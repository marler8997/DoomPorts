#pragma once

#include "private/size_t.h"

char *strchr(const char *s, int c);
size_t strlen(const char *s);

void *memcpy(void *s1, const void *s2, size_t n);
