# Display configuration module

The existing Displays feature now includes HiDPI and resolution selection,
refresh rate, main display, RGB color profile selection, and named snapshots of
the connected display setup. The existing brightness/power controls are reused.

Changes preview for 15 seconds. Keep commits the mode/layout permanently; Cancel,
closing the page, or the timeout restores the previous snapshot. WindowServer owns
temporary geometry changes (`forAppOnly`), so a crashed process cannot leave its
preview geometry active. A local recovery journal restores an unconfirmed ICC
override on the next launch of the Displays feature. A failed rollback retains
its recovery plan and offers Retry. Disconnected monitors are skipped during
recovery, but restoring a saved setup requires the complete connected display set.

Saved setups use display UUIDs and mode geometry/rate/depth, never transient
display or mode indexes. They include main-display-relative positions and custom
ICC selections. These machine-specific settings and the recovery journal are
excluded from portable settings backups. A missing mode or ICC file fails before
changing any display. Mirroring must be disabled before editing a configuration.

## Mode API boundary

Public CoreGraphics mode enumeration omits some scaled HiDPI modes on Apple
silicon. The optional, dynamically resolved CGS bridge reads those existing modes
and configures them inside a CoreGraphics transaction. Its structure is validated
against the public current mode on every query. Unsupported symbols or layouts
fall back to public modes. Invalid/interlaced modes are rejected, and the current
color depth is preserved. The bridge uses the documented-by-source API layout in
[Hammerspoon](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/screen/libscreen.m)
and [CGSInternal](https://github.com/NUIKit/CGSInternal/blob/master/CGSDisplays.h).
It does not install either project or include their implementation.

This module does not create custom timings, install display-model/EDID overrides,
create virtual screens, or manage mirroring. It cannot invent modes the OS does
not expose. CGS is a private macOS API and may change with an OS update; the public
fallback deliberately provides a smaller mode list.

Color profiles come from the system, local and user's ColorSync profile folders,
plus the active display profile. Only display-class RGB ICC/ICM profiles are
offered. ColorSync sets an override for the current user, or resets to the device's
factory profile. No administrator helper is needed for these operations.

## Development and verification

Open the Displays settings directly with `--display-settings` (when the Displays
feature is installed). Build a separate Developer bundle for UI checks; replacing
the signed official bundle changes its code-signing identity and may invalidate
existing macOS privacy grants and privileged-helper trust.

Run the behavior tests without changing any display:

```sh
./build.sh --test-suite=display-configuration
```

Build the complete application with the standard repository build workflow and
run its selftest. UI/hardware acceptance checks: HiDPI versus backing pixel count,
retained refresh rate, timer rollback, Keep, main-screen switch/revert, ICC
switch/revert, snapshot save/restore, and monitor removal during a preview. Keep a
working built-in screen available for the mode tests. Compilation and mocked
transaction tests alone do not verify those interactions.

### Verified local setup

On an Apple M5 Pro running macOS 26.4 with the built-in Retina screen and an
H27T22 external screen, the Developer bundle passed its selftest and the selected
display-configuration/settings suites (721 checks). Hardware/UI checks covered
1920 × 1080 HiDPI at 144 Hz (3840 × 2160 backing pixels), a 2048 × 1152 preview
timing out to that mode, main-display switch/revert, and snapshot save/restore.
ColorSync independently reported the sRGB file after selection; the factory ICC
profile was restored afterward. The accepted HiDPI mode persisted after quitting
the app. The native SettingsCard/SettingsRow/SettingsMenuRow layout was checked
for alignment and clipping in both display cards and the saved configurations.
Physical hot-unplug during a preview was not performed; recovery for a missing
display is covered by the behavior tests.
