---
id: welcome-privacy-branch-has-no-secondary-door
status: backlog
priority: medium
area: modo-nube
created: 2026-09-05
updated: 2026-09-05
---

# «Es mi primera vez → privacidad total» no dice nada a quien está de visita

## El síntoma, en lenguaje de usuario

Estoy usando Yala con mi cuenta en el móvil de otra persona. Si llego a la pantalla de bienvenida
y elijo «Es mi primera vez → privacidad total», la app me deja pasar **sin decirme una palabra de
que estoy de visita**. La rama de al lado —«Vengo por un grupo → crear mi primer grupo»— sí me
para y me lo explica.

## Lo medido (2026-09-05, sobre `833b9f40`)

`WelcomeFlowContainer.handleNewOption` (`:287-300`):

```
289  case .privateAccount:
293      leaveWelcome(to: .privateOnboarding) { onSelectPrivateAccount() }
```

Ni un término de sesión secundaria. La rama hermana sí lo tiene, y con copy propio:
`GroupsOrganizerGateLogic.decide` abre con `guard !isSecondarySession else { return
.blockedSecondarySession }` (`:101`), **antes** que `hasExistingData`, y su cabecera explica por
qué el copy no se presta del guard de datos ajenos: «el hecho es distinto —"estás de visita", no
"hay datos de otro humano"— y la salida también».

El detector de datos existentes tampoco la para: `checkHasExistingData` mide el **store montado**,
que en sesión secundaria es el de la visita y está vacío ⇒ el alert de borrado ni salta.

## Qué CAMBIÓ desde que este hueco se describió, y por qué la pregunta es más estrecha ahora

Cuando esto se midió por primera vez (2026-08-12) la preocupación era el daño: lo que la visita
escribiera aguas abajo caía en el dominio del dueño. **Eso ya no pasa.** El dominio de preferencias
por sesión (2026-08-26) y el commit `258a90c3` (2026-09-05, `hasCompletedOnboarding` al cajón)
cierran las escrituras; lo que la visita haga en su onboarding privado se queda en su cajón y en su
store.

⇒ **lo que queda no es un bug de datos, es una pregunta de producto**: ¿qué se le enseña a alguien
que está de visita y elige «empezar de cero»? Hoy se le enseña un onboarding privado normal, que es
defendible; lo que no es defendible es que la rama de al lado sí le diga que está de visita y ésta
no — la app se contradice según por dónde entre.

Decisión del owner del 2026-09-02 para la familia entera: **encauzar, no bloquear**. Aplicada a
esta rama, «encauzar» ya es lo que ocurre. Falta decidir si además se le dice.

## Efecto colateral medido que sí conviene resolver con esto

**El onboarding privado en secundaria promete categorías y no crea ninguna.** `completeOnboarding`
llama a `seedCategoriesIfNeeded`, y el seed retorna en su primera línea si hay sesión secundaria
(`CategorySeed.swift`, cinturón M1). Pregunta si quiere las categorías de ejemplo, ella dice que
sí, y el store queda vacío. Es pequeño y es exactamente el tipo de detalle que hace que la visita
crea que la app está rota.

## Las salidas

1. **Una pantalla propia**, molde `welcome.groups.secondary*`: «estás usando Yala en el móvil de
   otra persona; lo que apuntes aquí es tuyo y no se mezcla con lo suyo», y sigue. Informa sin
   bloquear, que es la decisión del owner aplicada a la letra.
2. **Nada, y se declara**: la rama funciona y ya no daña. Entonces el trabajo es quitar la
   asimetría por el otro lado o dejar escrito por qué las dos ramas se comportan distinto.

En cualquiera de las dos, el seed de categorías se arregla o se deja de prometer.

## Criterio de hecho

- Las dos ramas del chooser tratan la sesión secundaria de forma coherente, y si difieren está
  escrito por qué.
- El onboarding privado en secundaria no ofrece nada que después no haga.
- Copy propio, nunca prestado del guard de datos ajenos — ver
  [[welcome-copy-blames-owner]].

## Relacionados

- [[secondary-visitor-writes-owner-domain]] — el ticket madre; ésta era su vía 2
- [[welcome-copy-blames-owner]] — el precedente de por qué el copy no se presta
