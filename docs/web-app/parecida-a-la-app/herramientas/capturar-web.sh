#!/bin/zsh
# capturar-web.sh <ruta> <nombre> <claro|oscuro> <escritorio|movil> — necesita servidor-maqueta.mjs en :8787
S=${SCRATCH:?pon SCRATCH=<carpeta temporal>}
CH=~/Library/Caches/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-mac-arm64/chrome-headless-shell
dark=""; [[ $3 == oscuro ]] && dark="--blink-settings=preferredColorScheme=0" || dark="--blink-settings=preferredColorScheme=1"
if [[ $4 == movil ]]; then
  $CH --headless --hide-scrollbars --lang=es-419 $dark --window-size=390,844 --force-device-scale-factor=2 --user-data-dir=$S/chr-$$ --virtual-time-budget=5000 --screenshot=$S/cap/web-$2-$3-movil.png "http://localhost:8787/marco.html#$1" >/dev/null 2>&1
  magick $S/cap/web-$2-$3-movil.png -crop 780x1688+0+0 +repage $S/cap/web-$2-$3-movil.png
else
  $CH --headless --hide-scrollbars --lang=es-419 $dark --window-size=1280,820 --user-data-dir=$S/chr-$$ --virtual-time-budget=5000 --screenshot=$S/cap/web-$2-$3-escritorio.png "http://localhost:8787$1" >/dev/null 2>&1
fi
rm -rf $S/chr-$$
echo ok $2 $3 $4
