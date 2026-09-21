.pragma library

// Text helpers for message rendering. Pure functions, no Qt objects.

var PALETTE = [200, 340, 25, 150, 265, 45, 300, 180, 90, 320, 15, 225]

function hashString(s) {
  var h = 5381
  for (var i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0
  return Math.abs(h)
}

// A stable hue per user id, from a palette that stays readable on both
// light and dark backgrounds.
function hueFor(userId) {
  return PALETTE[hashString(String(userId)) % PALETTE.length]
}

function initial(name) {
  var s = String(name || "").trim()
  if (s.charAt(0) === "@") s = s.substring(1)
  return s.length ? s.charAt(0).toUpperCase() : "?"
}

function escapeHtml(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

var URL_RE = /((?:https?:\/\/|www\.)[^\s<>"']+[^\s<>"'.,;:!?)])/g

// Plain text -> rich text with clickable links and preserved line breaks.
function linkify(plain, linkColor) {
  var style = linkColor ? ' style="color:' + linkColor + '"' : ""
  var out = escapeHtml(plain).replace(URL_RE, function(m) {
    var href = m.indexOf("://") === -1 ? "https://" + m : m
    return '<a href="' + href + '"' + style + '>' + m + '</a>'
  })
  return out.replace(/\n/g, "<br>")
}

// Matrix formatted_body -> something Qt's rich text can show. Qt handles a
// small HTML subset; strip what it cannot and neutralise mx-reply quotes.
function cleanHtml(html, linkColor) {
  var s = String(html)
  if (linkColor) s = s.replace(/<a\s/gi, '<a style="color:' + linkColor + '" ')
  s = s.replace(/<mx-reply>[\s\S]*?<\/mx-reply>/gi, "")
  s = s.replace(/<img[^>]*>/gi, "[image]")
  s = s.replace(/<(script|style)[\s\S]*?<\/\1>/gi, "")
  s = s.replace(/<blockquote>/gi, '<blockquote style="margin-left:12px">')
  s = s.replace(/<code>/gi, '<code style="font-family:monospace">')
  return s
}

function dayLabel(ts, now) {
  var d = new Date(ts), n = new Date(now)
  var sameDay = function(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
  if (sameDay(d, n)) return "Today"
  var y = new Date(n); y.setDate(n.getDate() - 1)
  if (sameDay(d, y)) return "Yesterday"
  return d.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
}

function isSameDay(a, b) {
  var x = new Date(a), y = new Date(b)
  return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth() && x.getDate() === y.getDate()
}

// Semantic version compare: 1 if a > b, -1 if a < b, 0 if equal or unparsable.
function compareVersions(a, b) {
  var pa = String(a || "").replace(/^v/, "").split(".").map(function(x) { return parseInt(x, 10) || 0 })
  var pb = String(b || "").replace(/^v/, "").split(".").map(function(x) { return parseInt(x, 10) || 0 })
  for (var i = 0; i < 3; i++) {
    var x = pa[i] || 0, y = pb[i] || 0
    if (x > y) return 1
    if (x < y) return -1
  }
  return 0
}

// Collapse newlines and runs of whitespace so a subtitle stays one line
// and elides properly.
function oneLine(s) {
  return String(s || "").replace(/\s+/g, " ").trim()
}

function fileSize(bytes) {
  var n = Number(bytes) || 0
  if (n < 1024) return n + " B"
  if (n < 1024 * 1024) return (n / 1024).toFixed(n < 10240 ? 1 : 0) + " KB"
  if (n < 1024 * 1024 * 1024) return (n / 1048576).toFixed(1) + " MB"
  return (n / 1073741824).toFixed(2) + " GB"
}

// Escape for rich text and mark the query's words in the accent colour.
function highlightMatch(text, query, color) {
  var plain = String(text).replace(/\s+/g, " ")
  // Keep the snippet around the first match so long messages stay short.
  var first = String(query || "").split(/\s+/)[0] || ""
  var at = first ? plain.toLowerCase().indexOf(first.toLowerCase()) : -1
  var start = at > 120 ? at - 80 : 0
  if (plain.length - start > 260) plain = (start > 0 ? "…" : "") + plain.substr(start, 260) + "…"
  else if (start > 0) plain = "…" + plain.substr(start)
  var out = escapeHtml(plain)
  var words = String(query || "").split(/\s+/).filter(function(w) { return w.length > 1 })
  for (var i = 0; i < words.length; i++) {
    var re = new RegExp("(" + words[i].replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")", "ig")
    out = out.replace(re, '<span style="color:' + color + '"><b>$1</b></span>')
  }
  return out
}
