#define DOOM_IMPLEMENTATION

// we don't want to set function pointers at runtime, so we use these definitions
// to tell DOOM to include stdlib.h and the libc functions directly
#define DOOM_IMPLEMENT_PRINT
#define DOOM_IMPLEMENT_MALLOC
#define DOOM_IMPLEMENT_FILE_IO
#define DOOM_IMPLEMENT_GETTIME
#define DOOM_IMPLEMENT_EXIT
#define DOOM_IMPLEMENT_GETENV

#include "PureDOOM.h"

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#define checktype(type, size) do {                                              \
    if (sizeof(type) != size) {                                                 \
        printf("sizeof(" #type ") (%d) != %d\n", (int)sizeof(type), (int)size); \
        abort();                                                                \
    }                                                                           \
} while (0)

void check_libc_types()
{
    checktype(size_t, sizeof(void*));
    checktype(uint8_t, 1);
}

const unsigned char *doom_get_screen_palette()
{
    return screen_palette;
}

const unsigned char *doom_get_screen_buffer()
{
    return screen_buffer;
}
