#pragma once
#include <chrono>
#include <expected>
#include <future>
#include <memory>
#include <stop_token>
#include <system_error>
#include <thread>

template <typename T = void> class SeTaskHandle {
public:
  using ResultType = std::expected<T, std::error_code>;

  SeTaskHandle() noexcept = default;

  SeTaskHandle(std::jthread thread, std::shared_future<ResultType> future)
      : m_thread(std::move(thread)), m_future(std::move(future)) {}

  // Movable
  SeTaskHandle(SeTaskHandle &&other) noexcept = default;
  SeTaskHandle &operator=(SeTaskHandle &&other) noexcept = default;

  // Non-copyable
  SeTaskHandle(const SeTaskHandle &) = delete;
  SeTaskHandle &operator=(const SeTaskHandle &) = delete;

  ~SeTaskHandle() = default;

  /// @brief Requests the task to stop / abort
  void request_stop() noexcept {
    if (m_thread.joinable()) {
      m_thread.request_stop();
    }
  }

  /// @brief Alias for request_stop
  void cancel() noexcept { request_stop(); }

  /// @brief Checks if a stop has been requested
  [[nodiscard]] bool stop_requested() const noexcept {
    return m_thread.get_stop_token().stop_requested();
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
  [[nodiscard]] bool joinable() const noexcept { return m_thread.joinable(); }

  /// @brief Checks if the task is still actively running
  [[nodiscard]] bool is_running() const noexcept {
    if (!m_future.valid())
      return false;
    return m_future.wait_for(std::chrono::seconds(0)) !=
           std::future_status::ready;
  }

  /// @brief Checks if the task has completed
  [[nodiscard]] bool is_finished() const noexcept {
    if (!m_future.valid())
      return false;
    return m_future.wait_for(std::chrono::seconds(0)) ==
           std::future_status::ready;
  }

  /// @brief Checks if the task has completed (alias for is_finished)
  [[nodiscard]] bool is_done() const noexcept { return is_finished(); }

  /// @brief Waits for the task to finish
  void wait() const {
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
  void join() {
    if (m_thread.joinable()) {
      m_thread.join();
    }
  }

  /// @brief Detaches the thread if independent background execution is desired
  void detach() {
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
};

using SeArchiveTaskHandle = SeTaskHandle<void>;
