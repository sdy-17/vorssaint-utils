# In-place screenshot editing (local integration)

When the screenshot default action is Edit and screen freezing is enabled,
a region capture opens the annotation canvas at the original selection in
screen points. The frozen display forms a dimmed, non-interactive background;
a horizontal tool strip and contextual style controls stay near the selection.
Eight grips and the four edges resize the selection within the original frozen
display. Expansion reads original pixels without stretching the previous crop.
Marks keep their desktop position, and a drag adds one Undo entry that restores
the selection rectangle, source pixels and annotations together. A pressed grip
does not jump to the pointer or create an edit until it actually moves.
The tool strip sizes to its button count (about 730 points with all tools),
rather than leaving a fixed-width gap before its action buttons.
The strip moves above the selection when the bottom edge has insufficient room.
For full-display selections the strip stays inside the display.

The implementation shares the existing annotation model, canvas, undo stack,
text, crop, blur, renderer and copy/save paths. Enter/check copies and closes;
Escape cancels after exiting an active selection/crop; Pin pins and closes.
Canvas expansion and decorative backdrops remain in the windowed editor.
Screen mode changes or disconnection release the shield and reopen the existing
model in a normal editor so annotations survive. Live (unfrozen) captures,
history/clipboard captures without a desktop still, and configured decorative
backdrops use the existing windowed editor.

The full desktop still is ephemeral. History and exports only receive the
selected image and annotations, never the surrounding desktop or toolbar.
HiDPI geometry uses source pixels for rendering and Cocoa points for placement.
The app keeps the same bundle identifier and local signing certificate.

Validation: `./build.sh --test-suite=screenshots` passes 1,607 checks, including
selection placement on negative-origin HiDPI displays, bottom-edge toolbar
placement and full-screen toolbar bounds. UI checks on the installed signed app passed: a 400×250-point selection stayed
in place; arrow annotation, Undo/Redo and Escape worked; a separate safe settings
selection exported with its annotation and without the desktop dim or toolbar.
Both temporary test preferences were restored. Bottom-edge toolbar placement
is covered by the geometry checks; it was not independently verified in the UI.

Resizable-selection UI validation on the installed app: right-edge expansion
changed 400×250 to 450×250 points; dragging the top-left corner out changed it
to 480×280 and back in to 460×260. The arrow stayed at the same desktop
position. Undo restored 480×280 and Redo restored 460×260. A click without a
drag did not change the selection. Eight grips were visible, and the compact
strip had no large middle gap. Test toggles and the remembered sticker tool
were restored. This session did not save a resized export; the source-pixel
and annotation-offset checks cover the resized image, and the previous safe
UI export test covers the shared save renderer.

Presentation performance: sampling found time in repeated NSPanel creation,
window ordering/level changes and app activation during every capture handoff.
Frozen selections now offer a weak, one-claim surface lease: the editor replaces
the existing visible panel content before the selection retires other panels.
The display-sized hosting view disables ideal-size window negotiation and the
unused initial canvas animation. The key panel stays non-activating; regular
windowed editors retain the Dock/activation policy themselves. Background cursor
ownership remains held while an in-place editor or capture is alive. Vision
starts 350ms after presentation and checks that the editor is still visible.
Lease tests cover single ownership, weak lifetime and expired handoffs. This
removes the avoidable window swap; it is not a measured end-to-end latency claim.

Surface-reuse install validation: repeated in-place captures and Escape left
no residual shield. Arrow drawing, boundary expansion, Undo and typing `test`
in the text tool worked with the non-activating key panel. Sampling the old
path included ScreenshotInPlaceEditorPanel initialization and application
activation under showInPlace; these calls were absent from the new handoff
samples. The samples do not provide per-capture frame or pointer latency.
Temporary UI test preferences were restored (automatic copy was already off
at the start of this session, hidden app windows on, remembered sticker tool).

Follow-up after real F1 reproduction on the built-in display: the user's CPU
sample still showed finish → empty retirePanels → synchronous CA flush, image
copy/color conversion, and per-capture Vision work. Empty retirement now skips
flush. The native NSImageView/container survives handoff and the transparent
editor is added above it; SwiftUI no longer receives a second full-display
Image. In-place canvas shadows are disabled. Recognition is demand-driven for
the selection tool or text-only blur, deduplicated for the current base image;
the normal windowed editor retains its QR and recognition behavior.

Installed-build checks passed for dimmed native background, arrow drawing,
boundary resizing, Undo, typing and OCR text highlighting. Two ordinary sticker
captures cancelled without residual shields. Their CPU sample had no
ScreenshotEditorModel OCR/QR work and no retirePanels flush work; showInPlace
was only briefly sampled. Initial screen capture can still prepare images, so
this does not establish zero visible latency or a precise percentage improvement.
