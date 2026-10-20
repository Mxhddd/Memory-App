"""Redraw Pixelify Sans '2' and '5' so they can't be read as '8' and 'S' (5x7 pixel grid)."""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

GLYPHS = {
    'two': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
    'five': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
}
X0, X1, Y0, Y1 = 61, 536, -11, 636          # ink box shared by the font's digits

def draw(rows, glyphset):
    pen = TTGlyphPen(glyphset)
    cw, rh = (X1 - X0) / 5, (Y1 - Y0) / 7
    for r, row in enumerate(rows):
        c = 0
        while c < 5:
            if row[c] != '#': c += 1; continue
            e = c
            while e < 5 and row[e] == '#': e += 1
            x0, x1 = round(X0 + c * cw), round(X0 + e * cw)
            top, bot = round(Y1 - r * rh) + (0 if r == 0 else 4), round(Y1 - (r + 1) * rh) - (0 if r == 6 else 4)
            pen.moveTo((x0, bot)); pen.lineTo((x0, top)); pen.lineTo((x1, top)); pen.lineTo((x1, bot)); pen.closePath()
            c = e
    return pen.glyph()

src, out = sys.argv[1], sys.argv[2]
font = TTFont(src)
gs = font.getGlyphSet()
for name, rows in GLYPHS.items():
    font['glyf'][name] = draw(rows, gs)
font.save(out)
print('patched', out)
