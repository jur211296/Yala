# Captura automática — ¿puede Jürgen dejar de grabar a mano?

**Investigación, 2026-09-15.** Hermano de `RESEARCH-demo-stack-beyond-remotion.md`.
**Solo captura** (CAPA A). Remotion sigue siendo la capa de motion. Cero vídeo generativo.

La pregunta: ¿hay algo, de preferencia gratis / open source / GitHub / CI, que **grabe la pantalla
solo** y que **saque capturas solo**, para que Jürgen no sea el cuello de botella cada semana?

Respuesta corta: **sí para el simulador, no para «inventar el gesto».** La máquina puede repetir
una toma que alguien escribió una vez. Nadie tiene un producto que decida *qué* tocar.

---

## 1 · Recomendación para Yala

**Empieza por lo que ya está en el repo, gratis, en un Mac con Xcode.**

1. **Capturas (ya casi resuelto).** Un script o un XCUITest que lance `Yala Dev` con
   `-uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed realista` (el mismo cableado
   de `YalaUITests/Support/XCUIApplication+Yala.swift`) y dispare
   `xcrun simctl io booted screenshot`. Eso es nativo, PNG a resolución del simulador, **sin
   píldora roja**. Encaja con el plan de XcodeBuildMCP semanal — **pero no uses la tool
   `screenshot` de XcodeBuildMCP para marketing**: el código actual reescala a JPEG de **800 px**
   (`sips -Z 800`). Sirve para que un agente *vea* la UI; no para Remotion ni para la ficha.
2. **Vídeo (el hueco real).** No hace falta Screen Studio ni ReplayKit. En el simulador:
   `xcrun simctl io booted recordVideo --codec=h264 --force …mp4`. Sin píldora, sin QuickTime,
   sin iPhone enchufado. El gesto lo conduce un XCUITest (o un flow de Maestro). Xcode 26 ya
   **guarda el vídeo de un UI test aunque pase** si en el test plan pones «On, and keep all»
   — Apple lo dice en WWDC25 como uso para *documentation, tutorials or marketing*.
3. **CI como segundo paso, no el primero.** `macos-26` en GitHub Actions trae Xcode 26.x y
   iPhone 17 Pro. Un cron semanal puede dejar mp4/png en artefactos y copiarlos a
   `marketing/remotion/public/footage/` y `public/stills/`. **Sigue haciendo falta un Mac**
   (el runner *es* un Mac). Linux / cloud genérico no corre el Simulator.

**Lo que sigue pidiendo a un humano, una vez:** escribir el guion del gesto (el XCUITest o el
YAML). Revisar los chips de Yala IA (se generan con categorías reales — ya está en
`OPERACION.md`). Decidir si el Liquid Glass del Simulator vale o hay que repetir en dispositivo.
El visto bueno de Jürgen antes de publicar.

**Lo que no existe:** una herramienta que grabe «la demo de pizza» sin que nadie le haya dicho
qué tocar. Appium, Detox, idb, tidevice, Maestro Cloud — ninguno inventa el plano.

---

## 2 · Vídeo: quién graba solo

| Herramienta | Sim | iPhone físico | Headless / CI | Coste | Encaje Yala |
|---|---|---|---|---|---|
| **`xcrun simctl io recordVideo`** | Sí. `--codec=h264` (default es HEVC; Remotion y App Store prefieren H.264) | **No** | Sí, en un Mac. `kill -INT`, no `-9` | 0 $ | **Primera opción.** Es lo que XcodeBuildMCP envuelve |
| **XcodeBuildMCP `record-video`** | Sí (`record_sim_video`, AXe ≥ 1.1.0) | **No** (docs: *exclusively on iOS simulators*) | Sí, CLI + MCP | 0 $ (OSS) | Útil si Frank ya lo tiene abierto. Misma CAPA A |
| **XCUITest + test plan «keep all videos»** | Sí | El vídeo de Xcode en **device** es otra historia (más frágil) | Sí, `xcodebuild test` en Actions | 0 $ | **Mejor forma de «el gesto se escribe una vez».** El test *es* el guion |
| **Maestro `record --local`** | Sí | Limitado / depende de WDA | Sí en Mac; Cloud es de pago y **sube el raw a sus servers** si no usas `--local` | OSS local; Cloud de pago | YAML más corto que XCUITest. **Cuidado:** el MP4 *cosé* la pantalla con el output del flow — para un Reel de producto suele sobrar |
| **idb (`facebook/idb`)** | Sí | Captura USB sí; **UI en físico, no** (restricción de iOS) | Companion solo en Mac arm64 + Xcode 26 | 0 $ | Más peso que `simctl` para el mismo resultado en sim |
| **pymobiledevice3 / tidevice** | No es su fuerte | Screenshot y *screenrecord* USB, sin app en el teléfono | Linux/Windows para *algunas* cosas; iOS 17+ es un túnel | 0 $ | Plan B de **dispositivo** si no quieres QuickTime. **No automatiza toques** |
| **Appium + XCUITest driver** | Sí | Sí (WDA en el device) | Sí, si hay un Mac o un provider | OSS + infra | Curva alta. No aporta nada que XCUITest + `simctl` no dé |
| **Detox** | Sí (RN) | Parcial | CI | OSS | **No aplica.** Yala no es React Native |
| **ReplayKit / grabadora del iPhone** | — | Sí | — | 0 $ | **Prohibido para marketing.** Es la píldora roja de 16 s del piloto |
| **QuickTime USB / Screen Studio / Rotato** | — | Sí, sin píldora | No | 0 $ / de pago | Sigue siendo **manual**. No quita a Jürgen del bucle |
| **GitHub Actions `macos-26`** | Sí (iPhone 17 Pro está en la imagen) | **No** (no hay USB) | Sí | Minutos de Mac de Actions (caro frente a Linux) | El sitio para el cron semanal **después** de que el script corra en local |
| **MacStadium / Mac mini propio** | Sí | Sí, si enchufas un iPhone | Sí | De pago / hardware | Solo si el cron de Actions se queda corto o hace falta device |

### El comando que ya vale

```bash
# Status bar de ficha (9:41, batería llena). Solo Simulator.
xcrun simctl status_bar booted override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

# Vídeo H.264. Ctrl+C o kill -INT para parar.
xcrun simctl io booted recordVideo --codec=h264 --force \
  marketing/remotion/public/footage/ia-gasto-pizza.mp4
```

Default de `recordVideo` es **HEVC**. Apple rechaza HEVC en app preview; Remotion se come H.264
sin drama. No te fíes del default.

---

## 3 · Capturas: quién las saca solo

| Herramienta | Qué da | Trampa |
|---|---|---|
| **`xcrun simctl io booted screenshot file.png`** | PNG nativo del framebuffer | **Úsala.** Resolución de verdad |
| **`XCUIScreen.main.screenshot()`** + `XCTAttachment` | PNG del screen o de un elemento | Oficial. Fastlane snapshot es esto con wrapping |
| **XcodeBuildMCP `screenshot`** | Path o base64 | **Reescala a 800 px JPEG.** No es captura de marketing |
| **fastlane `snapshot`** | Lote App Store, idiomas, devices | Vive; en 2026 se rompió con iOS 26.x de tres dígitos (`OS=26.4` vs `26.4.1`). Arreglado en **fastlane 2.236.0** (destinos por UDID). Si se usa, **pinnear esa versión o superior** |
| **Maestro `takeScreenshot`** | PNG del flow | Bien para un lote semanal si el flow ya existe |
| **idb / tidevice / pymobiledevice3** | PNG del device USB | Para físico. No sustituye al Simulator para el lote semanal |

Yala **no tiene** hoy un target `AppStoreScreenshots`. Tiene XCUITests de producto y seeds.
Montar `fastlane snapshot` es un proyecto; un XCUITest de 20 líneas que llame a
`screenshot()` y copie el PNG a `marketing/remotion/public/stills/` es una tarde.

---

## 4 · Límites honestos (los que tumbarían un cron)

**Siempre hace falta un Mac.** El Simulator no corre en Linux. «Headless» aquí significa
`simctl` sin Simulator.app abierto, no «un contenedor en la nube barata».

**Firma.** En Simulator, `Yala Dev` se firma con el team local y listo. En device o en un runner
ajeno: certificados, profiles, a veces un Apple ID. El cron de Actions del repo **no** firma hoy
para device.

**iOS 26 / Liquid Glass.** Target del proyecto. El Simulator de iPhone 17 Pro en `macos-26` lo
tiene. **No está medido** si el look 2.1 (glass oscuro) es idéntico al del iPhone físico. Si
diverge, el lote semanal del sim es bueno para *iterar copy* y malo para *publicar*. Eso se
comprueba con una pareja sim/device de la misma pantalla, una vez.

**Píldora roja.** Solo aparece si grabas **desde el propio iPhone** (ReplayKit / grabadora).
`simctl`, QuickTime USB y CoreMediaIO **no la pintan**. El `crop: { top: 0.05 }` del piloto
existe porque se grabó mal, no porque el stack lo exija.

**Seeds y chips de IA.** `-uitest-seed realista` (y `grupos`, `minimal`, …) ya resuelven datos
de ejemplo. El riesgo que queda es el de `OPERACION.md`: **los chips de Yala IA se generan con
las categorías de quien graba**. Un cron que lance el seed y no lea los chips puede publicar
nombres reales. El script tiene que **assertar el texto de los chips** o el job no sube el mp4.

**Contención de simuladores.** Ya picó en tickets (`3 sims homónimos "iPhone 17 Pro"`). El job
tiene que apuntar por **UDID**, no por nombre.

**Runtime que se mueve.** GitHub ha cambiado iOS 26.0 → 26.0.1 en el runner y ha roto destinos.
Pinnear `runs-on: macos-26` **y** el `OS=` exacto (`xcrun simctl list devices available`).

**Maestro Cloud / remote `record`.** Sube el raw a servers de mobile.dev (URL 60 min, borrado
24 h). Para Yala, **`--local` o nada**.

---

## 5 · Cómo entra en Remotion

Remotion no cambia. El contrato sigue siendo el de `OPERACION.md`:

```
toma.mp4  →  marketing/remotion/public/footage/<slug>.mp4
still.png →  marketing/remotion/public/stills/<slug>.png   # ya hay .gitkeep
```

Después: `ffprobe` (ancho, alto, duración → literales en `copy.ts`), Studio, `bun run render:reels`.

Un cron razonable, cuando el XCUITest exista:

1. Boot iPhone 17 Pro, `status_bar override` 9:41.
2. Launch `Yala Dev` con los `-uitest-*` de siempre.
3. `recordVideo --codec=h264` **o** el vídeo del test plan.
4. `screenshot` nativo en los beats quietos (para stills / App Store generator).
5. Copiar a `public/footage` y `public/stills`. El render lo dispara quien ya lo dispara
   (local, no hace falta Lambda).
6. **No commitear los mp4** (`out/` y el footage pesado ya están fuera de git salvo el piloto).

Screen Studio, si se prueba, entra **después** de este archivo: encuadre, no captura.

---

## 6 · Qué probar primero (barato) y qué no comprar

| Orden | Qué | Coste | Para qué |
|---|---|---|---|
| 1 | Un XCUITest `DemoIAPizza` + `simctl recordVideo` + `simctl screenshot` en el Mac de Frank | 0 $ | Demuestra que Jürgen no tiene que tocar el iPhone |
| 2 | Workflow `macos-26` semanal que suba artefactos (no merge automático) | Minutos de Mac de Actions | Quita el «acordarse el lunes» |
| 3 | Si el sim no se parece al device: **una** toma USB (QuickTime o pymobiledevice3) por release | 0 $ | CAPA A de publicación |
| — | Screen Studio | 29 $/mes de prueba | Encuadre, no captura. Ver el otro brief |
| — | Maestro Cloud, BrowserStack, MacStadium | De pago | No hasta que 1 y 2 se queden cortos |
| — | Appium / Detox / idb como sistema | Tiempo | Duplican XCUITest + `simctl` |

---

## 7 · Fuentes

Consultadas el **2026-09-15**.

- `simctl` screenshot / recordVideo — `xcrun simctl io help` (flags `h264`/`hevc`, `internal`/`external`, `--force`). Guía de 2026: https://www.screenify.studio/blog/2026-08-13-simctl-recordvideo-ios-simulator
- Status bar 9:41 — `xcrun simctl status_bar` (desde Xcode 11)
- XCUIScreenshot — https://developer.apple.com/documentation/xcuiautomation/xcuiscreenshot
- Vídeos de UI tests para marketing — WWDC25 «Record, replay, and review»: https://developer.apple.com/videos/play/wwdc2025/344/
- XcodeBuildMCP (OSS) — https://github.com/cameroncooke/xcodebuildmcp · tools: https://xcodebuildmcp.com/docs/tools · `record_sim_video` / `screenshot` (este último, JPEG 800 px: ver `screenshot.ts` en el repo)
- Maestro record / takeScreenshot — https://docs.maestro.dev/maestro-flows/workspace-management/record-your-flow · https://docs.maestro.dev/reference/commands-available/takescreenshot · CLI: https://docs.maestro.dev/maestro-cli/maestro-cli-commands-and-options
- idb — https://github.com/facebook/idb · install: https://fbidb.io/docs/idb/installation/ (Mac arm64, macOS 15+, Xcode 26)
- pymobiledevice3 — https://github.com/doronz88/pymobiledevice3 · captura USB tipo QuickTime (Valeria/CMIO)
- tidevice — https://github.com/alibaba/tidevice
- fastlane snapshot + iOS 26 — https://github.com/fastlane/fastlane/issues/30040 · fix en 2.236.0: https://github.com/fastlane/fastlane/releases/tag/2.236.0
- GitHub Actions macos-26 + sims iPhone 17 Pro — https://github.com/actions/runner-images/blob/releases/macos-26/20260824/images/macos/macos-26-Readme.md · `macos-latest` → 26: https://github.com/actions/runner-images/issues/14167 · destinos que se rompen al cambiar el patch: https://github.com/actions/runner-images/issues/13220
- Cableado de seeds en este repo — `YalaUITests/Support/XCUIApplication+Yala.swift`
- Contrato de footage — `marketing/remotion/docs/OPERACION.md`

**No verificado aquí:** si Liquid Glass del Simulator 26.x es publicable frente al iPhone 17 Pro
físico; el precio exacto por minuto de `macos-26` en Actions (cambia; mirar la calculadora de
GitHub antes de poner un cron diario); que `maestro record --local` saque un MP4 *sin* el overlay
del flow (la doc dice que «stitches the app screen and Flow output»).
