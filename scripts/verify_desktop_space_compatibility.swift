#!/usr/bin/env swift

import ApplicationServices
import Darwin
import Foundation
import ObjectiveC

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ERROR: \(message)\n".utf8))
    exit(1)
}

let version = ProcessInfo.processInfo.operatingSystemVersion
print("Desktop Space compatibility probe: macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")

guard version.majorVersion == 26 else {
    fail("this compatibility probe must run on the macos-26 runner")
}

let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
guard let skyLight = dlopen(skyLightPath, RTLD_LAZY) else {
    let reason = dlerror().map { String(cString: $0) } ?? "unknown error"
    fail("unable to load SkyLight: \(reason)")
}
defer { dlclose(skyLight) }

let requiredSymbols = [
    "SLSCopyManagedDisplaySpaces",
    "SLSCopySpacesForWindows",
    "SLSPerformAsynchronousBridgedWindowManagementOperation",
]

for name in requiredSymbols where dlsym(skyLight, name) == nil {
    fail("missing SkyLight symbol \(name)")
}

guard dlsym(skyLight, "CGSMainConnectionID") != nil
        || dlsym(skyLight, "SLSMainConnectionID") != nil else {
    fail("missing SkyLight main connection symbol")
}

guard let operationClass = NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation") else {
    fail("missing SLSBridgedMoveWindowsToManagedSpaceOperation class")
}

let initializer = NSSelectorFromString("initWithWindows:spaceID:")
guard class_getInstanceMethod(operationClass, initializer) != nil else {
    fail("bridged move operation is missing initWithWindows:spaceID:")
}

// Force ApplicationServices into the process before checking the private AX
// window-ID bridge used by the app. No permission prompt is produced here.
_ = AXIsProcessTrusted()
guard let process = dlopen(nil, RTLD_LAZY) else {
    fail("unable to inspect process symbols")
}
defer { dlclose(process) }

guard dlsym(process, "_AXUIElementGetWindow") != nil else {
    fail("missing _AXUIElementGetWindow")
}

print("PASS: macOS 26 Desktop Space symbols and Objective-C ABI are available")
