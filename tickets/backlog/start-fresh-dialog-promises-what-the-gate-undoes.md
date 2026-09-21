---
id: start-fresh-dialog-promises-what-the-gate-undoes
status: backlog
priority: medium
area: "welcome, icloud, restore, copy"
created: 2026-09-20
updated: 2026-09-20
source: "review adversarial (lentes de concurrencia y de tests/copy) de `restore-says-no-data-when-the-icloud-import-never-settled`, 2026-09-20"
---

# «Esto creará una cuenta nueva sin tus datos previos» — ni crea una cuenta, ni es cierto en dos estados

## El problema, en lenguaje de usuario

Toco «Empezar desde cero», la app me pregunta «¿Empezar desde cero? Esto creará una cuenta nueva
sin tus datos previos. ¿Continuar?», digo que sí… y lo que aparece no es una cuenta nueva: es otra
pantalla que vuelve a preguntarme, esta vez con las cifras de lo que hay en iCloud.

## Medido (2026-09-20)

- El copy: `welcome.restore.startFreshConfirm.body` = «Esto creará una cuenta nueva sin tus datos
  previos. ¿Continuar?» (`es-419.lproj/Localizable.strings:4104`).
- Lo que hace el botón: `WelcomeRestoreView` → `onStartFresh()` → `ContentView.swift:863` →
  `returnToWelcomeChooser(dismissing:step: .privateICloudGate)`. **Abre la puerta que vuelve a
  preguntar**; ni crea ni borra nada en ese momento. El propio `ContentView` documenta que «sin tus
  datos previos» era el bug de 2026-09-14 y que por eso el callback se redirigió a la puerta — el
  copy del diálogo se quedó como estaba.
- Y desde el 2026-09-20 ese diálogo lo ven **cinco** estados en vez de tres, así que la frase es
  falsa en dos sitios más:
  - `.importIncomplete`: hay un import de CloudKit **escribiendo en ese mismo store** mientras se
    lee el diálogo. La «cuenta nueva» nacerá con el histórico dentro. Lo dice el comentario del
    propio `importIncompleteView`: «abre un dataset paralelo que convivirá con él».
  - `.iCloudDisabled`: afirma un hecho que ese estado explícitamente no conoce — su puerta lee
    `ubiquityIdentityToken`, que mide iCloud **Drive** y no CloudKit.

## Criterios de aceptación

- [ ] El diálogo dice lo que va a pasar de verdad al confirmar (lo siguiente es una comprobación,
      no un alta), y no afirma un borrado que todavía no ocurre.
- [ ] La frase aguanta los cinco estados que lo presentan, o cada uno lleva la suya.
- [ ] Copy revisado contra `docs/planning/BRAND-VOICE.md` §7 y propagado a los 16 locales.

## Relación con otros tickets

- `restore-says-no-data-when-the-icloud-import-never-settled` — de donde sale; extendió el diálogo
  a `.importIncomplete`, `.iCloudDisabled` y `.notFound`.
- `restore-start-fresh-keeps-the-imported-corpus` — el ticket que movió el callback a la puerta.
