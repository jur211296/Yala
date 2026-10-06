---
id: fresh-start-alert-cancel-after-an-adopt-exit-lands-in-the-app
status: backlog
priority: medium
area: "onboarding, modo-nube"
created: 2026-10-06
updated: 2026-10-06
source: "hallazgo de `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes` (leído en el código el 2026-10-06, sin ejecutar)"
---

# Tras salir de un adopt, «Cancelar» en «¿Borrar todo y continuar?» te deja dentro de la app en vez de en la bienvenida

## El problema, en lenguaje de usuario

Alguien empieza a entrar con su cuenta en la nube desde la bienvenida, el adopt falla o lo cancela y vuelve a la
bienvenida. Elige «Soy nuevo → privacidad total», le sale «¿Borrar todo y continuar?» porque el teléfono tiene datos, y
toca «Cancelar». Espera volver a la pantalla donde estaba; en vez de eso aterriza dentro de la app, sobre los datos que
estaba a punto de borrar, como si hubiera terminado el onboarding. Lo mismo con el «OK» del aviso de que el borrado falló.

## Lo medido (leyendo el árbol de `5c493dedb`; nada visto en pantalla)

- Presentar ese alert desmonta el cover del Welcome (traza medida en `ShellDataAlertsModifier`), así que al cerrarlo no
  queda nada montado debajo.
- «Cancelar» y el «OK» del aviso de fallo reabren el Welcome solo `if !hasCompletedOnboarding`. Su comentario dice que con
  el onboarding completo «el Welcome NO estaba montado»: **falso tras salir de un adopt**. `onAdoptStarted` pone el flag en
  `true` (kill-safety del adopt) y ninguna salida (error, `.adoptExit`, `.lineageExit`, «Cancelar la activación») lo
  devuelve; todas vuelven al Welcome por el mismo `onBack`.
- El único disparador del alert es `startFreshPrivateOnboarding`, y sus dos llamadores son closures del Welcome: hoy el
  alert siempre se presenta con el Welcome debajo.
- Desde `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes` existe el testigo que lo dice
  (`freshStartAlertPresentedOverWelcome`, capturado al disparar) y lo usa solo el botón destructivo con cambios de grupos
  pendientes. Aquel encargo pedía no tocar las demás salidas, y por eso estas dos siguen con la guarda vieja.

## Propuesta

Las dos salidas usan el mismo testigo: reabren el Welcome en `.chooser` si el alert se presentó sobre él. Sin cambio para
quien no completó el onboarding. Decidir antes si aterrizar en la app tras un adopt cancelado es aceptable (es lo mismo que
deja un kill a mitad del adopt) o si la bienvenida es lo correcto.

## Cómo se sabe que está bien

Con un adopt cancelado y datos locales, «Soy nuevo → privacidad total → Cancelar» vuelve a la elección privado/nube, y el
«OK» del aviso de fallo también.
