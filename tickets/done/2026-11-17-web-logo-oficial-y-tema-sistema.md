---
id: 2026-11-17-web-logo-oficial-y-tema-sistema
status: done
priority: medium
area: "web-app, entrada, tema"
created: 2026-11-17
updated: 2026-11-17
source: "Jürgen, 17-nov 17:46 Lima: logo oficial en Yala web, tema inicial según el sistema y sin el estilo de la bienvenida de iOS"
---

# Yala web: logo oficial y tema claro u oscuro según el sistema

## Qué pidió Jürgen

1. El logo oficial de Yala en toda la web, no el cuadrado índigo→rosa de la maqueta.
2. Tema inicial claro u oscuro según el sistema. Liquid Glass morado deja de ser el inicial y queda como extra; quien
   ya lo tenga guardado lo conserva.
3. La entrada y el QR dejan de ser «siempre oscuros» con el fondo de la bienvenida de iOS y siguen el tema de la web.

## Qué cambió para quien usa la web

- **Logo**: la palabra «yala» oficial (morada sobre claro, blanca sobre oscuro) en la entrada, el QR, la cámara, los
  avisos y la barra lateral. El favicon y el ícono de «Añadir a inicio» son el ícono de la app.
- **Tema**: con «Como el sistema» (el de siempre, sin elección guardada) la web se ve clara con el sistema en claro y
  con el oscuro negro de la app con el sistema en oscuro. En Ajustes siguen Como el sistema, Claro, Oscuro y, como
  extra, Liquid Glass. Quien lo eligió antes lo sigue viendo.
- **Entrada**: una tarjeta sobre el fondo de la web, con los botones redondos del resto de la app web. El reto de
  Turnstile se pide en el tema de la página y se lee en los dos.

## Cómo está hecho

- Logos copiados de `Web/public/images/logo.png` y `logo-light.png` (recortado el margen transparente, sin escalar ni
  recolorear) a `webapp/public/logo-oscuro.png` y `logo-claro.png`. Ícono desde `AppIcon.png` de la app:
  `favicon-32.png`, `apple-touch-icon.png`, `icono.png`. Fuera el `favicon.svg` viejo.
- Cada tema de `styles.css` declara `--logo`; la entrada y la barra lateral lo pintan de fondo con la proporción del
  PNG (402 × 308).
- El bloque oscuro por sistema es ahora una copia del «Oscuro» forzado (lo comprueba `test/base-visual.test.ts`).
- `temaEsOscuro()` en `tema.ts` decide el tema de Turnstile, porque `auto` solo mira al sistema.
- `index.html`: el color de la barra del navegador en oscuro pasa a negro, y los enlaces del favicon nuevo. No estaba
  en la lista del encargo; hacía falta para el favicon y la barra.

## Pruebas

- `npm run typecheck` y `npm test` de `webapp/`: 306/306. `test/lote6.test.ts` reescrito para la entrada nueva (sin
  colores propios, tarjeta y botones de la web, logo sin deformar, favicon).
- Capturas antes y después en `docs/web-app/parecida-a-la-app/capturas/logo-y-tema/`, con la maqueta local:
  entrada, QR y barra lateral; claro y oscuro; escritorio y celular (390 px).
