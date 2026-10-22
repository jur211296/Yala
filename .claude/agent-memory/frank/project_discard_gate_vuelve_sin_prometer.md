---
name: discard-gate-vuelve-sin-prometer
description: PR #160 — «Empezar desde cero» sin iCloud vuelve a Restaurar en vez de mentir; la review cazó que MI extensión al estado K creaba un camino muerto
metadata:
  type: project
---

**PR #160** (2026-09-14), hermano del #159 y del ticket padre
`activation-restore-start-fresh-keeps-the-imported-rows`. Al activar Yala completo, «Restaurar → Empezar
desde cero» sin respuesta de iCloud decía «Seguir así» y llevaba al onboarding con los datos viejos
enteros — y dejaba la app apuntada para el aviso del espejo tardío, cuyo borrado es `.handover`: purga el
dominio de Grupos de quien activó **para conservarlos**. Decisión (a) de Jürgen: volver a Restaurar sin
declarar nada.

**Why:** el parámetro `unverifiedExit` (enum de 2 casos, **sin default**) es el patrón que este fichero ya
usaba con `deviceCorpus` — la vista la montan tres sitios y contestan cosas opuestas.

**How to apply:** tres cosas que conviene recordar de aquí.

1. **La premisa del ticket era falsa y cambió el alcance.** Decía que `.noICloud` es inalcanzable por ese
   camino. Medido: `WelcomeRestoreView` ofrece «Empezar desde cero» desde tres estados que NO afirman que
   haya datos (`notFoundView`, `iCloudDisabledView`, `wipedView`), y llaman directo sin diálogo.
   [[feedback_la_premisa_del_encargo_tambien_se_mide]] otra vez.
2. **Y extender el arreglo a esa fase fue MI defecto más grave** — un camino muerto de dos pantallas, ver
   [[feedback_mi_salida_nueva_es_un_camino_muerto]]. Hoy `.noICloud` ofrece «Reintentar» en el desenlace
   que vuelve, y su cuerpo dice la causa.
3. **El chooser de la activación NO tiene «Restaurar»**: solo `.privateAccount` → `.privateGate` y
   `.cloudAccount` → `.consent`. A `.restore` se llega por `onRestore` de `.privateGate` (que exige
   `.found`) o por el resume. Dato que zanja varias hipótesis sobre alcanzabilidad en esa pantalla.

Deja `tickets/qa/device-qa-discard-gate-returns-to-restore-without-icloud.md` (no simulable: `measure()`
sale por `isUITesting` antes de la sonda) y dos tickets `low`:
`discard-gate-proceed-leaves-the-imported-rows-behind` y
`welcome-discard-gate-says-carry-on-right-after-asking-to-wipe`.

**Una consecuencia que Jürgen tiene que ver, y está destacada en el PR:** con iCloud apagado, la rama
privada de la activación ya no se puede terminar por «Empezar desde cero» sin encenderlo (antes seguía,
mintiendo). Si prefiere lo contrario, es un valor en un call-site.
