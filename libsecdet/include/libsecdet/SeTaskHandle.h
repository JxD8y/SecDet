#pragma once
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <expected>
#include <future>
#include <memory>
#include <mutex>
#include <stop_token>
#include <system_error>
#include <thread>
#include <utility>

class SePauseToken;

/// @brief Thread-safe shared pause controller
class SePauseState : public std::enable_shared_from_this<SePauseState> {
public:
  SePauseState() = default;

  /// @brief Requests the task to pause
  void pause() noexcept {
    m_paused.store(true, std::memory_order_release);
    m_cv.notify_all();
  }

  /// @brief Resumes the paused task
  void resume() noexcept {
    m_paused.store(false, std::memory_order_release);
    m_cv.notify_all();
  }

  /// @brief Toggles between paused and running states
  /// @return New paused state
  bool toggle() noexcept {
    bool expected = m_paused.load(std::memory_order_relaxed);
    m_paused.store(!expected, std::memory_order_release);
    m_cv.notify_all();
    return !expected;
  }

  /// @brief Checks if pause is currently requested
  [[nodiscard]] bool is_paused() const noexcept {
    return m_paused.load(std::memory_order_acquire);
  }

  /// @brief Blocks calling thread if paused, until resumed or stop requested
  /// @return true if stop was requested, false otherwise
  bool wait_if_paused(const std::stop_token &stopToken = {}) {
    if (!is_paused())
      return stopToken.stop_requested();
    std::unique_lock lock(m_mutex);
    m_cv.wait(lock, stopToken,
              [this]() { return !m_paused.load(std::memory_order_acquire); });
    return stopToken.stop_requested();
  }

  /// @brief Blocks calling thread if paused with optional callbacks on state transitions
  /// @return true if stop was requested, false otherwise
  template <typename OnPauseFn, typename OnResumeFn>
  bool wait_if_paused(const std::stop_token &stopToken, OnPauseFn &&onPause,
                      OnResumeFn &&onResume) {
    if (!is_paused())
      return stopToken.stop_requested();
    onPause();
    {
      std::unique_lock lock(m_mutex);
      m_cv.wait(lock, stopToken, [this]() {
        return !m_paused.load(std::memory_order_acquire);
      });
    }
    if (!stopToken.stop_requested()) {
      onResume();
    }
    return stopToken.stop_requested();
  }

  /// @brief Obtains a lightweight SePauseToken referencing this state
  SePauseToken get_token();

private:
  std::atomic<bool> m_paused{false};
  std::mutex m_mutex;
  std::condition_variable_any m_cv;
};

/// @brief Lightweight token passed to worker routines to check and honor pause requests
class SePauseToken {
public:
  SePauseToken() = default;
  explicit SePauseToken(std::shared_ptr<SePauseState> state)
      : m_state(std::move(state)) {}

  [[nodiscard]] bool is_paused() const noexcept {
    return m_state ? m_state->is_paused() : false;
  }

  bool wait_if_paused(const std::stop_token &stopToken = {}) const {
    if (m_state) {
      return m_state->wait_if_paused(stopToken);
    }
    return stopToken.stop_requested();
  }

  template <typename OnPauseFn, typename OnResumeFn>
  bool wait_if_paused(const std::stop_token &stopToken, OnPauseFn &&onPause,
                      OnResumeFn &&onResume) const {
    if (m_state) {
      return m_state->wait_if_paused(stopToken, std::forward<OnPauseFn>(onPause),
                              std::forward<OnResumeFn>(onResume));
    }
    return stopToken.stop_requested();
  }

  [[nodiscard]] std::shared_ptr<SePauseState> get_state() const noexcept {
    return m_state;
  }

private:
  std::shared_ptr<SePauseState> m_state;
};

inline SePauseToken SePauseState::get_token() {
  return SePauseToken(shared_from_this());
}

/// @brief Non-template polymorphic base class for SeTaskHandle allowing type-erased task management
class SeTaskHandleBase {
public:
  virtual ~SeTaskHandleBase() = default;

  /// @brief Requests the task to stop / abort
  virtual void request_stop() noexcept = 0;

  /// @brief Alias for request_stop
  void cancel() noexcept { request_stop(); }

  /// @brief Checks if a stop has been requested
  [[nodiscard]] virtual bool stop_requested() const noexcept = 0;

  /// @brief Requests the task to pause execution
  virtual void pause() noexcept = 0;

  /// @brief Requests the task to resume execution
  virtual void resume() noexcept = 0;

  /// @brief Toggles between paused and running states
  /// @return New paused state
  virtual bool toggle_pause() noexcept = 0;

  /// @brief Checks if task is currently paused
  [[nodiscard]] virtual bool is_paused() const noexcept = 0;

  /// @brief Checks if the underlying thread is joinable
  [[nodiscard]] virtual bool joinable() const noexcept = 0;

  /// @brief Checks if the task is actively running
  [[nodiscard]] virtual bool is_running() const noexcept = 0;

  /// @brief Checks if the task has completed
  [[nodiscard]] virtual bool is_finished() const noexcept = 0;

  /// @brief Checks if the task has completed (alias for is_finished)
  [[nodiscard]] bool is_done() const noexcept { return is_finished(); }

  /// @brief Waits for the task to finish
  virtual void wait() const = 0;

  /// @brief Explicitly joins the underlying thread
  virtual void join() = 0;

  /// @brief Detaches the thread if independent background execution is desired
  virtual void detach() = 0;
};

template <typename T = void> class SeTaskHandle : public SeTaskHandleBase {
public:
  using ResultType = std::expected<T, std::error_code>;

  SeTaskHandle() noexcept = default;

  SeTaskHandle(std::jthread thread, std::shared_future<ResultType> future,
               std::shared_ptr<SePauseState> pauseState = nullptr)
      : m_thread(std::move(thread)), m_future(std::move(future)),
        m_pauseState(std::move(pauseState)) {}

  // Movable
  SeTaskHandle(SeTaskHandle &&other) noexcept = default;
  SeTaskHandle &operator=(SeTaskHandle &&other) noexcept = default;

  // Non-copyable
  SeTaskHandle(const SeTaskHandle &) = delete;
  SeTaskHandle &operator=(const SeTaskHandle &) = delete;

  ~SeTaskHandle() override = default;

  /// @brief Requests the task to stop / abort (and wakes thread if paused)
  void request_stop() noexcept override {
    if (m_thread.joinable()) {
      m_thread.request_stop();
    }
    // Wake up any paused worker immediately so it can process the stop request
    if (m_pauseState) {
      m_pauseState->resume();
    }
  }

  /// @brief Checks if a stop has been requested
  [[nodiscard]] bool stop_requested() const noexcept override {
    return m_thread.get_stop_token().stop_requested();
  }

  /// @brief Requests the task to pause execution
  void pause() noexcept override {
    if (m_pauseState) {
      m_pauseState->pause();
    }
  }

  /// @brief Requests the task to resume execution
  void resume() noexcept override {
    if (m_pauseState) {
      m_pauseState->resume();
    }
  }

  /// @brief Toggles between paused and running states
  /// @return New paused state
  bool toggle_pause() noexcept override {
    if (m_pauseState) {
      return m_pauseState->toggle();
    }
    return false;
  }

  /// @brief Checks if task is currently paused
  [[nodiscard]] bool is_paused() const noexcept override {
    return m_pauseState ? m_pauseState->is_paused() : false;
  }

  /// @brief Gets the associated pause token
  [[nodiscard]] SePauseToken get_pause_token() const noexcept {
    return SePauseToken(m_pauseState);
  }

  /// @brief Gets the associated stop token
  [[nodiscard]] std::stop_token get_stop_token() const noexcept {
    return m_thread.get_stop_token();
  }

  /// @brief Gets the associated stop source
  [[nodiscard]] std::stop_source get_stop_source() noexcept {
    return m_thread.get_stop_source();
  }

  /// @brief Checks if the thread is joinable
  [[nodiscard]] bool joinable() const noexcept override {
    return m_thread.joinable();
  }

  /// @brief Checks if the task is still actively running
  [[nodiscard]] bool is_running() const noexcept override {
    if (!m_future.valid())
      return false;
    return m_future.wait_for(std::chrono::seconds(0)) !=
           std::future_status::ready;
  }

  /// @brief Checks if the task has completed
  [[nodiscard]] bool is_finished() const noexcept override {
    if (!m_future.valid())
      return false;
    return m_future.wait_for(std::chrono::seconds(0)) ==
           std::future_status::ready;
  }

  /// @brief Waits for the task to finish
  void wait() const override {
    if (m_future.valid()) {
      m_future.wait();
    }
  }

  /// @brief Waits for the task to finish with a timeout
  template <typename Rep, typename Period>
  bool wait_for(const std::chrono::duration<Rep, Period> &timeout) const {
    if (!m_future.valid())
      return true;
    return m_future.wait_for(timeout) == std::future_status::ready;
  }

  /// @brief Explicitly joins the underlying thread
  void join() override {
    if (m_thread.joinable()) {
      m_thread.join();
    }
  }

  /// @brief Detaches the thread if independent background execution is desired
  void detach() override {
    if (m_thread.joinable()) {
      m_thread.detach();
    }
  }

  /// @brief Blocks until the task completes and returns the result. Can be
  /// called multiple times.
  ResultType get() {
    if (m_thread.joinable()) {
      m_thread.join();
    }
    if (m_future.valid()) {
      return m_future.get();
    }
    return std::unexpected(
        std::make_error_code(std::errc::operation_not_permitted));
  }

  /// @brief Alias for get()
  ResultType result() { return get(); }

private:
  std::jthread m_thread;
  std::shared_future<ResultType> m_future;
  std::shared_ptr<SePauseState> m_pauseState;
};

using SeArchiveTaskHandle = SeTaskHandle<void>;
