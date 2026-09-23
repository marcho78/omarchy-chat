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
    var href = safeUrl(m.indexOf("://") === -1 ? "https://" + m : m)
    if (href === "") return m
    return '<a href="' + escapeAttr(href) + '"' + style + '>' + m + '</a>'
  })
  return out.replace(/\n/g, "<br>")
}

// ---------- HTML from other people ----------
// A message's formatted_body is written by whoever sent it. It is rebuilt
// here from scratch: every tag is checked against ALLOWED_TAGS, every
// attribute against the tag's list, every href against SAFE_SCHEMES, and
// all text is re-escaped. Anything else becomes text or disappears.

// Tag -> attributes kept. Everything Qt's rich text can draw from the Matrix
// formatting subset; nothing that executes, embeds, or loads.
var ALLOWED_TAGS = {
  b: [], strong: [], i: [], em: [], u: [], s: [], del: [], strike: [],
  code: [], pre: [], blockquote: [], p: [], br: [], hr: [],
  ul: [], ol: [], li: [], h1: [], h2: [], h3: [], h4: [], h5: [], h6: [],
  sup: [], sub: [], div: [], span: ["data-mx-color"], font: ["color", "data-mx-color"],
  a: ["href"],
  table: [], thead: [], tbody: [], tr: [], th: [], td: []
}
// Tags whose whole content is dropped, not just the tag.
var DROPPED_WITH_CONTENT = { script: 1, style: 1, "mx-reply": 1, iframe: 1, object: 1, embed: 1, svg: 1, math: 1, template: 1, noscript: 1 }
var VOID_TAGS = { br: 1, hr: 1, img: 1 }
var SAFE_SCHEMES = ["https://", "http://", "mailto:"]
var COLOR_RE = /^#[0-9a-fA-F]{6}$/
// Text nodes: keep the entities we know, escape stray ampersands and brackets.
var ENTITY_RE = /&(?:amp|lt|gt|quot|apos|nbsp|#\d{1,7}|#x[0-9a-fA-F]{1,6});/g

// A URL the desktop may open: an explicit safe scheme, no control characters. "" otherwise.
function safeUrl(url) {
  var u = String(url || "").trim()
  if (u.length > 2048 || /[\u0000-\u001f\u007f]/.test(u)) return ""
  var lower = u.toLowerCase()
  for (var i = 0; i < SAFE_SCHEMES.length; i++) if (lower.indexOf(SAFE_SCHEMES[i]) === 0) return u
  return ""
}

function escapeText(t) {
  // Entities the sender wrote survive; every other & < > " is escaped.
  var out = ""
  var last = 0
  var m
  ENTITY_RE.lastIndex = 0
  while ((m = ENTITY_RE.exec(t)) !== null) {
    out += escapeHtml(t.substring(last, m.index)) + m[0]
    last = m.index + m[0].length
  }
  return out + escapeHtml(t.substring(last))
}

function escapeAttr(v) {
  return String(v).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// name="value" | name='value' | name=value | name
var ATTR_RE = /([A-Za-z_:][-A-Za-z0-9_:.]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g

function parseAttrs(raw) {
  var attrs = {}
  var m
  ATTR_RE.lastIndex = 0
  while ((m = ATTR_RE.exec(raw)) !== null) {
    var value = m[2] !== undefined ? m[2] : (m[3] !== undefined ? m[3] : (m[4] !== undefined ? m[4] : ""))
    attrs[m[1].toLowerCase()] = value
  }
  return attrs
}

// Rebuild one opening tag from its allowed attributes, or "" to drop it.
function buildTag(name, attrs, linkColor) {
  var keep = ALLOWED_TAGS[name]
  var out = "<" + name
  if (name === "a") {
    var href = safeUrl(attrs.href)
    if (href === "") return ""          // no safe target: the link text stays as plain text
    out += ' href="' + escapeAttr(href) + '"'
    if (linkColor) out += ' style="color:' + escapeAttr(linkColor) + '"'
  } else if (name === "font" || name === "span") {
    var color = attrs.color || attrs["data-mx-color"] || ""
    if (COLOR_RE.test(color)) out += ' color="' + color + '"'
    if (name === "span") { name = "font" ; out = "<font" + (COLOR_RE.test(color) ? ' color="' + color + '"' : "") }
  } else if (name === "code") {
    out += ' style="font-family:monospace"'
  } else if (name === "blockquote") {
    out += ' style="margin-left:12px"'
  }
  return out + ">"
}

// Matrix formatted_body -> rich text Qt can show, rebuilt from an allowlist.
function cleanHtml(html, linkColor) {
  var src = String(html)
  var out = ""
  var open = []          // names of allowed tags currently open, for balance
  var dropDepth = 0      // inside a tag whose content is dropped
  var dropName = ""
  var inLink = 0, inCode = 0
  var i = 0
  var TAG_RE = /<\/?([A-Za-z][A-Za-z0-9-]*)((?:\s+[^<>]*?)?)\s*\/?>|<!--[\s\S]*?-->|<[^>]*>/g
  TAG_RE.lastIndex = 0
  var m
  while ((m = TAG_RE.exec(src)) !== null) {
    var text = src.substring(i, m.index)
    if (dropDepth === 0 && text !== "") out += textNode(text, inLink || inCode, linkColor)
    i = m.index + m[0].length
    var tok = m[0]
    var name = m[1] ? m[1].toLowerCase() : ""
    if (name === "") continue                            // comments, junk: gone
    var closing = tok.charAt(1) === "/"
    if (dropDepth > 0) {
      if (name === dropName) { if (closing) dropDepth--; else dropDepth++ }
      continue
    }
    if (DROPPED_WITH_CONTENT[name]) {
      if (!closing && !VOID_TAGS[name]) { dropDepth = 1; dropName = name }
      continue
    }
    if (name === "img") { out += "[image]"; continue }
    if (!ALLOWED_TAGS.hasOwnProperty(name)) continue     // unknown tag: its text stays, the tag goes
    var emitted = name === "span" ? "font" : name
    if (closing) {
      var at = open.lastIndexOf(emitted)
      if (at === -1) continue
      // close everything opened after it, then it
      while (open.length > at) {
        var n = open.pop()
        out += "</" + n + ">"
        if (n === "a") inLink--
        if (n === "code" || n === "pre") inCode--
      }
      continue
    }
    if (VOID_TAGS[name]) { out += "<" + name + ">"; continue }
    var attrs = parseAttrs(m[2] || "")
    var built = buildTag(name, attrs, linkColor)
    if (built === "") continue
    out += built
    open.push(emitted)
    if (emitted === "a") inLink++
    if (emitted === "code" || emitted === "pre") inCode++
  }
  var tail = src.substring(i)
  if (dropDepth === 0 && tail !== "") out += textNode(tail, inLink || inCode, linkColor)
  while (open.length) out += "</" + open.pop() + ">"
  return out
}

// A text node: escaped, with bare URLs turned into links unless inside a link or code.
function textNode(text, noLinks, linkColor) {
  if (noLinks) return escapeText(text)
  var style = linkColor ? ' style="color:' + escapeAttr(linkColor) + '"' : ""
  return escapeText(text).replace(/(https?:\/\/[^\s<>"'&]+[^\s<>"'&.,;:!?)])/g, function(u) {
    return '<a href="' + escapeAttr(u) + '"' + style + '>' + u + '</a>'
  })
}

// "10:42" today, "Yesterday", or a short date.
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

// Escape for rich text and mark the query's words in the accent color.
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

function firstUrl(text) {
  var m = String(text || "").match(/https?:\/\/[^\s<>"')\]]+/)
  return m ? m[0] : ""
}

// "10:42" today, "Yesterday", or a short date.
function timeOf(ts) {
  var d = new Date(ts), n = new Date()
  if (isSameDay(ts, n.getTime())) return d.toLocaleTimeString(Qt.locale(), "HH:mm")
  var y = new Date(n); y.setDate(n.getDate() - 1)
  if (isSameDay(ts, y.getTime())) return "Yesterday"
  return d.toLocaleDateString(Qt.locale(), "d MMM")
}

// A glyph for a bridged network; a link for ones the font has no logo for.
function bridgeGlyph(protocol) {
  switch (String(protocol || "")) {
    case "whatsapp": return "󰖣"
    case "discord": return "󰙯"
    case "slack": return "󰒱"
    case "instagram": return "󰋾"
    case "facebook": return "󰈌"
    case "telegram": return "󰒊"
    default: return "󰌷"
  }
}

// Seconds → "m:ss".
function clock(seconds) {
  var t = Math.max(0, Math.floor(Number(seconds) || 0))
  var m = Math.floor(t / 60), sec = t % 60
  return m + ":" + (sec < 10 ? "0" : "") + sec
}
