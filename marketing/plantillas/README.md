# Plantillas HTML para redes (sin Figma)

Tres lienzos a tamaño real. Se editan en el HTML y se exportan a PNG con Chrome headless, igual que
el post diario. El sistema visual está en [`../marca/`](../marca/).

| Plantilla | Tamaño | Uso |
|---|---|---|
| [`post-1080x1350.html`](post-1080x1350.html) | 1080×1350 (4:5) | Post de IG, imagen de X |
| [`reel-1080x1920.html`](reel-1080x1920.html) | 1080×1920 (9:16) | Portada de Reel. El vídeo sale de [`../remotion/`](../remotion/). Con `?guias` en la URL se ven las zonas que tapa IG |
| [`carrusel-1080x1350.html`](carrusel-1080x1350.html) | 5 × 1080×1350 | Carrusel: portada, tres láminas con captura y cierre |

`yala.css` guarda los tokens de color, la tipografía y el pill. `destellos.js` pinta los destellos
que se describen en `data-destellos="x,y,tamaño,color,giro,opacidad; …"`.

## Cómo se edita

1. Copia la plantilla en esta misma carpeta con un nombre propio, por ejemplo `2026-W43-voz.html`.
2. Cambia el `data-acento` (`rosa`, `azul`, `teal` o `violeta`) y los textos del pill, el titular y el subtítulo.
3. En el titular, envuelve **una sola palabra** en `<u>…</u>`. Esa palabra sale subrayada.
4. Cambia la captura en el `<img>` de `.telefono`. Las que hay están en `../screenshots-appstore/generator/public/screenshots/es/`.
   **Ojo:** esas capturas son de 2.0. Si la pieza enseña algo de 2.1, hay que sacar antes su captura.

## Cómo se exporta a PNG

```bash
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
F="$PWD/post-1080x1350.html"            # o el reel, o el carrusel
"$C" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --virtual-time-budget=3000 --window-size=1080,1350 --screenshot="$PWD/out.png" "file://$F"
# Reel: --window-size=1080,1920.  Carrusel: una pasada por lámina, con "file://$F#1" … "#5".
```

Los PNG no se commitean: van a la carpeta de entregas o directamente a publicar.
