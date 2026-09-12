#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include "OpsNotchPrivateInterop.h"
#include "FinderSpaceDemoBridge.h"

@interface NSObject (FinderDemoPrivateInitializer)
- (id)initWithWindows:(NSArray *)windows spaceID:(uint64_t)spaceID;
@end

void *FinderDemoMoveAddress(void)
{
    static void *image;
    const char *path = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight";
    if (!image) image = dlopen(path, RTLD_LAZY);
    if (!image) return NULL;
    void *address = dlsym(image, "SLSPerformAsynchronousBridgedWindowManagementOperation");
    return address ? address : opsnotch_find_macho_symbol(path,
        "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation");
}

const char *FinderDemoBridgeStatus(void)
{
    if (!FinderDemoMoveAddress()) return "missing-perform-symbol";
    Class cls = objc_getClass("SLSBridgedMoveWindowsToManagedSpaceOperation");
    if (!cls) return "missing-operation-class";
    if (!class_getInstanceMethod(cls, @selector(initWithWindows:spaceID:))) return "missing-initializer";
    return "available";
}

int FinderDemoRequestMove(uint32_t window_id, uint64_t space_id, int64_t *raw_result)
{
    typedef int64_t (*PerformMove)(id);
    PerformMove perform = (PerformMove)FinderDemoMoveAddress();
    if (strcmp(FinderDemoBridgeStatus(), "available") != 0) return 1;
    @autoreleasepool {
        @try {
            Class cls = objc_getClass("SLSBridgedMoveWindowsToManagedSpaceOperation");
            NSArray *windows = @[@((int32_t)window_id)];
            // SwiftPM compiles Objective-C with ARC. Hold the initialized
            // object through the C call and let ARC release it afterwards.
            __attribute__((objc_precise_lifetime)) id operation =
                [[cls alloc] initWithWindows:windows spaceID:space_id];
            if (!operation) return 2;
            int64_t result = perform(operation);
            if (raw_result) *raw_result = result;
        } @catch (NSException *exception) {
            // Do not include Finder titles or paths in diagnostics.
            return 3;
        }
    }
    return 0;
}
