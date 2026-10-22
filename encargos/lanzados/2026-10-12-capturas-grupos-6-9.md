# Capturas de Grupos 6,9" + propuesta de capturas App Store con App Designer Pro

Card «Capturas de Grupos 6,9" + propuesta de capturas App Store con App Designer Pro» (tablero-capturas-de-grupos-para-el-hueco-de-6-9-vohe). Effort medium. Cierre: entregar a Lola y Jürgen; sin PR salvo que toques código.

## AUTONOMÍA (léelo primero)
Jürgen está dormido. **Nunca uses AskUserQuestion y nunca esperes respuesta.** Donde la skill /app-designer-pro pide entrevista o elección, decide tú con lo que hay en el repo (ficha, web, `marketing/`, `docs/`), apunta la decisión y sigue hasta `/cerrar-total`. No subas nada a App Store Connect.

## Antes de empezar
1. Lee `~/Claude/referencias-ui/README.md` y mira las carpetas que dice útiles para Yala (kargul-2026-10-07, threads-2026-10-09-grupos). Inspiración de patrones, nunca copiar.
2. Lee `~/.claude/skills/app-designer-pro/SKILL.md` y `references/stores.md`.

## Parte A — capturas obligatorias (sin cambios respecto a lo pedido)
El PR #471 dejó capturas de Grupos 2.1 en `~/Claude/capturas-ficha/2.1/` (1206x2622 y 2064x2752) con la semilla `-uitest-seed ficha-mx`. La ficha es-MX usa el hueco de iPhone 6,9" (1320x2868).
1. Desde origin/2.1, `Yala Dev` en el simulador de 6,9" (iPhone 17 Pro Max o el que dé 1320x2868), semilla `ficha-mx`, mismas dos pantallas que #471 (lista de Grupos y detalle), modo claro, es-MX, barra de estado limpia (`xcrun simctl status_bar override`: 9:41, batería y señal llenas), sin marco, PNG.
2. Verifica 1320x2868 con `sips -g pixelWidth -g pixelHeight`.
3. Guarda en `~/Claude/capturas-ficha/2.1/`: `grupos-iphone-1320x2868.png` y `grupos-iphone-detalle-1320x2868.png`.
4. Si al pasar de un grupo a otro el detalle se queda con el primero (bug en arreglo), abre cada grupo desde cero.
Haz la Parte A primero y entera.

## Parte B — PROPUESTA de set de capturas App Store 2.1 con /app-designer-pro
Una propuesta, no la ficha final: Lola y Jürgen deciden.
1. Usa /app-designer-pro (paso de store screenshots) para rediseñar el set de capturas de la ficha 2.1: encuadre nuevo, titulares (captions) y composición. Base: capturas reales de la app 2.1 en simulador (semilla `ficha-mx` para Grupos y la semilla de vida personal en MXN que exista; no inventes pantallas que la app no tiene; los números deben ser coherentes entre capturas).
2. Explora **al menos dos direcciones creativas** distintas (p. ej. una editorial sobria y una más expresiva). Cada dirección, set completo.
3. Cada hueco en tamaño exacto: iPhone 6,9" 1320x2868 e iPad 13" 2064x2752, PNG, es-MX. Orden de huecos pensado (qué cuenta cada uno: registro rápido, Panel, Grupos 2.1, IA, privacidad/nube, etc.). Copy en español de México, sin promesas falsas: debe cuadrar con la política 2.1 (PR #469) y con lo que la app hace (más de 50 divisas, exportación gratis, Grupos en la nube, IA vía nuestro servidor). Pasa el escaneo de slop de la skill.
4. Salida en `~/Claude/propuestas/capturas-appstore-2.1/`: una carpeta por dirección (`direccion-a-<nombre>/`, `direccion-b-<nombre>/`) con `iphone-6.9/` e `ipad-13/` (`01-…png` …), el `DIRECTION.md` de la skill y la crítica puntuada.
5. `README.md` corto en esa carpeta: qué es cada dirección, comparación con el set actual (el actual está en ASC, versión 2.0.4 es-MX — léelo con la ASC CLI SOLO lectura o descárgalo — y en `~/Claude/capturas-ficha/`), pros y contras, y **una recomendación** clara. Incluye una hoja de contacto (montaje con todos los huecos) por dirección para verlo de un vistazo en el móvil.

## Qué NO tocar
App Store Connect (solo leer), textos de la ficha en ASC, la semilla `grupos` (la usan XCUITests), Vercel, datos reales, la sesión viva de iPad. Sin deploy.

## SIMULADORES iOS EN LA MINI
Nunca más de un simulador encendido a la vez; al terminar (y antes de cerrar) `xcrun simctl shutdown all`. NO usar el simulador entre 9:00 y 11:00 Lima. `nice -n 10 xcodebuild -jobs 2`, carga < 8.

## Gate tras el CI del PR anterior
Arranca cuando cierre la sesión del bug de iPad (ipad-detalle-grupo-se-queda-con-el-primero).

## PR a 2.1
Solo si tocas código (p. ej. una semilla nueva): `git fetch origin && git rebase origin/2.1` y PR a 2.1. Si no hay cambio de código, sin PR.

## Cómo se sabe
Parte A: dos PNG 1320x2868 en `~/Claude/capturas-ficha/2.1/`. Parte B: en `~/Claude/propuestas/capturas-appstore-2.1/` al menos dos direcciones completas en los dos tamaños exactos, README con comparación y recomendación, hojas de contacto. Simuladores apagados. Cierre normal con `/cerrar-total`.

## Paso 0 (auto-contestado: Jürgen dormido)

| Decisión | Tomada | Por qué |
|---|---|---|
| Simulador 6,9" | iPhone 17 Pro Max propio, iOS 27.0 (creado para la sesión) | Es el que da 1320x2868; el iPhone 18 Pro Max no consta con ese tamaño |
| Barra de búsqueda en la lista de Grupos | Se queda en la captura | Es la UI real de 2.1 en iOS 27 (`.searchable` automático, la lista no tiene recorrido para ocultarla). Las de 6,3" de #471 no la llevan |
| Semilla de vida personal en MXN | **No existía** (`realista` siembra PEN/USD). Perfil nuevo `ficha-mx-vida` | Las capturas de Panel, presupuestos y estadísticas tenían que salir en pesos y cuadrar con los grupos de `ficha-mx`. No toca la semilla `grupos` |
| Cómo pasar a MXN | Re-etiquetado al final del perfil: PEN → MXN ×5 (USD a 18.50 MXN) | Un solo fichero; el generador personal no cambia y `realista` sigue igual |
| Hueco de IA | Presentación real de Yala IA, no un chat | En simulador el chat contesta «Yala IA no está disponible» (sin App Attest); no se inventa una conversación |
| Hueco de privacidad | Tarjeta real de «Dónde viven tus datos» | La pantalla lleva una fila DEBUG de Yala Dev; se usa solo la tarjeta |
| Direcciones | A «La libreta del mes» (editorial) y B «Cada cosa, su color» (campos de color) | El encargo pide al menos dos; la skill pide que difieran en fondo, tipo, acento y riqueza |
| Entrevista de la skill | Brief auto-redactado desde ficha, web y política 2.1 (#469) | Sin AskUserQuestion por encargo |
