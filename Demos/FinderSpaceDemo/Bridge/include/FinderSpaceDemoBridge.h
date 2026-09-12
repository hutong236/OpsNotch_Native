#ifndef FINDER_SPACE_DEMO_BRIDGE_H
#define FINDER_SPACE_DEMO_BRIDGE_H
#include <stdint.h>

// Pointers refer to the loaded SkyLight image, held until process termination.
void *FinderDemoMoveAddress(void);
const char *FinderDemoBridgeStatus(void);
// 0 = submitted (not verified); 1 = unavailable; 2 = initialization failed;
// 3 = Objective-C exception. raw_result is diagnostic, never a success flag.
int FinderDemoRequestMove(uint32_t window_id, uint64_t space_id, int64_t *raw_result);
#endif
