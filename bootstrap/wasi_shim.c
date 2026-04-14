/* Minimal WASI shim for wasm2c-generated Lux compiler */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include "lux3_native.h"

/* Global ref to module instance for memory access */
static w2c_lux30x2Dreal* g_inst = NULL;

#define MEM_BASE (g_inst->w2c_memory.data)

/* The WASI "instance" — just needs to exist, can be empty */
struct w2c_wasi__snapshot__preview1 { int dummy; };

u32 w2c_wasi__snapshot__preview1_fd_write(
    struct w2c_wasi__snapshot__preview1* wasi,
    u32 fd, u32 iovs_ptr, u32 iovs_len, u32 nwritten_ptr)
{
    u8* mem = MEM_BASE;
    u32 total = 0;
    for (u32 i = 0; i < iovs_len; i++) {
        u32 buf_ptr = *(u32*)(mem + iovs_ptr + i * 8);
        u32 buf_len = *(u32*)(mem + iovs_ptr + i * 8 + 4);
        ssize_t n = write(fd, mem + buf_ptr, buf_len);
        if (n < 0) return 8;
        total += n;
    }
    *(u32*)(mem + nwritten_ptr) = total;
    return 0;
}

u32 w2c_wasi__snapshot__preview1_fd_read(
    struct w2c_wasi__snapshot__preview1* wasi,
    u32 fd, u32 iovs_ptr, u32 iovs_len, u32 nread_ptr)
{
    u8* mem = MEM_BASE;
    u32 total = 0;
    for (u32 i = 0; i < iovs_len; i++) {
        u32 buf_ptr = *(u32*)(mem + iovs_ptr + i * 8);
        u32 buf_len = *(u32*)(mem + iovs_ptr + i * 8 + 4);
        ssize_t n = read(fd, mem + buf_ptr, buf_len);
        if (n < 0) return 8;
        total += n;
        if ((u32)n < buf_len) break;
    }
    *(u32*)(mem + nread_ptr) = total;
    return 0;
}

u32 w2c_wasi__snapshot__preview1_path_open(
    struct w2c_wasi__snapshot__preview1* wasi,
    u32 dirfd, u32 dirflags, u32 path_ptr, u32 path_len,
    u32 oflags, u64 fs_rights_base, u64 fs_rights_inh,
    u32 fdflags, u32 result_fd_ptr)
{
    u8* mem = MEM_BASE;
    char path[4096];
    u32 copy_len = path_len < 4095 ? path_len : 4095;
    memcpy(path, mem + path_ptr, copy_len);
    path[copy_len] = '\0';
    
    int flags = O_RDONLY;
    if (oflags & 1) flags |= O_CREAT;
    if (oflags & 4) flags |= O_TRUNC;
    
    int fd = open(path, flags, 0644);
    if (fd < 0) return 44;
    *(u32*)(mem + result_fd_ptr) = fd;
    return 0;
}

u32 w2c_wasi__snapshot__preview1_fd_close(
    struct w2c_wasi__snapshot__preview1* wasi,
    u32 fd)
{
    close(fd);
    return 0;
}

int main(int argc, char** argv) {
    wasm_rt_init();
    
    w2c_lux30x2Dreal inst;
    struct w2c_wasi__snapshot__preview1 wasi = {0};
    
    g_inst = &inst;
    wasm2c_lux30x2Dreal_instantiate(&inst, &wasi);
    w2c_lux30x2Dreal_0x5Fstart(&inst);
    wasm2c_lux30x2Dreal_free(&inst);
    
    wasm_rt_free();
    return 0;
}
