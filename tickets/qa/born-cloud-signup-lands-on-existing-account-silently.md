---
id: born-cloud-signup-lands-on-existing-account-silently
status: backlog
priority: medium
area: "onboarding, modo-nube, copy"
created: 2026-09-10
updated: 2026-10-07
source: "review adversarial (lente de producto) de `beacon-routes-only-never-blocks`, 2026-09-10"
---

# «Crear otra cuenta» → nube → Apple entra en la cuenta que ya existe, diciendo que la crea

## El síntoma, en lenguaje de usuario

Con el faro de Apple puesto y su cuenta viva: «Es mi primera vez» → «Crear otra cuenta» → «Tu cuenta en
la nube» → «Registrarse con Apple». Leo «Creando tu cuenta…» y termino en «¡Tu cuenta está lista!», pero
estoy DENTRO de la cuenta que ya existía. Nada me lo dice. Si el Apple ID es compartido, es la cuenta de
otra persona, con sus finanzas.

## Lo medido (2026-09-10)

- Un Apple ID tiene UNA identidad de Sign in with Apple, así que el claim del alta contesta
  `existing_stable` y el flujo va a la variante A de §f.1: `AccountClaimDecision` → `.routeReturningUser` →
  `BornCloudSignUpFlow.continueAsReturningUser` → `runSignInFlow` → adopt → `.reentryReady`.
- **El comportamiento es anterior y correcto**: no sembrar encima de una cuenta viva. Tampoco expone nada
  nuevo: «Ya tengo cuenta → Apple» entra igual en esa cuenta.
- **Lo que cambió es la alcanzabilidad**: antes el faro no dejaba llegar al alta con su cuenta viva; desde
  el paso 6 se llega por diseño (decisión de Jürgen: el chooser entero, sin recortar). El ticket del paso 6
  ya contaba con que «otro Apple» no se plantea, porque SIWA solo ofrece el Apple ID del teléfono; lo que
  falta es decírselo a la persona.

## Qué hay que decidir (es copy, y por eso es de Jürgen)

- ¿La terminal del alta que acaba en `existing_stable` dice «Ya tenías una cuenta con este Apple ID: has
  entrado en ella»? Hoy comparte `.reentryReady` («¡Tu cuenta está lista!») con la re-entrada.
- ¿O el intro del alta, cuando llega desde «Crear otra cuenta» con faro de Apple, avisa de que con Apple
  se entra en la existente? Ojo con la decisión del 2026-09-09: pide no añadir avisos que nadie pidió.

## Decisión de Jürgen (2026-10-07)

Sí. Se avisa: **«Ya tenías una cuenta, has entrado en ella»**.

A qué parte corresponde: es la primera de las dos preguntas de «Qué hay que decidir»: la terminal del alta que acaba en
`existing_stable` deja de compartir «¡Tu cuenta está lista!» con la re-entrada y dice ese texto. La segunda pregunta
(avisar ya en el intro del alta) no se elige. El texto, con las palabras de Jürgen, se lleva a todos los idiomas de la
app.
