#pragma once

#include <algorithm>
#include <cstdint>

namespace ControlReconnect
{
enum class State
{
    Idle,
    Waiting,
    ProbingBlueZ,
    ConnectingSocket
};

// Doubling from one second, capped so a long-lived session cannot overflow the shift.
inline constexpr int baseDelayMs = 1000;
inline constexpr int maxDoublings = 10;
inline constexpr int maxJitterMs = 499;
inline constexpr int jitterRangeMs = maxJitterMs + 1;

// Short enough that a real profile rebuild is still in progress when the first probe runs.
inline constexpr int firstDelayMs = 750;

inline int delayMs(int attempt, int jitterMs)
{
    const int boundedAttempt = std::clamp(attempt, 1, maxDoublings);
    const int boundedJitter = std::clamp(jitterMs, 0, maxJitterMs);
    return baseDelayMs * (1 << (boundedAttempt - 1)) + boundedJitter;
}

inline bool hasAttemptRemaining(int completedAttempts, int maximumAttempts)
{
    return completedAttempts < std::max(0, maximumAttempts);
}

class Session
{
public:
    void begin(bool bleScanWasActive)
    {
        m_state = State::Waiting;
        m_completedAttempts = 0;
        m_restoreBleScan = bleScanWasActive;
        ++m_generation;
    }

    bool isActive() const { return m_state != State::Idle; }
    State state() const { return m_state; }
    int completedAttempts() const { return m_completedAttempts; }

    std::uint64_t beginProbe()
    {
        m_state = State::ProbingBlueZ;
        return ++m_generation;
    }

    bool acceptsProbe(std::uint64_t generation) const
    {
        return m_state == State::ProbingBlueZ && generation == m_generation;
    }

    void beginConnection()
    {
        m_state = State::ConnectingSocket;
        ++m_generation;
    }

    bool prepareRetry(int maximumAttempts)
    {
        if (!isActive() || !hasAttemptRemaining(m_completedAttempts, maximumAttempts)) {
            return false;
        }
        ++m_completedAttempts;
        m_state = State::Waiting;
        ++m_generation;
        return true;
    }

    bool complete()
    {
        const bool restoreBleScan = m_restoreBleScan;
        reset();
        return restoreBleScan;
    }

    void cancel() { reset(); }

private:
    void reset()
    {
        m_state = State::Idle;
        m_completedAttempts = 0;
        m_restoreBleScan = false;
        ++m_generation;
    }

    State m_state = State::Idle;
    int m_completedAttempts = 0;
    bool m_restoreBleScan = false;
    std::uint64_t m_generation = 0;
};
}
