"""Deixa as fontes do Noto mais leves sem mudar como o texto aparece.

- Fontes variáveis (com vários pesos num arquivo só) viram só o peso normal:
  o Flutter já usa o peso padrão delas.
- Mantém só os caracteres usados em português e em notas (acentos, pontuação,
  símbolos comuns). Caracteres de fora caem na fonte do sistema.
"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

UNICODES = (
    list(range(0x20, 0x7F))        # ASCII
    + list(range(0xA0, 0x180))     # Latin-1 e Latin Extended-A (acentos)
    + list(range(0x2000, 0x2070))  # pontuação geral (— … “ ” •)
    + [0x20AC, 0x20BD, 0x2122, 0x2190, 0x2191, 0x2192, 0x2193]
    + list(range(0x2600, 0x2700))  # ☐ ☑ ★ e outros símbolos
    + [0x2713, 0x2714, 0x2715, 0x2716, 0xFFFD]
)

total_before = total_after = 0
for path in sys.argv[1:]:
    before = os.path.getsize(path)
    try:
        font = TTFont(path)
        if "fvar" in font:
            axes = {axis.axisTag: axis.defaultValue for axis in font["fvar"].axes}
            if "wght" in axes:
                axes["wght"] = 400 if axes["wght"] != 700 else 700
            font = instancer.instantiateVariableFont(font, axes)
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        options.glyph_names = False
        options.hinting = False
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=UNICODES)
        subsetter.subset(font)
        font.save(path)
    except Exception as error:  # Se algo falhar, a fonte original continua.
        print(f"::warning::Não reduzi {os.path.basename(path)}: {error}")
    after = os.path.getsize(path)
    total_before += before
    total_after += after
    print(f"{os.path.basename(path):34} {before/1024:8.0f} KB -> {after/1024:6.0f} KB")

print(
    f"::notice::Fontes: {total_before/1048576:.1f} MB -> {total_after/1048576:.1f} MB"
)
