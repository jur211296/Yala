# Probar Frames CLI 1.5.0 y documentar en marketing si funciona

## Contexto
Federico Viticci publicó Frames CLI 1.5.0 (2026-09-30): marcos oficiales Apple, iPhone 18 Pro default Pro, colores Burgundy/Glacier/Silver/Black, Duo experimental, batch, scaling proporcional, screen recordings. Skill para agentes. Free/OSS.
Pipeline pensado para demos Yala: simctl/XCUITest captura → Frames CLI bezel → Remotion anima. Esta sesión NO monta Remotion ni XCUITest completo: solo instalar/probar Frames CLI y dejar rastro en el repo marketing si vale.
Ref: https://www.macstories.net/notes/frames-cli-1-5-0-now-with-iphone-18-pro-and-experimental-iphone-duo-support/

## Que se pide
1. Instalar o actualizar Frames CLI a 1.5.0 (método oficial del repo de Viticci / docs que encuentres).
2. Probar con al menos: (a) una screenshot de app iPhone (puede ser existente en el repo o una captura del Simulator si hay una a mano; no hace falta XCUITest nuevo), (b) si es rápido, un screen recording corto — si no hay recording, solo documenta que no se probó video.
3. Verificar que el bezel iPhone 18 Pro sale bien (o el default Pro del CLI).
4. Si funciona: documentar en el repo marketing (md corto en docs/ o según convenciones del repo; sin research largos en la raíz si CLAUDE.md lo prohíbe). Incluir: cómo instalar, comando ejemplo, resultado, límites (Duo experimental irrelevante para Yala ahora), y que Remotion sigue siendo la capa de animación.
5. Abrir PR con el doc + cualquier script mínimo útil (opcional). No mergees.

## Que NO hay que tocar
- No tocar app Yala (fuera de marketing/).
- No lanzar Remotion ni ElevenLabs.
- No instalar VoiceStudio ni Screen Studio.
- No deploy prod.
- No pedir permisos interactivos: ya vas en bypassPermissions.
- Duo: no hace falta probarlo a fondo.

## Como se sabe que esta bien
Frames CLI corre en la Mini; hay al menos una imagen framed de salida; hay documento en marketing/ en PR describiendo install + uso + veredicto para demos Yala.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Instalación:** opción A del README (clon), en `~/.local/share/frames-cli` + symlink en `~/.local/bin` (ya en el PATH). El pack de marcos en `~/.local/share/frames-assets`, bajado con curl porque `frames setup` sin ruta exige tty.
2. **Captura de prueba:** las crudas del generador (`generator/public/screenshots/es/*.png`, 1206×2622, datos de ejemplo). No se lanza Yala en el simulador: evita cualquier duda de datos y no hace falta para probar el marco.
3. **Vídeo:** sí, grabación corta del simulador sobre Ajustes de iOS (sin datos de nadie), H.264 y `hevc-alpha`.
4. **Dónde va el doc:** `marketing/docs/frames-cli.md` (carpeta nueva; el encargo pide docs/) + una línea en `marketing/README.md`. Muestra: un JPG reducido en `docs/img/`.
5. **No se commitea:** el pack de marcos (Apple Design Resources License prohíbe redistribuirlo) ni las salidas completas.
6. **Script:** ninguno. El CLI ya es un comando; un wrapper no aporta.
7. **Remotion:** no se toca. Sustituir el `DeviceFrame` dibujado por un vídeo encuadrado queda como decisión abierta de Jürgen.
8. **Entrega:** PR contra `2.1`, sin mergear (el encargo lo dice; no es MODO AUTÓNOMO de auto-merge).
