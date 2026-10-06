---
id: fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes
status: qa
priority: high
area: "grupos, onboarding"
created: 2026-10-05
updated: 2026-10-06
qa-status: needs-testing
source: "caso 4 de `fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason` (medido leyendo el código el 2026-10-05)"
---

# Tras salir de un adopt, «Empezar de cero» se niega en bucle si hay cambios de grupos que no pueden subir

## El problema, en lenguaje de usuario

Alguien empieza a entrar con su cuenta en la nube desde la bienvenida, el adopt falla o lo cancela, vuelve a la bienvenida
y elige «Soy nuevo → privacidad total». Si el teléfono tiene datos y cambios de grupos que no pueden subir (de otra cuenta,
o de una cuenta sin sesión), el aviso «Borrar todo y continuar» no los sube ni ofrece perderlos: dice «inténtalo de nuevo
en un rato» y no borra. Volver a intentarlo da lo mismo, para siempre. La única salida es desinstalar.

## Lo medido (leyendo el árbol de `088f4e43f`; nada visto en pantalla)

- El único disparador del alert es `ContentView.startFreshPrivateOnboarding` (~L2900), desde el cover del Welcome.
- El botón destructivo llama a `continueInTheGateWhileGroupsArePending` (`ShellDataAlertsModifier.swift` ~L202): con
  `hasCompletedOnboarding == true` NO va a la puerta privada (que sube y ofrece perderlos), sino a
  `refuseWhileGroupsArePending`, que anota `.uploadRetryLater` y se niega.
- **El flag puede estar en `true` con el Welcome montado.** `onAdoptStarted` lo pone a `true` al empezar el adopt
  (`ContentView.swift` ~L2798, llamado desde `WelcomeCloudSignInView.swift` ~L1172), y si el adopt sale por error,
  `.adoptExit`, `.lineageExit` o «Cancelar la activación» (`cancelLanded` → `onBack()`, ~L1204), nada lo devuelve a
  `false`. Los únicos que escriben `false` son `ContentView.swift` ~L1645/1785/2063 y `DataWipeService.swift` ~L1319.
- `onBack` del cover de la nube reabre el Welcome en `.chooser` sin guarda (`ContentView.swift` ~L2880-2883).

Lo que no se pudo comprobar sin dispositivo: que en ese punto haya datos locales con el espejo montado (sin espejo la app
relanza y el alert no sale) y cambios de grupos pendientes. Lo segundo es justo el caso del iPhone heredado o de otra
cuenta, que es para el que existe la salida de la puerta.

Desde el 2026-10-05 (PR del ticket padre) el texto del alert al menos separa los tuyos de los de otra cuenta y no promete
que esperar sube los ajenos; el bucle sigue.

## Propuestas

- **A. El alert pasa por la puerta también con el onboarding completo cuando el Welcome está montado.** La guarda real es
  «¿hay cover debajo?», no `hasCompletedOnboarding`. Coste: decidir qué se ve al volver de la puerta.
- **B. «Cancelar» y los fallos del adopt devuelven `hasCompletedOnboarding` a `false`** si el adopt no llegó a la nube.
  Arregla la causa, pero toca la kill-safety del adopt (el `true` temprano existe para que un kill no siembre el onboarding
  sobre una cuenta existente).
- **C. El alert, con algo que no sube, ofrece la misma salida «perderlos» con su «¿seguro?»** (sin subir: el alert no
  puede esperar una subida, ver su docblock). Coste: duplica la salida en una tercera pantalla.

**Recomendación: A.** Es la que respeta el diseño de hoy —la puerta es la única pantalla que sube, enseña el motivo y
ofrece perderlos— y no toca el adopt. B es más limpia en la causa pero arriesga la kill-safety; C duplica lo que ya hace la
puerta.

## Cómo se sabe que está bien

Con un adopt cancelado, datos locales y un cambio de grupos de otra cuenta, «Soy nuevo → privacidad total → Borrar todo y
continuar» enseña la oferta de perderlos con su cifra, y aceptarla borra.

## Resolución (2026-10-06, decisión A de Jürgen)

- **Qué cambia para el usuario:** tras salir de un adopt, «Soy nuevo → privacidad total → Borrar todo y continuar» con
  cambios de grupos que no pueden subir ya no dice «inténtalo en un rato» para siempre. Sigue en la puerta privada: sube
  lo que pueda, enseña el motivo y, si esperar no lo arregla, ofrece perderlos con su cifra y un «¿seguro?». Volver atrás
  en la puerta deja en la elección privado/nube sin borrar; aceptar perderlos borra y sigue al onboarding privado.
- **Cómo:** el disparador del alert (`ContentView.startFreshPrivateOnboarding`) captura si había Welcome debajo
  (`freshStartAlertPresentedOverWelcome`) antes de encenderlo, y la ruta del botón destructivo decide con
  `FreshStartAlertRoutingLogic` (`!hasCompletedOnboarding || presentedOverWelcome` → puerta). La entrada con la nube, la
  kill-safety del adopt, el texto y las demás salidas del alert no cambian.
- **Medido en la review:** hoy el alert solo se dispara desde el Welcome, así que con grupos pendientes siempre sigue en
  la puerta (también desde un Welcome que una sesión solo-grupos reabre con el onboarding completo; ahí el borrado
  directo con el outbox vacío ya borraba igual). La negativa en el sitio queda para un disparador futuro, y un test cuenta
  los disparadores.
- **Tests:** `FreshStartAfterAdoptExitTests` (tabla de la decisión, cableado entero y la puerta con cambios de otra cuenta
  con las dos sesiones posibles tras la salida). Mutantes sobre la guarda en el PR.
- **Hallazgo aparte:** «Cancelar» y el «OK» del aviso de fallo siguen con la guarda vieja y, tras un adopt, dejan dentro de
  la app → `fresh-start-alert-cancel-after-an-adopt-exit-lands-in-the-app`.

## Guion de device-QA (iPhone real; el simulador no firma con Apple ni Google)

Montaje: build con la entrada en la nube visible en la bienvenida (TestFlight de 2.1 o `Yala Dev`). Un iPhone con Yala ya usada con **privacidad total** (registros propios) y con cambios de un grupo que no hayan
subido —el caso natural es el iPhone heredado: el dueño anterior apuntó gastos en un grupo y su sesión ya no está—.

1. Ajustes → borra los datos o reinstala hasta ver la bienvenida, conservando los cambios de grupos sin subir (si no tienes
   ese estado a mano, apunta un gasto en un grupo con el modo avión puesto justo antes).
2. En la bienvenida: «Ya tengo una cuenta» → entra con una cuenta en la nube.
3. Cuando aparezca la barra de activación, toca «Cancelar la activación» y confirma. Debe volver a la elección.
4. Elige «Soy nuevo» → «Privacidad total». Sale «¿Borrar todo y continuar?».
5. Toca «Borrar todo y continuar». **Esperado:** se abre la pantalla de la puerta privada, no el aviso «inténtalo en un
   rato».
6. Si los cambios no pueden subir, la puerta enseña el motivo y la cifra, y ofrece perderlos. Toca **atrás** primero:
   vuelves a la elección privado/nube y tus datos siguen ahí.
7. Repite 4-5 y esta vez acepta perderlos y confirma el «¿seguro?». **Esperado:** se borra todo y empieza el onboarding
   privado.
8. Variante: en el paso 3, en vez de cancelar, deja que la activación falle (modo avión) y sal con la flecha. El resto,
   igual.
