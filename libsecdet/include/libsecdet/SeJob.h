#pragma once
#include <string>
#include <random>

using namespace std;

class SeArchive;


enum class JobType{
    None = 0,
    AddFile,
    RemoveFile,
    AddDirectory,
    DeleteDirectory,
    MoveArchiveFile,
    MoveDirectory,
    CompressionLevelChange,
    TestFile,
    ExtractFile,
    ExtractDirectory
};

enum class JobStatus{
    Idle,
    Pending,
    Running,
    Finished,
    Aborted,
    Failed
};


inline int getRandom(int min,int max){
    thread_local mt19937 gen(random_device{}());
    uniform_int_distribution<int> distrib(min,max);
    return distrib(gen);
}

class SeJob{
    
public: 
    SeJob() = delete;
    
    SeJob(JobType type,u16string fileName,u16string filePath): m_type(type) , m_fileName(fileName) , m_filePath(filePath){
        m_id=getRandom(100000,120000);
    }

    JobStatus GetStatus() const noexcept {return this->m_status;};

    int GetId() const noexcept {return this->m_id;}

    bool operator==(const SeJob& value){
        return value.m_id == this->m_id;
    }
    
    
    uint64_t processedBytes = 0;
    uint64_t totalBytes = 0;
    uint32_t percentage = 0;
    
    friend class SeArchive;

protected:
    void setStatus(JobStatus status) noexcept { this->m_status = status; }

private:
    int m_id = 0;
    JobType m_type = JobType::None;
    u16string m_fileName;
    u16string m_filePath;
    JobStatus m_status = JobStatus::Idle;
};
