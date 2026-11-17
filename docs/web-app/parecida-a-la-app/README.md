# Yala web como la app — maqueta

Maqueta comentable del rediseño de Yala web para que se parezca a la app de iPhone (pedido de Jürgen, 16-nov-2026).
La versión publicada, con comentarios y decisiones, es el artifact https://claude.ai/artifact/AJBG7EmuTbtiq8YzGbfkWa.

- `index.html` — la fuente del artifact: inventario lado a lado, sistema visual extraído de Swift, rediseño en vivo
  (escritorio y celular, claro y Liquid Glass), siete decisiones y el plan por lotes.
- `capturas/` — web de hoy (`web-<pantalla>-<claro|oscuro>-<escritorio|movil>.jpg`) y app (`app-*.jpg`, simulador
  iPhone 17 Pro, Yala Dev con `-uitest-seed rendimiento`; claro con `-userTheme 1`).
- `herramientas/` — para repetir las capturas de la web en cada lote (antes y después) sin entrar a producción.
- `herramientas/recorrido-navegacion.mjs` — el recorrido del lote 3 en un Chromium sin cabeza (teclado, ⌘K, enlaces
  viejos, 390 px); cómo correrlo, en su cabecera.
- `herramientas/capturar-pantallas.mjs` y `recorrido-lote-4.mjs` — capturas con la hoja «Nuevo registro» y el detalle
  abiertos, y el recorrido del lote 4 (Panel, Registros y Nuevo registro); cómo correrlos, en su cabecera.
- `herramientas/capturar-lote-5.mjs` y `recorrido-lote-5.mjs` — capturas y recorrido del lote 5 (Planificación,
  Estadísticas, Grupos, Bandeja y Ajustes), con el grupo abierto y la Bandeja encima; cómo correrlos, en su cabecera.
- `herramientas/capturar-lote-6.mjs` y `recorrido-lote-6.mjs` — capturas de la entrada (con Turnstile pidiendo
  interacción, el QR y los avisos) y el recorrido del lote 6 contra un despliegue de verdad (Apple, Google, el QR y las
  direcciones de siempre); cómo correrlos, en su cabecera.
- `capturas/lote-6/` — antes y después del lote 6 (entrar, QR, QR caducado, página de la cámara, «sin nube» y aviso de
  salida) y `app-bienvenida-oscuro.jpg`, la bienvenida de la app 2.3 como referencia.
- `capturas/lote-5/` — antes y después del lote 5: `antes-|despues-<pantalla>-<claro|oscuro>-<escritorio|movil>.jpg`.
- `capturas/lote-4/` — antes y después del lote 4: `antes-|despues-<pantalla>-<claro|oscuro>-<escritorio|movil>.jpg`.
- `capturas/lote-1/` — antes y después del lote 1 (base visual): `antes-|despues-<pantalla>-<claro|oscuro>-<escritorio|movil>.jpg`,
  y `despues-<pantalla>-tema-<claro|oscuro>-…` con el tema forzado en Configurar.

## Decisiones de Jürgen (16-nov-2026)

- 15:59 · Yala web debe parecerse lo más posible a Yala móvil: diseño, colores, componentes y navegación.
- 17:21 · El hero del Panel de la app (saldo en grande con rótulo claro, «?» que explica la cifra y sin hueco antes del
  valor) es el estándar: Estadísticas, Registros y Flujo de caja de la web quedan igual de claros.
- 17:46 · Aprueba todo lo recomendado de la maqueta y encola los seis lotes: Liquid Glass por defecto con selector de
  tema, barra lateral de cristal en escritorio, pestañas de la app en celular, sin Voz, Foto ni Yala IA hasta que existan,
  íconos Lucide, cifras redondeadas con Nunito de respaldo, Planificación y Distribución en el Panel.

Cómo se aplicó cada una, lote a lote, va en el ticket del lote (`tickets/done/2026-11-16-web-app-lote-1-base-visual.md`
para el primero).

## Capturar la web con datos de ejemplo

La web no tiene modo demo: sin sesión solo enseña la entrada. Se sirve el build con un servidor que responde `/api/*`
con datos inventados.

```bash
cd webapp && npm ci && npx vite build && cd ..
SCRATCH=$(mktemp -d); cp -R webapp/dist/client "$SCRATCH/dist"
cp docs/web-app/parecida-a-la-app/herramientas/marco.html "$SCRATCH/dist/"   # iframe de 390 px para el celular
node docs/web-app/parecida-a-la-app/herramientas/servidor-maqueta.mjs "$SCRATCH/dist" 8787 &
mkdir -p "$SCRATCH/cap"
SCRATCH=$SCRATCH bash docs/web-app/parecida-a-la-app/herramientas/capturar-web.sh /registros registros oscuro movil
```

Dos trampas medidas: las fechas de los movimientos van como `AAAA-MM-DD` (con hora, Registros se cae con
`Invalid time value`), y `/api/categorias` devuelve `{ categorias: [...] }`, no una lista. El Chromium sin cabeza no
baja de ~500 px de ventana: por eso el celular se captura dentro de `marco.html`.
