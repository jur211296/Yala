---
id: 2026-11-16-web-app-lote-6-entrar
status: done
priority: high
area: web
created: 2026-11-17
updated: 2026-11-17
source: encargo 2026-11-17-web-app-lote-6-entrar (maqueta «Yala web como la app», aprobada el 16-nov)
---
# Yala web como la app, lote 6: pantalla de entrada y código QR

Sexto y último de los lotes del plan de `docs/web-app/parecida-a-la-app/`. La entrada de la web pasa a verse como la
bienvenida de la app. Las decisiones, con su porqué, están en el Paso 0 del encargo
(`encargos/lanzados/2026-11-17-web-app-lote-6-entrar.md`).

## Qué cambia para quien usa la web

- **Entrar:** el fondo oscuro de la bienvenida de la app, con el brillo índigo detrás y el toque turquesa arriba, sin
  tarjeta blanca. El logo cuadrado índigo→rosa, «Entra a tu Yala» en grande y los tres accesos con el diseño de los de
  la app: cristal, borde fino, la manzana de Apple, la «G» de Google en color y el iPhone.
- **Entrar con tu iPhone:** el mismo fondo; el QR va en su cuadro blanco para que la cámara lo lea igual.
- **La página de la cámara** (`/v/…`), el aviso de salida, «Tu Yala vive en iCloud» y «Pronto podrás ver tus Grupos
  aquí» también.
- La entrada es **siempre oscura**, como la bienvenida de la app: con el sistema en claro, con «Claro» elegido en Ajustes
  o en oscuro se ve igual. Turnstile se pide en oscuro para que su reto se lea sobre ese fondo.
- Los textos no cambian (ni en español ni en los otros quince idiomas).

## Decisiones que no hay que deshacer

- El fondo y los botones salen del Swift de la app (`WelcomeF2Background` y `WelcomeAccessButton` en
  `WelcomeShowcaseView.swift`) y `test/lote6.test.ts` los compara con él: si la bienvenida cambia, la prueba lo dice.
- La maqueta pintaba el degradado lineal índigo→negro y el botón de Apple en blanco. La app de hoy usa el fondo F2 y
  retiró los botones blancos el 13-nov; manda la app.
- Todo el estilo de la entrada cuelga de clases `e-*`. `.brand`, `.fade` y `h1` siguen sirviendo a la app con sesión.

## Pruebas

- `webapp`: `npm run typecheck` y `npm test` (305 casos; 11 nuevos en `test/lote6.test.ts`).
- Recorrido en Chromium sin cabeza contra staging (`herramientas/recorrido-lote-6.mjs`), en escritorio y celular, con
  el sistema en claro y en oscuro: fondo de la bienvenida, Turnstile enciende los tres botones, Apple llega a
  appleid.apple.com, Google a accounts.google.com, el QR trae su código del servidor y «Volver» regresa; las direcciones
  de siempre siguen abriendo. Todo en verde.
- e2e de la web contra staging (usuarios A y B: entrar, salir, el QR aprobado desde el «iPhone» de A): 23 de 23.
- Capturas de antes y después en `docs/web-app/parecida-a-la-app/capturas/lote-6/`, hechas con
  `herramientas/capturar-lote-6.mjs` (Turnstile con la clave de prueba que siempre pide interacción, para verlo).

## Fuera de este lote

- La mascota y la vitrina de la bienvenida de la app (las tarjetas que rotan): la web entra directo a los accesos.
- «Entrar con iCloud privado»: la web solo abre cuentas con los datos en la cuenta de Yala.
