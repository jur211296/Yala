---
id: groups-stuck-drain-on-a-healthy-phone-says-try-again-later
status: backlog
priority: low
area: "grupos, sync, copy"
created: 2026-10-05
updated: 2026-10-05
source: "review adversarial de `groups-drain-that-always-aborts-takes-the-loss-exit-away` (2026-10-05, lente 3)"
---

# Con el drain de Grupos atascado en un teléfono sano, cerrar sesión dice «inténtalo en un rato» y esperar no lo cura

## El problema, en lenguaje de usuario

Muy raro. Si este teléfono no consigue preparar para subir un cambio de tus grupos —siempre, no una vez— y todo lo demás va
bien (tiene App Attest, tu sesión vale y el cambio es tuyo), cerrar sesión, desasociar o «Empezar de cero» te dicen «Los
últimos cambios de tus grupos no llegaron al servidor… inténtalo de nuevo en un rato». No se pierde nada y no hay salida que
lo pierda (decisión A de Jürgen), pero el texto promete que esperar ayuda, y no ayuda.

## Por qué pasa (medido el 2026-10-05)

- `CloudSignOutFlowLogic.stuckCaptureVerdict` devuelve `.uploadRetryLater` cuando la captura está atascada, el ciclo fue
  bien y algo de lo que queda fuera es de esta sesión. Es el texto de una subida que falló, no el de un cambio que este
  teléfono no consigue preparar.
- El gemelo personal tiene su motivo y su texto (`.personalCaptureUnfinished`, `settings.signOutCaptureUnfinished`: «no se
  pudieron preparar; no se pierden; cierra y abre Yala o actualízala»). Grupos no.
- Pariente: en el desasociar, con el drain atascado y la sesión caducada, el aviso dice «tu sesión caducó» (verdad, pero volver
  a entrar no cura el drain; tras entrar saldría este mismo texto).

## Propuestas (decide Jürgen)

- **A (recomendada).** Motivo propio `.groupsCaptureUnfinished` con el texto del personal dicho de tus grupos: «Algunos de
  los últimos cambios de tus grupos no se pudieron preparar para subirlos. Siguen guardados en este teléfono y no se pierden.
  Cierra y vuelve a abrir Yala; si sigue pasando, actualízala.» 16 locales, sin salida. Es lo honesto y es el molde ya decidido.
- **B.** Reusar el texto personal (`settings.signOutCaptureUnfinished`) tal cual en Grupos. Cero copy nuevo, pero habla de «tus
  cambios» sin decir que son de grupos.
- **C.** Dejarlo como está. Es tan raro que no compensa; el texto no promete segundos, solo «un rato».

## Criterios de aceptación

- [ ] Con el drain de Grupos atascado en un teléfono sano, ningún aviso promete que esperar lo cura.
- [ ] Sin salida que pierda nada (decisión A).
