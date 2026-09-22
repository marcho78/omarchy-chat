#!/usr/bin/env python3
"""Regenerate shared/Icons.js from fonts/phosphor-regular.css."""
import re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
css = (root / 'fonts' / 'phosphor-regular.css').read_text()
pairs = re.findall(r'\.ph\.ph-([a-z0-9-]+):before\s*\{\s*content:\s*"\\([0-9a-f]{4})";', css)
lines = ['.pragma library', '', '// Phosphor icon names -> glyphs, generated from fonts/phosphor-regular.css',
         '// by scripts/gen-icons.py. Do not edit by hand.', '', 'var map = {']
lines += ['  "%s": "\\u%s",' % (n, cp) for n, cp in pairs]
lines[-1] = lines[-1].rstrip(',')
lines += ['}', '', 'function glyph(name) { return map[name] || "" }', 'function has(name) { return map[name] !== undefined }', '']
(root / 'shared' / 'Icons.js').write_text('\n'.join(lines))
print('wrote shared/Icons.js with', len(pairs), 'icons')
