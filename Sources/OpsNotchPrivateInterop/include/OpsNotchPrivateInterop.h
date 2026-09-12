#ifndef OPS_NOTCH_PRIVATE_INTEROP_H
#define OPS_NOTCH_PRIVATE_INTEROP_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Finds exported or local symbols in an already loaded 64-bit Mach-O image.
///
/// `dlsym` cannot resolve the local C++ window-management entry point used by
/// SkyLight on macOS 26. The returned pointer belongs to the loaded image and
/// remains valid while that image remains loaded.
void *opsnotch_find_macho_symbol(const char *image_path, const char *symbol_name);

// SkyLight image is retained for the process lifetime. A successful request is
// only submission: callers must independently verify Space membership/position.
void *opsnotch_window_move_address(void);
const char *opsnotch_window_move_status(void);
// 0 = submitted, 1 = unavailable, 2 = initializer failed, 3 = ObjC exception.
int opsnotch_request_window_move(uint32_t window_id, uint64_t space_id, int64_t *raw_result);

#ifdef __cplusplus
}
#endif

#endif
