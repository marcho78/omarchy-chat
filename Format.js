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
function linkify(plain) {
  var out = escapeHtml(plain).replace(URL_RE, function(m) {
    var href = m.indexOf("://") === -1 ? "https://" + m : m
    return '<a href="' + href + '">' + m + '</a>'
  })
  return out.replace(/\n/g, "<br>")
}

// Matrix formatted_body -> something Qt's rich text can show. Qt handles a
// small HTML subset; strip what it cannot and neutralise mx-reply quotes.
function cleanHtml(html) {
  var s = String(html)
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
