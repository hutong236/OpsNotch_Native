#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "OpsNotchPrivateInterop.h"

typedef uint32_t (*Connection)(void);
typedef CFArrayRef (*ReadSpaces)(uint32_t, int32_t, CFArrayRef);

static void fail(const char *message)
{
    fprintf(stderr, "WINDOW_MOVE_PROBE_FAILED: %s\n", message);
    exit(1);
}

static void pump(void)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
}

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        printf("OS %s\n", NSProcessInfo.processInfo.operatingSystemVersionString.UTF8String);
        void *image = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
        Connection connection = image ? (Connection)dlsym(image, "SLSMainConnectionID") : NULL;
        ReadSpaces readSpaces = image ? (ReadSpaces)dlsym(image, "SLSCopySpacesForWindows") : NULL;
        if (!connection || !readSpaces) fail("Space reader unavailable");

        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 300, 180)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed = NO;
        [window orderFront:nil];
        pump();
        uint32_t wid = (uint32_t)window.windowNumber;
        NSArray *ids = @[@((int32_t)wid)];
        NSArray *before = CFBridgingRelease(readSpaces(connection(), 7, (__bridge CFArrayRef)ids));
        if (before.count != 1) fail("own window does not have one Space");
        uint64_t sid = [before.firstObject unsignedLongLongValue];
        int64_t rawResult = 0;
        int status = opsnotch_request_window_move(wid, sid, &rawResult);
        if (status != 0) fail("production Objective-C request did not submit");
        pump();
        NSArray *after = CFBridgingRelease(readSpaces(connection(), 7, (__bridge CFArrayRef)ids));
        if (![after isEqualToArray:before]) fail("unexpected same-Space membership change");
        [window orderOut:nil];
        puts("PASS: production Objective-C bridge invoked on own window in its current Space");
        puts("CROSS_SPACE_NOT_TESTED; CROSS_DISPLAY_NOT_TESTED; EXTERNAL_APP_NOT_TESTED");
    }
    return 0;
}
