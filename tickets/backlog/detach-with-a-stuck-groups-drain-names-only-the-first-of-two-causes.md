---
id: detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes
status: backlog
priority: very-low
area: "grupos, sync, copy"
created: 2026-10-05
updated: 2026-10-05
source: "pariente de `groups-stuck-drain-on-a-healthy-phone-says-try-again-later` (encargo del 2026-10-05, punto 3)"
---

# Desasociar con el drain de Grupos atascado y la sesión caducada dice solo «tu sesión caducó»

## El problema, en lenguaje de usuario

Rarísimo: hacen falta dos fallos a la vez. Si este teléfono no consigue preparar para subir un cambio de tus grupos
—siempre, no una vez— **y además** tu sesión de grupos caducó, «Desasociar» dice «Tu sesión de grupos caducó. Entra otra
vez y vuelve a intentarlo». Es verdad, y volver a entrar hace falta igual. Pero no basta: al volver a intentarlo sale el
segundo aviso, «Algunos de los últimos cambios de tus grupos no se pudieron preparar… cierra y vuelve a abrir Yala; si sigue
pasando, actualízala». La persona se entera de los dos problemas de uno en uno. No se pierde nada.

Lo mismo con el teléfono sin App Attest en lugar de la sesión caducada: el desasociar dice primero lo del App Attest.

## Por qué pasa (medido en el código el 2026-10-05)

- `CloudSignOutFlowLogic.stuckCaptureVerdict`: con la captura atascada, si el último ciclo paró por un motivo que abre la
  salida de la pérdida (`lossCause`: sin App Attest, sin sesión, otra cuenta), devuelve ESE motivo. Es lo correcto en los
  cierres de sesión, porque su salida «Cerrar sesión y perderlos» cuenta también lo que el drain no capturó y lo resuelve
  todo de una vez.
- El desasociar comparte el push-all pero no ofrece esa salida (`detachGroupsAccount` pasa `lossExit: nil`, decisión de
  Jürgen del 2026-09-15). Así que allí el motivo del ciclo solo sirve para el aviso, y el aviso nombra una causa de dos.
- Cambiar qué texto gana, o juntar los dos, es una decisión de copy: no se tocó en el ticket padre.

## Propuestas (decide Jürgen)

- **A.** En el desasociar, con la captura atascada gana el drain: sale `.groupsCaptureUnfinished`. Cero copy nuevo. Pero
  quien arregle el drain (actualizando la app) se encuentra después con «tu sesión caducó»: también son dos pasos, en el
  otro orden, y el primer aviso calla algo que la persona podría arreglar ya.
- **B (recomendada).** Un texto propio que diga las dos cosas, solo para el desasociar: «Tu sesión de grupos caducó y
  algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. No se pierden. Entra otra vez, cierra
  y vuelve a abrir Yala (si sigue pasando, actualízala) y vuelve a intentarlo.» Más el gemelo del App Attest. Es lo más
  honesto, y es lo que Jürgen suele preferir aunque cueste más: dos motivos o una marca en el bloqueo, y 2 textos × 16
  locales.
- **C.** Dejarlo como está. Cada aviso es verdad, y los dos pasos hacen falta igual; hacen falta dos fallos raros a la vez.

## Criterios de aceptación (si se elige A o B)

- [ ] Desasociar con el drain atascado y la sesión caducada (o sin App Attest) dice lo que hay que hacer para TODO, o al
      menos no calla el atasco.
- [ ] Sin salida que pierda nada en el desasociar (decisión del 2026-09-15).
- [ ] Los cierres de sesión no cambian: su aviso de pérdida ya cuenta lo que el drain no capturó.
