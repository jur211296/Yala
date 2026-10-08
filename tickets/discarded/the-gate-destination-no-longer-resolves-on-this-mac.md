---
id: the-gate-destination-no-longer-resolves-on-this-mac
status: discarded
priority: high
area: "qa, entorno"
created: 2026-09-22
updated: 2026-10-07
source: "medido al correr el gate de `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22)"
---

# El destino que usan el gate y `/verify-ios` no resuelve en esta Mac desde que se actualizó Xcode

Why: Discarded 2026-10-07, con OK de Jürgen (2026-10-07, 21:50 Lima). El destino del gate vuelve a resolver desde el 2026-09-30 (lo dice la cabecera de este ticket). Medido otra vez el 2026-10-07: hay un solo `iPhone 17 Pro` disponible, en iOS 27.0 (`46287CFE`), así que `name=iPhone 17 Pro` casa sin ambigüedad.

> **La premisa ha cambiado (medido el 2026-09-30, sesión del #306).** `name=iPhone 17 Pro` vuelve a
> casar con el `9EDA6AAF` de iOS 27.0, así que el destino del gate resuelve. Antes de trabajar
> este ticket, vuelve a medirlo: puede que ya no haya nada que arreglar. (Venía de la cabecera de
> `docs/ESTADO.md`, retirado ese mismo día.)

## El problema

`.claude/commands/gate.md` y `.claude/commands/verify-ios.md` lanzan todo con:

```
-destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Sin `OS=`, eso significa `OS:latest`. Con Xcode 27.0 instalado, «latest» es **iOS 27.0**, y en esta Mac
**no existe ningún device de iOS 27.0** — el runtime sí está instalado, pero no hay device creado con él.

Medido el 2026-09-22:

```
$ xcrun simctl list runtimes | grep -i ios
iOS 26.5 (26.5 - 23F77)  - com.apple.CoreSimulator.SimRuntime.iOS-26-5
iOS 27.0 (27.0 - 24A434) - com.apple.CoreSimulator.SimRuntime.iOS-27-0     ← instalado, SIN devices

$ xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild: error: Unable to find a device matching the provided destination specifier:
		{ platform:iOS Simulator, OS:latest, name:iPhone 17 Pro }
```

El único `iPhone 17 Pro` del parque es `9D0F6D32-1F49-46AD-8070-603D42B5220F`, en **26.5**.

**Por qué importa más de lo que parece:** ese fallo sale con **exit 70 y CERO tests ejecutados**. Es
exactamente el modo de fallo que `.claude/rules/testing.md:145` describe y que `/gate` existe para no
cometer — una corrida que no prueba nada. Hoy no hay ninguna sesión de este Mac que pueda correr el gate tal
como está escrito.

## Lo que sí funciona, medido

Compilando contra el SDK 27.0 (`SDKROOT = …/iPhoneSimulator27.0.sdk`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`) y
corriendo en el device de **26.5** por su `id=`, todo pasa: build ×2, 913 unit tests en 63 suites, y el
XCUITest del área. O sea que la premisa de `testing.md:145` («el device DEBE casar con el runtime del SDK»)
**no es cierta en este caso**: el deployment target es 26.0 y 26.5 lo cumple.

## Qué habría que decidir

1. **¿Crear un device de iOS 27.0, o fijar el destino por `id=`/`OS=`?** Crear el device hace que `name=` vuelva
   a resolver, pero deja **dos** `iPhone 17 Pro` en el parque y `name=` pasa a ser ambiguo — que es el otro
   problema que `testing.md:145` ya describe.
2. Si se fija por `OS=26.5`, hay que decidir quién lo mueve cuando llegue el runtime siguiente.
3. **La frase de `testing.md:145` hay que corregirla en cualquier caso**: dice que el device debe casar con el
   runtime del SDK, y lo medido hoy es que basta con cumplir el deployment target.

No se toca en el ticket que lo encontró porque cambiar el destino del gate afecta a las ~14 sesiones que
comparten este Mac, y eso es una decisión de Jürgen, no un daño colateral.

## Criterios de aceptación

- [ ] `bash` con el comando literal de `gate.md` ejecuta tests (no exit 70 con cero casos).
- [ ] `testing.md` dice lo que se mide hoy, no lo que se midió con el Xcode anterior.
- [ ] Si quedan dos devices con el mismo nombre, el comando documentado no es ambiguo.
