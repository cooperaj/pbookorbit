// Sizes and the type scale, matching the firmware's own Qt controls (the Global,
// GlobalValues and FontStyles singletons of com.pocketbook.controls in /ebrmain/qml).
// dpScale is set in main.cpp.

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

// The firmware's type scale, in points. Its styles, where they differ: Heading3 is
// heading, BodyL bodyLarge, BodyS bodySmall, TextInIcons1 textInIcons.
var heading = 13.44
var bodyLarge = 9.6
var body = 8.16
var bodySmall = 7.2
var textInIcons = 6
