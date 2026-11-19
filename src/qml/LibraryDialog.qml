import QtQuick
import "units.js" as Units
import "format.js" as Format

// Asks which library to use when the server has several and none has been chosen, or when
// changing library from the menu (see Session::libraryChoices). Opens by itself, with the
// library in use selected, or the first; a tap selects another, and Continue uses it. Only
// a change can be cancelled.
SystemDialog {
    id: dialog
    readonly property var choices: bookOrbit.session.libraryChoices
    readonly property bool changing: bookOrbit.session.libraryId >= 0
    property int selectedId: -1
    // Rows shown before the list scrolls
    readonly property int maxRows: 5

    visible: choices.length > 0
    onChoicesChanged: {
        const current = choices.find(choice => choice.id === bookOrbit.session.libraryId)
        selectedId = current ? current.id : choices.length > 0 ? choices[0].id : -1
    }

    heading: "Choose your library"
    icon: "icon_question"
    buttons: changing ? [["Cancel", "cancel"], ["Continue", "continue"]] : [["Continue", "continue"]]
    onPressed: (action) => {
        if (action === "cancel")
            bookOrbit.session.cancelLibraryChoice()
        else
            bookOrbit.session.chooseLibrary(selectedId)
    }

    SystemDialog.DialogText {
        text: "Your BookOrbit server has " + Format.count(dialog.choices.length, "library", "libraries")
              + ". Choose the one to use on this device."
    }

    Item {
        width: parent.width
        height: list.height

        ListView {
            id: list
            objectName: "libraryList"
            readonly property real rowHeight: Units.dp(50)
            width: parent.width
            height: Math.min(count, dialog.maxRows) * rowHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: dialog.choices

            delegate: PressableRow {
                id: row
                required property var modelData
                objectName: "library " + modelData.name
                height: list.rowHeight
                radius: Units.dp(4)
                selected: modelData.id === dialog.selectedId
                lineStartInset: Units.dp(4)
                lineEndInset: Units.dp(4)
                lineColor: "#7f7f7f"
                onClicked: dialog.selectedId = modelData.id

                ThemeIcon {
                    x: Units.dp(26) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    name: "e3_filter_bookshelf_bold"
                    inverted: row.inverted
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Units.dp(52)
                    anchors.right: count.left
                    anchors.rightMargin: Units.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: row.foreground
                    font.pointSize: 8
                    elide: Text.ElideRight
                }
                Text {
                    id: count
                    anchors.right: parent.right
                    anchors.rightMargin: Units.dp(10) + (scrollbar.visible ? Units.dp(12) : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Format.count(row.modelData.bookCount, "book")
                    color: row.foreground
                    font.pointSize: 7.25
                }
            }
        }

        ListScrollbar {
            id: scrollbar
            list: list
        }

        A2Scrolling {
            target: list
        }
    }
}
