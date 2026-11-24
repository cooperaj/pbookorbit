import QtQuick
import "units.js" as Units

// Bar under the toolbar with a filter button on the left and a sort button on the right,
// modelled on Libby on an Era Color. While its menu is open, a button becomes a black tab
// running down over the menu's top border so they read as one shape. The down arrow after
// each label marks a menu. As in the system library, the sort icon is a separate round
// button that reverses the sort and shows its direction; it isn't part of the tab, so it
// doesn't change while the menu is open. Its labels and icon show a query's sort and filter.
Item {
    id: bar
    property ListQuery query: null
    property bool filterOpen: false
    property bool sortOpen: false
    // Sort-only queries leave out the filter button
    readonly property bool showFilter: query ? query.hasFilter : false
    // How far an open tab reaches below the bar: PopupMenu's border, less the bar's line,
    // which the menu starts on
    property int tabOverhang: Units.panelBorder - 1
    // For a copy drawn over the faded page while a menu is open, showing just the open tab
    property bool onlyOpenTab: false
    // While set, the sort icon keeps its pressed look and the direction it had when set, so
    // it changes in the same screen update as the list it reversed
    property bool holdSortIcon: false
    property bool heldReversed: false
    onHoldSortIconChanged: if (holdSortIcon) heldReversed = query ? query.sortReversed : false
    signal filterClicked()
    signal sortClicked()
    signal sortIconClicked()

    // Where menus go, in this item's coordinates
    readonly property real filterMenuX: filterButton.x
    readonly property real sortMenuRight: sortButton.x + sortButton.width
    readonly property real menuY: height - 1

    height: Units.dp(55)

    // A button: icon, label and arrow
    component DropdownButton: Item {
        id: button
        property string icon
        property string text
        property bool capitals: false
        property bool open: false
        property int spacing: Units.dp(2)
        // Whether the icon is a separate button outside the tab. Its taps send iconClicked
        // instead of clicked, and it shows pressedIcon while pressed or held.
        property bool iconIsButton: false
        property string pressedIcon
        property bool held: false
        // Its label is cut short to keep it this wide at most
        property int maxWidth: (bar.width - 2 * Units.dp(26) - Units.dp(16)) / 2
        signal clicked()
        signal iconClicked()

        width: content.width + Units.dp(8)
        height: bar.height

        // The tab, without a separate icon button
        Rectangle {
            x: button.iconIsButton ? content.x + labelBox.x - Units.dp(4) : 0
            width: parent.width - x
            height: parent.height + bar.tabOverhang
            color: "black"
            visible: button.open
        }
        Row {
            id: content
            anchors.verticalCenter: parent.verticalCenter
            spacing: button.spacing
            ThemeIcon {
                id: iconImage
                anchors.verticalCenter: parent.verticalCenter
                // Left out of the open-tab copy so the faded one beneath shows
                opacity: button.iconIsButton && bar.onlyOpenTab ? 0 : 1
                name: button.iconIsButton && (iconMouse.pressed || button.held) ? button.pressedIcon : button.icon
                inverted: !button.iconIsButton && button.open
            }
            // The label, cut short if need be, then its arrow
            Item {
                id: labelBox
                anchors.verticalCenter: parent.verticalCenter
                width: label.width + arrowText.implicitWidth
                height: label.implicitHeight

                StyledText {
                    id: label
                    objectName: "label"
                    width: Math.min(implicitWidth, button.maxWidth - Units.dp(8) - iconImage.width
                                    - button.spacing - arrowText.implicitWidth)
                    text: button.text
                    color: button.open ? "white" : "black"
                    size: Units.body
                    font.capitalization: button.capitals ? Font.AllUppercase : Font.MixedCase
                    elide: Text.ElideRight
                }
                StyledText {
                    id: arrowText
                    x: label.width
                    text: " ↓"
                    color: label.color
                    size: Units.body
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: button.clicked()
        }
        // Icon tap area: full height, from the button's left edge to halfway into the gap
        // before the label
        PressArea {
            id: iconMouse
            objectName: "iconButton"
            visible: button.iconIsButton && !bar.onlyOpenTab
            width: content.x + iconImage.width + button.spacing / 2
            height: parent.height
            onClicked: button.iconClicked()
        }
    }

    Line {
        visible: !bar.onlyOpenTab
        anchors.bottom: parent.bottom
        inset: Units.dp(26)
    }

    DropdownButton {
        id: filterButton
        objectName: "filterButton"
        x: Units.dp(26)
        icon: "filter_empty"
        text: bar.query ? bar.query.filterName : ""
        capitals: true
        open: bar.filterOpen
        visible: bar.showFilter && (!bar.onlyOpenTab || open)
        onClicked: bar.filterClicked()
    }
    DropdownButton {
        id: sortButton
        objectName: "sortButton"
        x: bar.width - Units.dp(26) - width
        icon: (bar.holdSortIcon ? bar.heldReversed : bar.query && bar.query.sortReversed)
              ? "sorting_ascending" : "sorting_descending"
        held: bar.holdSortIcon
        text: bar.query ? "By " + bar.query.sortName : ""
        spacing: Units.dp(10)
        open: bar.sortOpen
        iconIsButton: true
        pressedIcon: icon + "_inv"
        visible: !bar.onlyOpenTab || open
        onClicked: bar.sortClicked()
        onIconClicked: bar.sortIconClicked()
    }
}
