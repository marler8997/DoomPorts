#pragma once

#include "private/size_t.h"

#define NULL ((void*)0)

_Noreturn void abort(void);
_Noreturn void exit(int);

void *malloc(size_t);
void free(void*);
char* getenv(const char*);
