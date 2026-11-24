// Sizes and the type scale, matching the firmware's own Qt controls (the Global,
// GlobalValues and FontStyles singletons of com.pocketbook.controls in /ebrmain/qml).
// dpScale and accessibility are set in main.cpp.

// Density-independent size: dp(56) is the same physical size on every device. The
// firmware's sizes aren't always whole dp (its header is dp(55.46)). To convert a pixel
// measurement from an Era Color screenshot, divide by 2.175 (300 dpi x scale factor 1.16
// / 160).
function dp(v) {
    return Math.round(v * dpScale)
}

// A size from the firmware's 300 dpi designs, in design pixels (its pixelsFromDesign())
function fromDesign(px) {
    return dp(px * 160 / 300)
}

// The firmware's metrics
var headerHeight = dp(55.46)        // toolbar, without its 1px line
var elementHeight = fromDesign(104) // pill buttons
var listElementHeight = dp(56)
var panelBorder = fromDesign(8)     // menus and dialogs
var disabledColor = "#808080"       // text and borders of disabled controls

// The firmware's type scale, in points, before the system's text size (see StyledText).
// Its styles, where they differ: Heading3 is heading, BodyL bodyLarge, BodyS bodySmall,
// TextInIcons1 textInIcons.
var heading = 13.44
var bodyLarge = 9.6
var body = 8.16
var bodySmall = 7.2
var textInIcons = 6

// The system's text size (Settings > Accessibility), 1 to 2. Text grows with it, and so
// does content laid out around text, such as a list row; toolbars, buttons and menu rows
// keep their height, and pictures their size.
function textScale() {
    return accessibility.textScale
}

// Lines close up a little as text grows, as in the firmware's apps: 0.9 at the largest
function lineSpacing() {
    return 1 - 0.1 * (accessibility.textScale - 1)
}

// A grey text colour, or black (or contrasted, e.g. white on a pressed row) with the
// system's grey text contrast on
function grey(color, contrasted) {
    return accessibility.highContrast ? (contrasted || "black") : color
}
