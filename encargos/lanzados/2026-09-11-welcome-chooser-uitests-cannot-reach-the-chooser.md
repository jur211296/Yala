# Arreglar los 7 XCUITest del Welcome que no pasan del Hero en 2.1 limpio

## Contexto
Ticket `tickets/backlog/welcome-chooser-uitests-cannot-reach-the-chooser` (high). Medido y bisecado el 2026-09-11: fallan en un worktree limpio de `2.1`, no son flaky ni de un PR concreto. El Hero sale y se tapea; el chooser de nivel 1 no llega (`welcome_chooser_restore` / invite / etc. agotan timeout). Sospecha: `WelcomeHeroView.handleEmpezar()` bajo `-uitest` ya no acaba en `goTo(.chooser)` (faro, sonda iCloud, sub-chooser).

Cola autónoma Frank: tras merge de `detach-failure-looks-like-success` (#144). Siguiente después de este: `cloud-killswitch-hides-the-only-door-to-detach-groups` → `shell-derives-from-two-session-axes` (paso 12) → `after-session-redesign-review-widgets-siri-applepay-and-web-copy` (paso 13, mitad app).

## Qué se pide
1. Leer el ticket entero y reproducir los 7 rojos en este worktree (WelcomeChooserUITests + SecondarySessionGateUITests).
2. Encontrar la causa real (no solo «timeout») y documentarla en el ticket.
3. Arreglar para que el chooser / puerta del organizador vuelvan a alcanzarse bajo `-uitest`.
4. Si resulta flaky de runner frío → Lista Negra con fecha de caducidad, no un «fix» cosmétique.
5. Relacionado opcional si cabe sin ensanchar: `nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` es OTRO conjunto; solo menciónalo o crea ticket si lo tocas de rebote — no es el alcance principal.
6. Gate en verde, PR a `2.1`, merge, board + `docs/TICKETS.md` al día, `/cerrar-total`.

## Qué NO hay que tocar
- marketing/
- clinicas
- Ampliar a rediseño de copy/onboarding de producto salvo lo mínimo para que el test vuelva a ver el chooser
- Relanzar o repreguntar decisión de producto del killswitch

## Cómo se sabe que está bien
Los siete en verde en este worktree (idealmente contrastados contra la base). Causa escrita en el ticket. PR mergeado a `2.1`. Índice `docs/TICKETS.md` cuadrado. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Nadie mirando: cada nodo lo contesto yo con mi recomendación y sigo. Se discute en el PR.

**1 · ¿El encargo asume un bug que no existe?** Sí, y se mide antes de tocar código. **Medido**:
los siete casos PASAN en `bef5c134` (11/11), PASAN en `1a9cbb83` —la revisión exacta que el
ticket bisecó— (11/11) y PASAN en la nocturna de CI del 11-sep sobre la suite completa de 149
casos. Las dos suites son byte-idénticas entre esas dos revisiones. ⇒ **no hay rojo que
arreglar**. La hipótesis del ticket (`handleEmpezar()` encamina) es falsa por lectura:
son cuatro líneas que llaman `onContinue()`, y el container va a `goTo(.chooser)` sin más.

**2 · Entonces, ¿qué se entrega?** Tres cosas, en este orden:
  (a) el ticket a `discarded` con la medición escrita — no a `done`: no se arregló nada;
  (b) la causa del FALSO POSITIVO, que es lo único real que queda: el veredicto de una corrida
      no vale si otra sesión entró a mitad, y `sim-libre.sh` solo miraba ANTES de empezar;
  (c) los tickets de lo que no cabe aquí.

**3 · ¿Se toca `qa/scripts/` o se deja en ticket?** Se toca. Es la causa del ticket que estoy
cerrando, no un hallazgo lateral, y el arreglo es un modo nuevo en un script que ya existe
(`--vigilar`), no una superficie nueva. Lo que NO hago aquí es un lock que PREVENGA la colisión:
eso cambia cómo trabajan las 14 sesiones a la vez y merece su propio ticket y su decisión.

**4 · ¿Y la Lista Negra?** No. La Lista Negra es para flaky que caduca; esto no es flaky —los
siete pasan siempre que la corrida esté aislada—. Una entrada ahí diría que hay que
desconfiar de siete tests sanos.

**5 · ¿Se toca `nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo`?** No, es otro conjunto. Pero
la nocturna del 11-sep que medí **confirma que sus cuatro siguen rojos**, así que se anota en él
como dato nuevo sin entrar a arreglarlo.

**6 · Más de 3 ficheros sin aprobación.** El default del repo pide esperar; el encargo dice modo
autónomo hasta terminar. Manda el encargo y se dice aquí: son 6 ficheros, ninguno de `Yala/`.
