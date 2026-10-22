---
id: xcode-27-1-with-the-iphone-duo-simulator
status: backlog
priority: medium
area: "tooling, iphone-duo, adaptativo"
created: 2026-09-27
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §1.1 y §3), 2026-09-27"
---

# Esta Mac no tiene el simulador del iPhone Duo: pide Xcode 27.1 (beta)

**Prerrequisito de acceso, de Jürgen.** Solo bloquea la verificación de [[iphone-duo-native-app]].

## Lo medido (2026-09-27)

- `xcodebuild -version` → Xcode 27.0 (27A266a). Runtimes: iOS 26.5 y 27.0. **Ningún tipo de dispositivo Duo** en
  `xcrun simctl list devicetypes`.
- Disco: 15 GB libres de 228 GB.

## Lo documentado

- El simulador del Duo viene con **Xcode 27.1 beta**, con controles para abrir, cerrar, girar y plegar en Device Hub
  ([Get ready for iPhone Duo](https://developer.apple.com/iphone-duo/)).
- Solo compilando con el SDK 27.1 la app llega hasta el borde de la pantalla en el Duo (tech talk
  [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)).
- Si macOS abre el Device Hub de 27.0, faltan los controles de postura: abrir el de 27.1 desde
  `Xcode > Open Developer Tool > Device Hub` ([foro](https://developer.apple.com/forums/thread/847556)).

## Qué decide Jürgen

1. Instalar Xcode 27.1 beta **al lado** del 27.0 (no en su lugar: el gate y la release siguen en 27.0), y cuándo.
2. Hacer sitio antes: con 15 GB libres no cabe con holgura. `bash qa/scripts/disk-report.sh`, y recordar que ese
   informe no ve los runtimes ni la caché dyld.
3. Compilar la release con el SDK 27.1 es otra decisión, suya y de release: no la toma este ticket.

## Hecho cuando

- `xcrun simctl list devicetypes` lista el Duo con el `DEVELOPER_DIR` de 27.1.
- Existe `YalaLane-Adapt-iPhone-Duo`, creado con `xcrun simctl create` y usado por UDID (regla de simulador del
  carril).
- Yala arranca en él cerrado y abierto, con capturas en el ticket.

## Relacionados

- [[iphone-duo-native-app]]. [[the-gate-destination-no-longer-resolves-on-this-mac]] — el otro lío de destinos de
  simulador en esta Mac.

## Reglas del carril adaptativo (obligatorias)

**Simulador** (Jürgen, 2026-09-27). Este carril usa simuladores dedicados creados con `xcrun simctl create` con
prefijo fijo `YalaLane-Adapt-` (p. ej. YalaLane-Adapt-iPhone-SE, YalaLane-Adapt-iPhone-ProMax,
YalaLane-Adapt-iPad-Pro-13, YalaLane-Adapt-iPad-mini) y los usa SIEMPRE por UDID (`-destination id=<UDID>`), nunca
por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar
simuladores sin ese prefijo (los usa la sesión de Cola A en paralelo). DerivedData propio del worktree
(`-derivedDataPath .ddp`). Receta para crearlos: `docs/exploracion/adaptativo-ipad-duo.md` §6.2.

**iPhone** (Jürgen, 2026-09-27). Se permiten mejoras de adaptación en iPhone si no rompen flujos ni ponen en riesgo
la release 2.1; cada una verificable en simulador con capturas antes/después en tamaños iPhone pequeño/grande y
Dynamic Type grande (`adaptativo-ipad-duo.md` §6.1).

**Layout** (ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo»). Se decide por size class y ancho del
contenedor, nunca por tipo de dispositivo ni orientación; un contenedor que se adapta, no un `if` por size class en
la raíz; APIs de iOS 27.1 solo tras `if #available`.
