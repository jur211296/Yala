---
id: ci-runner-se-queda-sin-simuladores-y-tumba-build-for-testing
status: qa
priority: medium
area: ci
created: 2026-09-09
updated: 2026-10-02
source: aparecido al pasar el PR #116 (build 13 a TestFlight) por el CI
---

# El runner del CI se queda sin simuladores y tumba `Build for testing` — y el rojo NO es advisory

## Qué pasa

En el job `tests` de `.github/workflows/qa.yml`, el paso **`Build for testing`** falla con:

```
xcodebuild: error: Unable to find a device matching the provided destination specifier:
		{ platform:iOS Simulator, OS:latest, name:iPhone 17 Pro }
	The requested device could not be found because no available devices matched the request.
	Available destinations for the "Yala Dev" scheme:
		{ platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
```

El runner `macos-26` arranca **sin ningún runtime de simulador**: el único destino disponible es el
placeholder «Any iOS Device». No es un fallo de código.

## Por qué importa, y no es cosmético

**Este rojo se disfraza del rojo advisory conocido.** Los tres pasos de test del workflow llevan
`advisory` en el nombre, y la costumbre —escrita en la propia memoria del repo— es no perseguirlos.
Pero el que falla aquí es `Build for testing`, que **no** es advisory: cuando cae, los tres pasos
advisory quedan en *skipped* y **la suite no llega a correr**. El propio CI lo anota:

> `Nadie se ha enterado de que la suite NO llego a correr.`

⇒ Un `tests: fail` producido por esta causa significa **«no se probó nada»**, no «hay tests rotos».
Leerlo como advisory es dar por cubierto un PR que nadie verificó. Se agrava con
`ci-avisador-de-rojos-advisory-tiene-la-clave-mal` (**high**): el avisador tampoco puede cantarlo.

## Que es intermitente, medido

El mismo sha `9f35afaa` de `2.1` produjo **dos veredictos opuestos** el 2026-09-09:

| corrida | sha | resultado |
|---|---|---|
| 11:41:27Z | `9f35afaa` | success |
| 12:57:50Z | `9f35afaa` | failure |

Un mismo código no puede romper y no romper: la causa está en el entorno del runner, no en el árbol.
Es la muestra imposible que zanja el diagnóstico sin bisecar.

**Y no rompe la compilación de los targets de test**: en el PR #116, con el mismo commit que el CI
declaró rojo, `xcodebuild build-for-testing -scheme "Yala Dev"` dio localmente
`** TEST BUILD SUCCEEDED **` (exit 0), produciendo `YalaTests.xctest` y `YalaUITests.xctest`.

## Qué habría que hacer

Alguna de estas, a decidir:

1. **Fijar el runtime en el runner** en vez de confiar en la imagen: instalar/seleccionar el
   simulador explícitamente antes del build (`xcodebuild -downloadPlatform iOS`, o fijar
   `xcode-version` a una versión concreta en lugar de `latest-stable`).
2. **Aflojar el destino**: `-destination 'generic/platform=iOS Simulator'` para `build-for-testing`
   no necesita un device concreto, y sólo los pasos que *ejecutan* tests lo necesitan.
3. **Que el paso falle ruidosamente y distinto**: hoy su rojo es indistinguible del advisory. Como
   mínimo, que el job distinga «la suite no arrancó» de «la suite corrió y falló».

La 2 es la más barata y ataca la causa directa; la 1 es la robusta.

## Cómo se sabe que está bien

Dos corridas seguidas del workflow en las que `Build for testing` pase, y una corrida forzada sin
runtime disponible en la que el job diga explícitamente que la suite no llegó a correr.

## Resolución (2026-10-02, PR #327)

Duplicado de `ci-destination-assumes-a-simulator-that-may-not-exist`, que lleva la resolución y lo que
falta para cerrarlo. De las opciones de aquí: se hizo la 1 en versión robusta (resolver/crear el device
y, si no hay runtime, `xcodebuild -downloadPlatform iOS`) y la 3 (`::error title=Simulador::` en vez del
exit 70). La 2 (`generic/platform`) se descartó; el porqué está en el otro ticket.
