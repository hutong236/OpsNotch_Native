#include "OpsNotchPrivateInterop.h"

#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>

static const char *skylight_path =
    "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight";
static const char *bridged_move_symbol =
    "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation";

static void fail(const char *message)
{
    fprintf(stderr, "ERROR: %s\n", message);
    exit(1);
}

static void require_export(void *image, const char *name)
{
    if (!dlsym(image, name)) {
        fprintf(stderr, "ERROR: missing SkyLight export %s\n", name);
        exit(1);
    }
}

int main(void)
{
    printf("Desktop Space compatibility probe: ");
    fflush(stdout);
    system("sw_vers -productVersion");

    void *skylight = dlopen(skylight_path, RTLD_LAZY);
    if (!skylight) fail("unable to load SkyLight");

    require_export(skylight, "SLSCopyManagedDisplaySpaces");
    require_export(skylight, "SLSCopySpacesForWindows");
    if (!dlsym(skylight, "CGSMainConnectionID") && !dlsym(skylight, "SLSMainConnectionID")) {
        fail("missing SkyLight main connection export");
    }

    void *perform_move = dlsym(
        skylight,
        "SLSPerformAsynchronousBridgedWindowManagementOperation"
    );
    if (!perform_move) {
        perform_move = opsnotch_find_macho_symbol(skylight_path, bridged_move_symbol);
    }
    if (!perform_move) fail("missing local bridged window-management entry point");

    Class operation_class = objc_getClass("SLSBridgedMoveWindowsToManagedSpaceOperation");
    if (!operation_class) fail("missing SLSBridgedMoveWindowsToManagedSpaceOperation class");
    SEL initializer = sel_registerName("initWithWindows:spaceID:");
    if (!class_getInstanceMethod(operation_class, initializer)) {
        fail("bridged move operation is missing initWithWindows:spaceID:");
    }

    // Force ApplicationServices into the process before checking the private
    // AX window-ID bridge. This does not display a permission prompt.
    (void)AXIsProcessTrusted();
    if (!dlsym(RTLD_DEFAULT, "_AXUIElementGetWindow")) {
        fail("missing _AXUIElementGetWindow");
    }

    dlclose(skylight);
    puts("PASS: macOS 26 Desktop Space exports, local symbol, and Objective-C ABI are available");
    return 0;
}
