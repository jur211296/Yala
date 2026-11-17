---
id: 2026-11-16-web-app-lote-3-navegacion
status: done
priority: high
area: web
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-web-app-lote-3-navegacion (maqueta «Yala web como la app», aprobada el 16-nov)
---
# Yala web como la app, lote 3: navegación de cristal en escritorio y celular

Tercero de los seis lotes del plan de `docs/web-app/parecida-a-la-app/`. La web se movía con una barra lateral de nueve
entradas y, en el celular, una barra fija con «+» en el medio. Ahora se mueve como la app.

## Qué cambia para quien usa la web

- **Escritorio:** barra lateral de cristal flotante, como la app en iPad: el campo «Buscar» con su atajo (⌘K en Apple,
  Ctrl K en el resto), Panel, Registros, Estadísticas, Planificación y Grupos; debajo, Bandeja con su contador y Yala IA
  con «Pronto»; al pie, el avatar con tu nombre, que abre Configurar. En la cabecera, el ojo y «+ Nuevo registro».
- **Celular:** la barra flotante de la app (Panel, Registros, Grupos y Más) con la lupa aparte; la Bandeja en su botón
  redondo arriba a la izquierda, con el contador; el avatar arriba a la derecha; «+ Nuevo registro» como cápsula al
  principio del Panel y de Registros. «Más» enseña tarjetas con ícono de color: Bandeja, Estadísticas, Presupuestos,
  Pagos planificados, Configurar y Yala IA.
- **Planificación** reúne Presupuestos y Pagos planificados en dos segmentos, como la pestaña de la app.
- Al cerrar la búsqueda con Esc o ⌘K, el foco vuelve a donde estaba.

## Direcciones

- `/planificacion` abre Planificación en Presupuestos; `/presupuestos` y `/pagos` siguen valiendo y abren su segmento.
  Tocar un segmento cambia la dirección a la suya, así que recargar y «Atrás» respetan el segmento.
- No hizo falta tocar `wrangler.toml`: el Worker ya devuelve la página para cualquier dirección que no sea `/api` ni
  `/auth`. Lo fija `test/navegacion.test.ts`.
- Qué abre cada dirección y qué se marca vive en `webapp/src/client/app/navegacion.ts`, puro y probado sin navegador.

## Decisiones que un lote siguiente no debe deshacer

- «Configurar» conserva su nombre: el avatar lleva ahí. El cambio a «Ajustes» va con el lote 5, que toca Configurar y los
  14 idiomas.
- La clave de texto nueva es `app.nuevoRegistro`, con la traducción de la app (`transaction.new`). `app.apuntar` queda
  sin uso en la navegación; la hoja «Apuntar» la rehace el lote 4.
- Las tarjetas de «Más» no llevan la línea de descripción de la maqueta (serían textos nuevos en 14 idiomas).

## Fuera de este lote

- La hoja «Nuevo registro» centrada en el monto: lote 4.
- Bandeja como panel lateral en escritorio y Ajustes a 700 px: lote 5.

## Pruebas

- `webapp`: `npm run typecheck` y `npm test` (248 casos), con `test/navegacion.test.ts` (direcciones viejas y nuevas,
  segmentos, pestaña marcada, atajo, página para `/planificacion` en staging y producción) y un caso nuevo en
  `test/movil.test.ts` (en el celular la barra lateral se oculta y la barra flotante respeta la zona segura).
- Recorrido en Chromium sin cabeza, `docs/web-app/parecida-a-la-app/herramientas/recorrido-navegacion.mjs`: 42
  comprobaciones en verde contra el servidor de maqueta (Tab por la barra lateral en orden, Intro abre, ⌘K y Ctrl K
  abren con el foco en el campo y Esc lo devuelve, la búsqueda lleva a Planificación, enlaces viejos, Atrás, avatar,
  Bandeja, y las diez secciones a 390 px sin scroll lateral).
- Capturas de antes y después en `docs/web-app/parecida-a-la-app/capturas/lote-3/` (claro y oscuro, escritorio y
  celular).
