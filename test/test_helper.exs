nt_font_files = ["Arial.ttf", "Arial Bold.ttf", "Microsoft Sans Serif.ttf"]

# As fontes da NT 008 não podem ser redistribuídas; o teste que as usa roda só onde o sistema as tem.
nt_fonts_installed? =
  Enum.all?(nt_font_files, &File.regular?(Path.join("/System/Library/Fonts/Supplemental", &1)))

ExUnit.start(exclude: if(nt_fonts_installed?, do: [], else: [:nt_fonts]))
