#pragma once

struct timeval {
    unsigned tv_sec;
    unsigned tv_usec;
};
struct timezone { };
int gettimeofday(
    struct timeval */*restrict*/ tv,
    struct timezone */*restrict*/ tz
);
