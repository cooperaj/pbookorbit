import QtQuick
import QtTest
import "../../../src/qml/format.js" as Format

// Text formatting (format.js)
TestCase {
    name: "Format"

    function test_date() {
        compare(Format.date("1948-03-12", 1948), "12/03/1948")
        compare(Format.date(undefined, 1948), "1948")
        compare(Format.date(undefined, undefined), "")
    }

    function test_dateTime() {
        compare(Format.dateTime("2024-05-06T14:05:00"), "06/05/24 14:05")
        compare(Format.dateTime(undefined), "")
    }

    function test_duration() {
        compare(Format.duration(50136), "13 h 56 min")
        compare(Format.duration(2700), "45 min")
        compare(Format.duration(10), "1 min")
        compare(Format.duration(undefined), "")
    }

    function test_count() {
        compare(Format.count(1, "book"), "1 book")
        compare(Format.count(0, "book"), "0 books")
        compare(Format.count(3, "other"), "3 others")
    }

    function test_formats() {
        compare(Format.formats(["epub", "m4b"]), "EPUB, M4B")
        compare(Format.formats([]), "")
    }

    function test_fileSize() {
        compare(Format.fileSize(2000000), "1.9 MB")
        compare(Format.fileSize(100), "1 KB")
    }
}
