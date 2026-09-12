#include "OpsNotchPrivateInterop.h"

#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <stdint.h>
#include <string.h>

static int image_path_matches(const char *loaded_path, const char *target_path)
{
    if (strcmp(loaded_path, target_path) == 0) return 1;

    const char *loaded_name = strrchr(loaded_path, '/');
    const char *target_name = strrchr(target_path, '/');
    loaded_name = loaded_name ? loaded_name + 1 : loaded_path;
    target_name = target_name ? target_name + 1 : target_path;
    return strcmp(loaded_name, target_name) == 0;
}

void *opsnotch_find_macho_symbol(const char *image_path, const char *symbol_name)
{
    if (!image_path || !symbol_name) return NULL;

    const uint32_t image_count = _dyld_image_count();
    for (uint32_t image_index = 0; image_index < image_count; ++image_index) {
        const char *loaded_path = _dyld_get_image_name(image_index);
        const struct mach_header *untyped_header = _dyld_get_image_header(image_index);
        if (!loaded_path || !untyped_header || !image_path_matches(loaded_path, image_path)) continue;
        if (untyped_header->magic != MH_MAGIC_64 && untyped_header->magic != MH_CIGAM_64) continue;

        const struct mach_header_64 *header = (const struct mach_header_64 *)untyped_header;
        const struct segment_command_64 *linkedit = NULL;
        const struct symtab_command *symtab = NULL;
        const uint8_t *command_address = (const uint8_t *)header + sizeof(*header);

        for (uint32_t command_index = 0; command_index < header->ncmds; ++command_index) {
            const struct load_command *command = (const struct load_command *)command_address;
            if (command->cmdsize < sizeof(*command)) return NULL;

            if (command->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                if (strncmp(segment->segname, SEG_LINKEDIT, sizeof(segment->segname)) == 0) {
                    linkedit = segment;
                }
            } else if (command->cmd == LC_SYMTAB) {
                symtab = (const struct symtab_command *)command;
            }
            command_address += command->cmdsize;
        }

        if (!linkedit || !symtab) return NULL;

        const intptr_t slide = _dyld_get_image_vmaddr_slide(image_index);
        const uintptr_t linkedit_base = (uintptr_t)(linkedit->vmaddr - linkedit->fileoff) + (uintptr_t)slide;
        const char *string_table = (const char *)(linkedit_base + symtab->stroff);
        const struct nlist_64 *symbol_table = (const struct nlist_64 *)(linkedit_base + symtab->symoff);

        for (uint32_t symbol_index = 0; symbol_index < symtab->nsyms; ++symbol_index) {
            const struct nlist_64 *symbol = &symbol_table[symbol_index];
            if (symbol->n_un.n_strx == 0 || symbol->n_un.n_strx >= symtab->strsize) continue;

            const char *candidate = string_table + symbol->n_un.n_strx;
            if (strcmp(candidate, symbol_name) == 0 && symbol->n_value != 0) {
                return (void *)((uintptr_t)symbol->n_value + (uintptr_t)slide);
            }
        }
        return NULL;
    }

    return NULL;
}
