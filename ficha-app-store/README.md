# Ficha de la App Store · capturas y vista previa por idioma

El molde que saca, para un idioma, las 10 capturas del set B («Primer plano y objetos») en iPhone 6,9", iPhone 6,5" e
iPad 13", sus hojas de contacto y la vista previa (vídeo) con y sin música. Todo recibe **un solo parámetro: el
idioma** (`es`, `en`, `pt-BR`). El inglés sirve para en-US y en-GB.

Las salidas viven fuera del repo, en `~/Claude/propuestas/ficha-app-store-2.1/<idioma>/` (cámbialo con
`YALA_FICHA_SALIDA`). Subirlas a App Store Connect es de Lola; aquí no se sube ni se manda a revisión nada.

## Una corrida

Con la app compilada (scheme **Yala**, configuración Debug) y **un solo simulador encendido a la vez**:

```bash
cd ficha-app-store
export YALA_FICHA_APP=/Volumes/ExtDev/DerivedData/Yala-<hash>/Build/Products/Debug-iphonesimulator/Yala.app

capturas/recibo.sh en                 # la foto del recibo que la app «lee» (sale de textos/en.js)
capturas/conducir.sh en iphone        # las 10 pantallas del iPhone 17 Pro   → en/capturas/s-*.png
video/grabar.sh en todas              # las 4 escenas del vídeo, en el iPhone → en/video/tomas/
xcrun simctl shutdown all
capturas/conducir.sh en ipad          # las 10 del iPad Pro 13"               → en/capturas/i-*.png
xcrun simctl shutdown all

capturas/render.sh en                 # láminas: en/6.9, en/6.5, en/ipad-13 (PNG sin alfa)
python3 capturas/hojas.py en iphone && python3 capturas/hojas.py en iphone65 && python3 capturas/hojas.py en ipad
video/render.sh en                    # en/video/yala-preview-6.9.mp4 y -musica.mp4
```

`conducir.sh` y `grabar.sh` empiezan **borrando el simulador** (`simctl erase`), le ponen el idioma de sistema de la
ficha y reinstalan la app (la que esté instalada o la de `YALA_FICHA_APP`). Después siembran una vez y relanzan para
cada pantalla. `YALA_FICHA_SIN_SEMBRAR=1` se salta las dos cosas, para repetir una pantalla suelta:
`YALA_FICHA_SIN_SEMBRAR=1 capturas/conducir.sh en ipad grupo`.

## Sumar un idioma (de, fr, it, ja…)

1. **`textos/<idioma>.js`**: el fichero de Lola, con la misma forma que `en.js` (`TXT`, `OBJ`, `VIDEO`).
2. **Una línea en `idiomas.json`**: `appleLanguages`, `appleLocale`, `moneda`, el `.lproj` de la app y
   `monedaExtranjera` (la `foreignCurrency` de su fila en la semilla: la cuenta de la 09).
3. **Si su divisa es nueva** (EUR, JPY), su fila en `Yala/Seed/DevSeedFicha.swift → cifras(forMainCurrency:)`, con las
   cifras de su `OBJ`: factor de los gastos del viaje, divisa y saldo de la cuenta extranjera, Teléfono y Spotify,
   efectivo y deuda de la tarjeta (la 08) y el importe de la pizza del vídeo, que tiene que ser creíble en esa divisa
   (`video/grabar.sh` escribe ese mismo número).
   Los nombres (viaje, amigos, gastos, la frase del chat, el comercio del recibo…) ya están en los 16 idiomas de la
   app, con las claves `devseed.ficha.*` y `uitestDemo.*`; si el texto de Lola dice otra cosa, se cambian ahí.
4. **La corrida de arriba.** Las cifras de la semilla salen iguales que en español porque la app cree que es el
   13-oct-2026 (ver «El reloj»).
5. **Los cortes del vídeo**, `video/cortes/<idioma>.json`, medidos sobre las tomas de ese idioma (abajo).

Si un texto no cabe, se ajusta la **composición** en `capturas/sets.js → AJUSTES[<idioma>]` (tamaño del titular,
posición de un chip). Los textos no se tocan: son de Lola.

## Lo que hay dentro

| Ruta | Qué es |
|---|---|
| `textos/` | Los textos de Lola por idioma, copia literal de `~/Claude/lola-borradores/2.1/textos-capturas/` (16-oct-2026). |
| `idiomas.json` | Idioma → `AppleLanguages`, `AppleLocale`, divisa y `.lproj`; el reloj; los simuladores. |
| `comun.sh` | Lo que comparten los scripts: la configuración del idioma, `udid`, `barra` y `preparar`. |
| `reloj/` | `reloj.c` y su `compilar.sh`: la app del simulador ve la hora desplazada al reloj de `idiomas.json`. |
| `capturas/lanzar.sh` | Lanza la app con el idioma, la divisa, el tema oscuro, Pro, la semilla `ficha` y el reloj. |
| `capturas/conducir.sh` · `ui.sh` | Recorren las 10 pantallas con `axe` (por identificador o etiqueta) y capturan. |
| `capturas/cap.sh` | Una captura suelta, con una vista reducida en `_vistas/` para revisarla. |
| `capturas/recibo.html` · `recibo.sh` | La foto del recibo de `OBJ["02_foto"].boleta`. |
| `capturas/lamina.html` · `lamina.css` · `sets.js` | La composición de las láminas; los textos salen de `TXT` y `OBJ`. |
| `capturas/render.sh` · `hojas.py` | Chrome headless → PNG; hojas de contacto. |
| `video/grabar.sh` | Graba cada escena del vídeo con `simctl io recordVideo` y apunta los toques. |
| `video/cortes/<idioma>.json` | Los tramos de cada toma y los toques, medidos por idioma. |
| `video/tomas.py` · `index.html` · `render.sh` | La pista de pantalla, la composición con las frases de `VIDEO` y el render (HyperFrames + ffmpeg). |
| `assets/` | El logo y GSAP (licencia estándar de GreenSock). La música (`pop.mp3`, Mixkit) no está en el repo: `YALA_FICHA_MUSICA`. |

## El reloj

Las capturas citan cifras que dependen del día: lo gastado en el mes, lo que queda del presupuesto, «19 días»,
«Teléfono en 2 días». La semilla y la app las calculan con el reloj, así que `lanzar.sh` inyecta `reloj/` en la app
(`SIMCTL_CHILD_DYLD_INSERT_LIBRARIES`) y la app cree que es el **13-oct-2026 a las 9:41**: la semilla `realista` da
ese día exactamente las cifras del set en español (S/ 4,686 del mes, Comer fuera 1,330 de 1,800, 74 %, 19 días). No
toca el binario de Yala ni el reloj del simulador.

## Medir los cortes del vídeo

`grabar.sh` deja cada toma a 30 fps y sus marcas (`<escena>.marcas.json`, con los toques en puntos de pantalla). Las
esperas varían de una grabación a otra, así que los tramos `[desde, hasta, velocidad]` se miden mirando los
fotogramas (una tira cada 0,5 s basta) y se escriben en `video/cortes/<idioma>.json`. Cada escena dura unos 6-7 s
(IA, foto, voz) y Grupos unos 5; el vídeo queda entre 27 y 28 s (Apple admite de 15 a 30). Si un toque de las marcas
cae desplazado, se fija a mano en `"toques"` de la escena.

## Trampas medidas (16-oct-2026)

- **«Tus cuentas» (08) enseña las cuentas.** La semilla añade efectivo y tarjeta de crédito en la divisa principal,
  `lanzar.sh` las pone primero en el carrusel (`-accountsSortOrderNames`, con los nombres del `.strings` de la app) y
  `conducir.sh panel` despliega «Tus finanzas» antes de capturar. `divisas` busca la tarjeta de la cuenta extranjera
  por su nombre y pasa el carrusel hasta verla entera.
- **El Panel al relanzar.** Sin `-uitest-reset`, la app a veces pasaba al Panel con todas las secciones en vez del de
  usuario nuevo. `lanzar.sh` fija el Panel de `PanelDefaults` por argumentos de arranque; si cambian esos
  predeterminados, cambian allí.
- **La barra de estado del iPad.** Escribe la fecha en el idioma del sistema del simulador (por eso `preparar` lo
  cambia) y una fecha ISO en `simctl status_bar --time` la escribe siempre en inglés y con el día de la semana de hoy:
  `barra` pone solo la hora y el iPad la fecha real en su idioma.
- **`simctl io recordVideo` no escribe fotogramas cuando la pantalla no cambia**: un final quieto se perdía.
  `grabar.sh` congela el último fotograma hasta el tiempo real de la grabación.
- **`axe` tarda en tocar** (~1-2 s por llamada): las marcas se apuntan después del toque.
- **`axe type` no escribe tildes ni «ñ»**: las frases del chat van sin ellas.
- Las capturas en español son las de v2 (`~/Claude/propuestas/capturas-app-store-final-v2-2026-10-13/capturas/`), sin
  recapturar; el molde las renderiza igual (`capturas/render.sh es`). El vídeo en español sigue siendo el de
  `~/Claude/propuestas/assets-asc-2.1-2026-10-13/`: no hay `video/cortes/es.json` porque no se regrabó con el molde.
