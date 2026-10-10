---
id: born-cloud-signup-into-existing-account-relaunch-says-nothing
status: backlog
priority: low
area: "onboarding, modo-nube, copy"
created: 2026-10-09
updated: 2026-10-09
source: "hallazgo de `born-cloud-signup-lands-on-existing-account-silently` (2026-10-09), inferido por lectura, NO reproducido"
---

# «Crear otra cuenta» que entra en la cuenta existente y acaba en «reinicia Yala» sigue sin decírselo

## El síntoma, en lenguaje de usuario

Pido crear una cuenta en la nube con Apple, leo «Creando tu cuenta…», y la pantalla final es «Ya casi está — reinicia
Yala». Al reabrir estoy dentro de la cuenta que ya tenía ese Apple ID (o de la de otra persona, si el Apple ID es
compartido), y nada me lo ha dicho.

## Lo medido (lectura del código, 2026-10-09)

- `born-cloud-signup-lands-on-existing-account-silently` hizo que el alta que el claim manda a la cuenta existente
  (`existing_stable` → `BornCloudSignUpFlow.continueAsReturningUser` → adopt) termine diciendo «Ya tenías una cuenta, has
  entrado en ella». Eso solo cubre la terminal de «listo» (`.cloudActive` → `.signUpEnteredExistingAccount`).
- Si ese adopt termina en `.needsRelaunch(.toCloud)` —el espejo de iCloud está montado en este arranque—, la fase es
  `.relaunch` y la pantalla es la de siempre (`storage.relaunch.title` / `.body`), venga o no del alta.
- Alcance probable: raro. El alta de «Es mi primera vez» nace con el almacenamiento neutro; el espejo montado exige un
  fichero de store previo (un Welcome tras un kill, o tras un cierre que no armó el neutro). No está medido en device.

## Qué hay que decidir (es copy, y por eso es de Jürgen)

- A (recomendada): el relanzamiento del alta que entró en una cuenta existente añade la misma frase de la decisión del
  2026-10-07 («Ya tenías una cuenta, has entrado en ella») encima de «reinicia Yala». El origen ya viaja hasta el poll
  (`WelcomeAdoptOrigin`), así que es una fase o un parámetro más en `CloudWelcomeSignInFlow.phase`.
- B: se deja así: el caso es raro y la pantalla no promete haber creado nada.
