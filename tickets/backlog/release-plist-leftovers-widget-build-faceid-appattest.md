---
id: release-plist-leftovers-widget-build-faceid-appattest
status: backlog
priority: medium
area: "release"
created: 2026-10-10
source: "Checklist de envío de 2.1 (docs/RELEASE-CHECKLIST-2.1.md §5), medido sobre origin/2.1 6937828ff"
---

# Restos en los plist de release: build del widget fijo, texto de Face ID y App Attest sin declarar

1. **El widget fija su build a `3`** (`YalaWidgets/Info.plist:23-24`, desde `0d68a5d0d`, mayo). La app va en
   15 (`CURRENT_PROJECT_VERSION = 15` en `Yala.xcodeproj/project.pbxproj`). App Store Connect avisa de que la
   extensión y la app no coinciden. Arreglo: `$(CURRENT_PROJECT_VERSION)`.
2. **Sobra `NSFaceIDUsageDescription`** (`Yala/Resources/Info.plist:23-32` y los 16 `InfoPlist.strings`). El
   bloqueo con Face ID se quitó: no hay `LocalAuthentication` en el código y `AppBootstrapper.swift:2688-2701`
   limpia sus restos.
3. **App Attest no declara su entitlement** en `Yala/App/Yala-Release.entitlements`. En distribución atesta
   en producción igualmente; declararlo `production` quita la ambigüedad.

Ninguno bloquea el envío. El primero es el único que conviene antes del archive.

## Hecho cuando

El archive de 2.1 sale con el mismo build en la app y el widget, sin el texto de Face ID y con App Attest declarado.
