# Yala web como la app — maqueta

Maqueta comentable del rediseño de Yala web para que se parezca a la app de iPhone (pedido de Jürgen, 16-nov-2026).
La versión publicada, con comentarios y decisiones, es el artifact https://claude.ai/artifact/AJBG7EmuTbtiq8YzGbfkWa.

- `index.html` — la fuente del artifact: inventario lado a lado, sistema visual extraído de Swift, rediseño en vivo
  (escritorio y celular, claro y Liquid Glass), siete decisiones y el plan por lotes.
- `capturas/` — web de hoy (`web-<pantalla>-<claro|oscuro>-<escritorio|movil>.jpg`) y app (`app-*.jpg`, simulador
  iPhone 17 Pro, Yala Dev con `-uitest-seed rendimiento`; claro con `-userTheme 1`).
- `herramientas/` — para repetir las capturas de la web en cada lote (antes y después) sin entrar a producción.

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
