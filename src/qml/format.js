.pragma library

// "12/03/1948" from an ISO date, else the year alone ("1948"), else ""
function date(isoDate, year) {
    return isoDate ? Qt.formatDate(new Date(isoDate), "dd/MM/yyyy") : (year || "").toString()
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
