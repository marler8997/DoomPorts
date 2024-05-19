#pragma once

#include "private/size_t.h"

typedef struct {
    int errno;
    unsigned flags;
    unsigned offset;
} FILE;

extern FILE *const stdin;
extern FILE *const stdout;
extern FILE *const stderr;

FILE *fopen(const char *filename, const char *mode);
int fclose(FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);
int fseek(FILE *stream, long int offset, int whence);
long int ftell(FILE *stream);
int feof(FILE *stream);

int printf(const char *format, ...);
int fprintf(FILE *stream, const char *format, ...);
