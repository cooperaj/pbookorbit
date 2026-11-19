.pragma library

// "12/03/1948" from an ISO date, else the year alone ("1948"), else ""
function date(isoDate, year) {
    return isoDate ? Qt.formatDate(new Date(isoDate), "dd/MM/yyyy") : (year || "").toString()
}

// "12/03/48 14:05" from an ISO date and time, else ""
function dateTime(isoDateTime) {
    return isoDateTime ? Qt.formatDateTime(new Date(isoDateTime), "dd/MM/yy hh:mm") : ""
}

// "13 h 56 min", "45 min", or "" if unknown
function duration(seconds) {
    if (!seconds)
        return ""
    const minutes = Math.max(1, Math.round(seconds / 60))
    const hours = Math.floor(minutes / 60)
    return hours > 0 ? hours + " h " + (minutes % 60) + " min" : minutes + " min"
}

// "1 book", "3 books"; plural for nouns that don't just add an s
function count(n, noun, plural) {
    return n + " " + (n === 1 ? noun : plural || noun + "s")
}

// "EPUB, M4B" from ["epub", "m4b"]
function formats(list) {
    return list.map(format => format.toUpperCase()).join(", ")
}

// Whether text is HTML, as some sources send descriptions, rather than plain text (whose
// line breaks HTML would drop). Only a closing tag of an element descriptions use, or a
// line break tag, counts, so plain text with a stray "<", or "a <b and c>", stays plain.
const htmlTag = /<\/(p|div|span|a|b|i|u|em|strong|ul|ol|li|h[1-6]|blockquote)\s*>|<br\s*\/?>/i
function isHtml(text) {
    return htmlTag.test(text || "")
}

// "1.9 MB", "820 KB" or "1.1 GB"
function fileSize(bytes) {
    return bytes >= 1024 * 1024 * 1024 ? (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
         : bytes >= 1024 * 1024 ? (bytes / (1024 * 1024)).toFixed(1) + " MB"
         : Math.max(1, Math.round(bytes / 1024)) + " KB"
}
