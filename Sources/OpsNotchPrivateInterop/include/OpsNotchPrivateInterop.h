#ifndef OPS_NOTCH_PRIVATE_INTEROP_H
#define OPS_NOTCH_PRIVATE_INTEROP_H

#ifdef __cplusplus
extern "C" {
#endif

/// Finds exported or local symbols in an already loaded 64-bit Mach-O image.
///
/// `dlsym` cannot resolve the local C++ window-management entry point used by
/// SkyLight on macOS 26. The returned pointer belongs to the loaded image and
/// remains valid while that image remains loaded.
void *opsnotch_find_macho_symbol(const char *image_path, const char *symbol_name);

#ifdef __cplusplus
}
#endif

#endif
