// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Darwin
import Foundation
import IOKit.graphics

/// The CGS mode API exposes scaled modes omitted by CGDisplayCopyAllDisplayModes.
/// The ABI is independently decoded here, checked against the public current mode
/// on each display, and dynamically resolved so missing symbols disable this path.
/// API layout references: Hammerspoon's extensions/screen/libscreen.m (MIT),
/// https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/screen/libscreen.m
/// and CGSInternal's CGSDisplays.h. No third-party implementation is bundled.
enum ExtendedDisplayModes {
    struct Mode {
        let index: Int32
        let specification: DisplayModeSpecification
    }
    struct Snapshot {
        let current: Mode
        let modes: [Mode]
    }
    private typealias Count = @convention(c) (UInt32, UnsafeMutablePointer<Int32>) -> Int32
    private typealias Describe = @convention(c) (UInt32, Int32, UnsafeMutableRawPointer, Int32) -> Int32
    private typealias Current = @convention(c) (UInt32, UnsafeMutablePointer<Int32>) -> Int32
    private typealias Configure = @convention(c) (CGDisplayConfigRef, UInt32, Int32) -> Int32
    private struct Bridge {
        let count: Count
        let describe: Describe
        let current: Current
        let configure: Configure
    }
    private static let bridge: Bridge? = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY | RTLD_LOCAL),
              let count = dlsym(handle, "CGSGetNumberOfDisplayModes"),
              let describe = dlsym(handle, "CGSGetDisplayModeDescriptionOfLength"),
              let current = dlsym(handle, "CGSGetCurrentDisplayMode"),
              let configure = dlsym(handle, "CGSConfigureDisplayMode") else { return nil }
        return Bridge(count: unsafeBitCast(count, to: Count.self),
                      describe: unsafeBitCast(describe, to: Describe.self),
                      current: unsafeBitCast(current, to: Current.self),
                      configure: unsafeBitCast(configure, to: Configure.self))
    }()

    static func decode(_ data: Data, index: Int32) -> Mode? {
        guard data.count >= 212 else { return nil }
        func number<T>(_ offset: Int, _ type: T.Type) -> T {
            data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: type) }
        }
        let flags = number(4, UInt32.self)
        let width = number(8, UInt32.self), height = number(12, UInt32.self)
        let depth = number(16, UInt32.self)
        let rate = Double(number(188, UInt32.self)) / 65536
        let scale = number(208, Float.self)
        guard index >= 0, width > 0, height > 0, width <= 32768, height <= 32768,
              depth > 0, depth <= 64, rate <= 1000,
              scale.isFinite, scale == 1 || scale == 2,
              flags & UInt32(kDisplayModeValidFlag) != 0,
              flags & UInt32(kDisplayModeNeverShowFlag | kDisplayModeInterlacedFlag) == 0 else { return nil }
        return Mode(index: index, specification: DisplayModeSpecification(width: Int(width), height: Int(height),
            pixelWidth: Int(width) * Int(scale), pixelHeight: Int(height) * Int(scale),
            refreshRate: rate, colorDepth: depth))
    }

    static func snapshot(_ id: CGDirectDisplayID) -> Snapshot? {
        guard let bridge, let publicMode = CGDisplayCopyDisplayMode(id) else { return nil }
        var count: Int32 = 0, current: Int32 = -1
        guard bridge.count(id, &count) == 0, count > 0, count <= 4096,
              bridge.current(id, &current) == 0, current >= 0, current < count else { return nil }
        func describe(_ index: Int32) -> Mode? {
            var data = Data(repeating: 0, count: 212)
            let result = data.withUnsafeMutableBytes { raw in
                bridge.describe(id, index, raw.baseAddress!, 212)
            }
            return result == 0 ? decode(data, index: index) : nil
        }
        guard let active = describe(current), active.specification.width == publicMode.width,
              active.specification.height == publicMode.height,
              active.specification.pixelWidth == publicMode.pixelWidth,
              active.specification.pixelHeight == publicMode.pixelHeight,
              abs(active.specification.refreshRate - publicMode.refreshRate) < 0.1 else { return nil }
        let modes = (0..<count).compactMap(describe).filter {
            // Changing scale must not silently change the user's color depth.
            $0.specification.colorDepth == active.specification.colorDepth
        }
        return Snapshot(current: active, modes: modes)
    }

    static func configure(_ mode: Int32, display: CGDirectDisplayID, in configuration: CGDisplayConfigRef) -> CGError {
        guard let bridge else { return .notImplemented }
        return CGError(rawValue: bridge.configure(configuration, display, mode)) ?? .failure
    }
}
