---
id: full-activation-cloud-adopt-when-account-already-complete
status: backlog
priority: low
area: "modo-nube, groups"
created: 2026-09-11
source: "paso 8 del rediseño de sesiones (`full-mode-activation-must-ask-where-personal-data-lives`), decisión D6 del Paso 0"
---

# «Activar Yala completo → nube» con una cuenta que ya es completa se bloquea en vez de traerla

## El síntoma, en lenguaje de usuario

Tengo dos móviles con la misma cuenta de grupos. En el primero activo Yala completo → nube. En el segundo,
que sigue en solo-grupos, toco «Activar Yala completo» → «Tu cuenta en la nube» → hago el onboarding → «Tu
cuenta ya tiene finanzas personales. Para usarlas aquí, cierra sesión y vuelve a entrar con ella». Es
seguro —no se escribe nada— pero es un rodeo, y me lo dice después de hacerme el onboarding.

## Por qué quedó así (medido el 2026-09-11)

- La promoción es el alta born-cloud de siempre: con la fila ligera de grupos el claim contesta `created`;
  con una cuenta que ya tiene lo personal reclamado contesta `existing_stable`
  (`qa/cloud/g15_01_account_kind.sql`). Sembrar ahí un segundo corpus sería una fusión, que el ADR
  descartó, así que el paso 8 bloquea sin escribir nada.
- Se sabe **después** del onboarding porque la promoción va al final (decisión de Jürgen) y el Worker
  todavía no sirve `kind`: sin él, [I] no puede distinguir antes una cuenta completa de una solo-grupos.
- Adoptar en sitio necesita el camino del adopt (`WelcomeCloudSignInView.runAdoptFlow`), que vive dentro
  del cover del Welcome, con su guard cross-cuenta y su máquina.

## Alcance

- Con `kind` desplegado: preguntar a [I] ANTES del onboarding y, si es `complete`, no hacerlo.
- Adoptar en sitio: consentimiento → adopt (pull del backend) → shell completa, sin cerrar sesión.

## Criterios de aceptación

- [ ] Segundo móvil en solo-grupos + cuenta ya completa → «Activar Yala completo → nube» trae los datos
      personales de la cuenta sin pedir onboarding ni cerrar sesión.
- [ ] Una cuenta que volvió a iCloud (`reverted_at`) sigue sin poder promocionarse por aquí: el
      re-cutover es diseño futuro.

## Nota (2026-09-24, `claim-replay-can-seed-beside-a-phone-that-adopted-silently`)

Desde `qa/cloud/g16_02_…` esta pantalla también le sale al **reintento** de «Activar Yala completo» cuando otro teléfono
entró en la cuenta mientras la respuesta se perdía. Ahí el texto «Esta cuenta ya guarda datos personales» puede ser
falso —el otro teléfono entró y aún no subió nada— y «No cambiamos nada» también: la promoción de este teléfono sí
cambió la cuenta. Adoptar en sitio (el alcance de este ticket) lo resolvería igual; si se toca el copy antes, tenerlo
en cuenta.
