#!/usr/bin/env bash
# Vista previa de la App Store de un idioma: tomas → HyperFrames → codificación final con la especificación de ASC.
#   video/render.sh <idioma>
#   886×1920 · 30 fps · H.264 High@4.0 progresivo · ~11 Mbps · AAC estéreo 256 kbps 48 kHz.
# Sale en <salida>/<idioma>/video/: yala-preview-6.9.mp4 (pista de audio en silencio) y yala-preview-6.9-musica.mp4.
# Necesita las tomas del idioma (video/grabar.sh) y sus cortes (video/cortes/<idioma>.json).
set -euo pipefail
source "$(cd "$(dirname "$0")/.." && pwd)/comun.sh" "$1"
OUT="$SALIDA/video"; B="$OUT/_build"
python3 "$MOLDE/video/tomas.py" "$IDIOMA"
cp "$MOLDE/video/hyperframes.json" "$B/"
cp "$MOLDE/assets/gsap.min.js" "$MOLDE/assets/logo.png" "$B/assets/"
FIN=$(python3 -c "import json,re;t=open('$B/config.js').read();c=json.loads(re.search(r'= (.*);',t,re.S).group(1));print(c['fin'],c['pantallaDuracion'])")
read -r T_FIN T_PANTALLA <<<"$FIN"
sed -e "s/__FIN__/$T_FIN/" -e "s/__PANTALLA__/$T_PANTALLA/" "$MOLDE/video/index.html" > "$B/index.html"
(cd "$B" && npx --yes hyperframes@0.8.138 render -q high -o "$B/_crudo.mp4" > "$B/render.log" 2>&1) || { echo "✗ mira $B/render.log"; exit 1; }
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$B/_crudo.mp4")
V=(-vf "scale=886:1920:flags=lanczos,fps=30,format=yuv420p" -c:v libx264 -profile:v high -level:v 4.0 -b:v 11M -minrate 11M -maxrate 11M -bufsize 11M
   -x264-params "nal-hrd=cbr" -r 30 -g 30 -movflags +faststart -t "$DUR")
# 1) Principal: audio en silencio (Apple pide estéreo AAC; una pista muda evita rechazos de subida).
ffmpeg -v error -y -i "$B/_crudo.mp4" -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=48000" -map 0:v -map 1:a \
  "${V[@]}" -c:a aac -b:a 256k -ar 48000 -ac 2 -shortest "$OUT/yala-preview-6.9.mp4"
# 2) Con la música de la serie (Pop Track 03, Mixkit 729): entra suave y se apaga con el cierre.
M="${YALA_FICHA_MUSICA:-$HOME/Claude/propuestas/reels-hyperframes-v3-2026-10-13/plantilla/musica/pop.mp3}"
[ -f "$M" ] || { echo "✗ no está la música ($M): pon YALA_FICHA_MUSICA"; exit 1; }
ffmpeg -v error -y -i "$B/_crudo.mp4" -i "$M" -map 0:v -map 1:a "${V[@]}" \
  -af "atrim=0:$DUR,asetpts=PTS-STARTPTS,afade=t=in:d=0.6,afade=t=out:st=$(python3 -c "print(round($DUR-1.8,2))"):d=1.8,loudnorm=I=-18:TP=-2:LRA=11" \
  -c:a aac -b:a 256k -ar 48000 -ac 2 "$OUT/yala-preview-6.9-musica.mp4"
for f in "$OUT"/yala-preview-6.9*.mp4; do
  echo "✓ $(basename "$f") · $(ffprobe -v error -select_streams v -show_entries stream=width,height,r_frame_rate,profile,level,bit_rate -of csv=p=0 "$f") · $(printf %.2f "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")") s"
done
