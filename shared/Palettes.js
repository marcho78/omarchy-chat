.pragma library

// The colour sets the Yapper look can use. Each palette carries the same
// tokens (`bg`, `bg2`, `surface`, `line`, `fg`, `muted`, `accent`, `accent2`,
// `ok`, `warn`, `bad`, `desk`, `own`, `chip`, `hover`, `sel`) plus `light`
// for the tones that flip on a light background. `omarchy` is built from
// the shell's theme at runtime (see omarchy()); the rest are fixed.

function rgba(r, g, b, a) { return Qt.rgba(r / 255, g / 255, b / 255, a) }

var themes = {
  tokyonight: { label: "Tokyo Night", light: false, v: { bg: "#1a1b26", bg2: "#16161e", surface: "#24283b", line: "#2b3050", fg: "#c0caf5", muted: "#59618a", accent: "#7aa2f7", accent2: "#7dcfff", ok: "#9ece6a", warn: "#e0af68", bad: "#f7768e", desk: "#0d0e15", own: "#2c3557", chip: rgba(192, 202, 245, 0.06), hover: rgba(122, 162, 247, 0.10), sel: rgba(122, 162, 247, 0.18) } },
  catppuccin: { label: "Catppuccin", light: false, v: { bg: "#1e1e2e", bg2: "#181825", surface: "#313244", line: "#3b3b52", fg: "#cdd6f4", muted: "#7f849c", accent: "#89b4fa", accent2: "#94e2d5", ok: "#a6e3a1", warn: "#f9e2af", bad: "#f38ba8", desk: "#11111b", own: "#35395a", chip: rgba(205, 214, 244, 0.06), hover: rgba(137, 180, 250, 0.10), sel: rgba(137, 180, 250, 0.18) } },
  gruvbox: { label: "Gruvbox", light: false, v: { bg: "#282828", bg2: "#1d2021", surface: "#3c3836", line: "#504945", fg: "#ebdbb2", muted: "#928374", accent: "#83a598", accent2: "#8ec07c", ok: "#b8bb26", warn: "#fabd2f", bad: "#fb4934", desk: "#171819", own: "#45403a", chip: rgba(235, 219, 178, 0.06), hover: rgba(131, 165, 152, 0.12), sel: rgba(131, 165, 152, 0.20) } },
  everforest: { label: "Everforest", light: false, v: { bg: "#2d353b", bg2: "#272e33", surface: "#374145", line: "#45535b", fg: "#d3c6aa", muted: "#859289", accent: "#a7c080", accent2: "#7fbbb3", ok: "#a7c080", warn: "#dbbc7f", bad: "#e67e80", desk: "#1e2326", own: "#3f4c47", chip: rgba(211, 198, 170, 0.06), hover: rgba(167, 192, 128, 0.10), sel: rgba(167, 192, 128, 0.18) } },
  rosepine: { label: "Rosé Pine", light: false, v: { bg: "#191724", bg2: "#1f1d2e", surface: "#26233a", line: "#322f4a", fg: "#e0def4", muted: "#6e6a86", accent: "#c4a7e7", accent2: "#9ccfd8", ok: "#9ccfd8", warn: "#f6c177", bad: "#eb6f92", desk: "#12101c", own: "#2f2a45", chip: rgba(224, 222, 244, 0.06), hover: rgba(196, 167, 231, 0.10), sel: rgba(196, 167, 231, 0.18) } },
  matte: { label: "Matte Black", light: false, v: { bg: "#141414", bg2: "#0e0e0e", surface: "#1e1e1e", line: "#2b2b2b", fg: "#e8e8e8", muted: "#8a8a8a", accent: "#d4a373", accent2: "#c9c9c9", ok: "#9bb48a", warn: "#d4a373", bad: "#cf6a6a", desk: "#070707", own: "#242424", chip: rgba(255, 255, 255, 0.05), hover: rgba(255, 255, 255, 0.055), sel: rgba(255, 255, 255, 0.10) } },
  latte: { label: "Catppuccin Latte", light: true, v: { bg: "#eff1f5", bg2: "#e6e9ef", surface: "#dce0e8", line: "#ccd0da", fg: "#4c4f69", muted: "#7c7f93", accent: "#1e66f5", accent2: "#179299", ok: "#40a02b", warn: "#df8e1d", bad: "#d20f39", desk: "#c5c9d4", own: "#d8e2fb", chip: rgba(76, 79, 105, 0.06), hover: rgba(30, 102, 245, 0.07), sel: rgba(30, 102, 245, 0.14) } }
}

// Order for pickers: the shell's theme first, then the fixed palettes.
var order = ["omarchy", "tokyonight", "catppuccin", "gruvbox", "everforest", "rosepine", "matte", "latte"]

function mix(a, b, t) {
  a = Qt.color(a); b = Qt.color(b)
  return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
}
function alpha(c, a) { c = Qt.color(c); return Qt.rgba(c.r, c.g, c.b, a) }
function luminance(c) { c = Qt.color(c); return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

// The shell's theme as a palette. The theme gives five colours; the rest
// are blends of those so the result sits with the desktop.
function omarchy(background, foreground, accent, muted, urgent) {
  var light = luminance(background) > 0.5
  var black = light ? "#ffffff" : "#000000"
  return {
    label: "Omarchy theme", light: light, v: {
      bg: Qt.color(background), bg2: mix(background, black, 0.18), surface: mix(background, foreground, 0.07), line: mix(background, foreground, 0.14),
      fg: Qt.color(foreground), muted: Qt.color(muted), accent: Qt.color(accent), accent2: mix(accent, foreground, 0.35),
      ok: light ? "#40a02b" : "#9ece6a", warn: light ? "#df8e1d" : "#e0af68", bad: Qt.color(urgent),
      desk: mix(background, black, 0.4), own: mix(background, accent, 0.18),
      chip: alpha(foreground, 0.06), hover: alpha(accent, 0.10), sel: alpha(accent, 0.18)
    }
  }
}

// Per-user colour for names and avatars: a stable hue from the id, toned
// for the palette's background.
var hues = [200, 340, 25, 150, 265, 45, 300, 180, 90, 320, 15, 225]
function hueOf(id) {
  var h = 5381, s = String(id)
  for (var i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0
  return hues[Math.abs(h) % hues.length]
}
function colorOf(id, light) { return Qt.hsla(hueOf(id) / 360, 0.58, light ? 0.38 : 0.70, 1) }
