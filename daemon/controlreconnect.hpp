#pragma once

#include <algorithm>

namespace ControlReconnect
{
inline int delayMs(int attempt, int jitterMs)
{
    const int boundedAttempt = std::clamp(attempt, 1, 10);
    const int boundedJitter = std::clamp(jitterMs, 0, 499);
    return 1000 * (1 << (boundedAttempt - 1)) + boundedJitter;
}

inline bool hasAttemptRemaining(int completedAttempts, int maximumAttempts)
{
    return completedAttempts < std::max(0, maximumAttempts);
}
}
