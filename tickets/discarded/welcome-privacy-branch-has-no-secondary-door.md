---
id: welcome-privacy-branch-has-no-secondary-door
status: discarded
priority: medium
area: modo-nube
created: 2026-09-05
updated: 2026-09-09
---

# «Es mi primera vez → privacidad total» no dice nada a quien está de visita

Why: Discarded 2026-09-09. Superado por el ADR 2026-09-09 «Sesiones — dos ejes» (docs/DECISIONS.md): la sesión de visita (M1) se retira del modelo. La rama privada ya no puede recorrerse «de visita».

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

## Decisión Jürgen (2026-09-06)

**Salida 1: una pantalla propia, informa sin bloquear.** Elegida entre las dos salidas de arriba (y
«no decidir hoy»). Motivo, tal como se le puso delante y ratificó: es su «encauzar, no bloquear» del
2-sep aplicado a la letra, con el mismo molde que ya usa la rama de Grupos
(`welcome.groups.secondary*`); y la app deja de contradecirse según por dónde entres. Y lo del seed:
el onboarding en visita **deja de ofrecer** las categorías de ejemplo que no va a crear.

## Criterio de hecho

Resuelto por la decisión de arriba:

- [x] «Es mi primera vez → privacidad total» en sesión secundaria muestra una pantalla propia que dice
      que estás de visita y que lo tuyo no se mezcla con lo del dueño, y **sigue** al onboarding.
      → `WelcomeSecondaryNoticeView` + step `.privateSecondaryNotice`. Visto en pantalla:
      `tickets/qa/evidencia-welcome-privacy-secondary/01-aviso-visita.png`.
- [x] El onboarding privado en secundaria no ofrece el seed de categorías. **Se eligió NO ofrecerlo**
      (la decisión del 6-sep), no crearlo: el cinturón M1 de `seedCategoriesIfNeeded` es una
      invariante del store de la visita y forzarlo sería reabrirla. El paso desaparece del flujo
      (`OnboardingStepPlan`) y la fila del resumen tampoco se pinta. Visto en pantalla: el indicador
      pasa de 8 a 7 pasos (capturas 02 y 03).

- Las dos ramas del chooser tratan la sesión secundaria de forma coherente, y si difieren está
  escrito por qué.
- El onboarding privado en secundaria no ofrece nada que después no haga.
- Copy propio, nunca prestado del guard de datos ajenos — ver
  [[welcome-copy-blames-owner]].

## Relacionados

- [[secondary-visitor-writes-owner-domain]] — el ticket madre; ésta era su vía 2
- [[welcome-copy-blames-owner]] — el precedente de por qué el copy no se presta


---

## Lo hecho (2026-09-07)

### En lenguaje de usuario

Si usas Yala con tu cuenta en el móvil de otra persona y eliges «Es mi primera vez → privacidad
total», ahora Yala te lo dice antes de empezar: **«Lo tuyo no se mezcla con lo suyo»**, con una
explicación de una frase y un botón para seguir. No te para: informa y continúa, que es la decisión
del 2-sep aplicada a esta rama. Y el onboarding deja de ofrecerte unas categorías de ejemplo que
nunca iba a crear — un paso menos, en vez de una promesa incumplida.

### La premisa del ticket se midió otra vez, y trajo un hecho que no estaba escrito

El ticket decía que la rama «ya no daña, es coherencia + seed». Medido sobre este árbol, eso es
cierto **y se queda corto en un punto que cambia el copy**: la card que la visita acaba de tocar
promete «tus datos … se sincronizan por tu **iCloud privado**» (`welcome.new.privateBody`), y en
sesión secundaria eso **no ocurre**: el store se monta con `cloudKitDatabase: .none`
(`SwiftDataConfiguration.swift:1188`), así que no se espeja a ninguna CloudKit — ni a la del dueño ni
a la de la visita. Por eso el cuerpo del aviso dice «se guarda solo para ti y solo en este
dispositivo», que es el hecho verdadero y no una cautela. La card en sí es de otro ticket
(`welcome-private-card-promises-icloud-in-visit`): hoy casi nadie la lee, porque en producción el
sub-chooser no se muestra.

### Y un segundo defecto del mismo patrón, que salía del propio arreglo

**En visita, el saldo inicial que la persona teclea se descartaba en silencio.** Con el paso de
categorías respondido que sí (su default), `completeOnboarding` llamaba al seed, el cinturón M1 lo
cortaba y **nadie creaba la subcategoría «Ajuste de saldo»** — así que `createOnboardingAccount`
no encontraba dónde colgar el importe, imprimía un `print` de DEBUG y seguía. La visita ponía
«tengo 500» y su cuenta nacía en cero.

No hizo falta un arreglo aparte: es la rama `!willSeedCategories` la que llama a
`ensureBalanceAdjustmentSubcategoryExists`, así que **tratar la visita como «sin seed» —que es lo
que la decisión pedía— lo cierra de paso**. Cubierto por `SecondarySessionInitialBalanceTests`, que
se ejecuta de verdad contra un store vacío.

## Cómo se verificó

| Qué | Cómo |
|---|---|
| El aviso sale y **no bloquea** | `SecondarySessionGateUITests#test_privateBranch_inSecondarySession_informsAndThenContinues` — el aviso aparece, y tras el CTA el onboarding MONTA |
| Que no sale de más | `#test_privateBranch_withoutSecondarySession_goesStraightToOnboarding` — mismo build, misma card, única diferencia el seam |
| El cableado no se puede descablear en silencio | `WelcomeSecondaryNoticeWiringTests` — **control positivo por mutación: 4 mutantes → 5 tests rojos, los 5 esperados**, y los otros 24 verdes |
| El skip del paso | `OnboardingStepPlanTests` ×4 (pure-logic ejecutada, incl. default e idempotencia con `groupsOnly`) |
| El saldo inicial | `SecondarySessionInitialBalanceTests` ×2, contra un `ModelContext` real |
| **En pantalla** | Las tres capturas de `tickets/qa/evidencia-welcome-privacy-secondary/` |

**Y la pantalla cazó lo que el fuente escondía.** La primera captura mostró el copy VIEJO con el
fichero fuente ya corregido: `es.lproj` y `pt.lproj` son **copias regeneradas** de `es-419` y
`pt-BR`, y editar los `.strings` después de correr `add-l10n-key.sh` los dejó atrás — con un
`[NEEDS_TRANSLATION]` vivo en `pt`. Se arregló re-corriendo el script (que resincroniza los alias) y
se volvió a mirar. Los 16 locales pasan `LocalizationParityTests` (15 tests, 3 suites).

## Coherencia con la rama de Grupos, escrita

Las dos ramas nombran el mismo hecho —«estás de visita»— y **se comportan distinto a propósito**:

| | Grupos (`.blockedSecondarySession`) | Privada (`.privateSecondaryNotice`) |
|---|---|---|
| Qué hace | **Bloquea** | **Informa y sigue** |
| Por qué | Detrás, el alta escribe seis preferencias en el `UserDefaults` del DUEÑO | No queda nada que impedir: el dominio por sesión (26-ago) y `258a90c3` cerraron esas escrituras |
| Copy | Propio (`welcome.groups.secondary*`) | Propio (`welcome.private.secondary*`) |

El copy **no se comparte**, y la razón está en el docblock de la vista: la de Grupos tiene que sonar
a «no puedes» justo donde ésta suena a «puedes, y esto es lo que pasa». Compartir la key ataría las
dos pantallas a evolucionar juntas para siempre — el precedente es [[welcome-copy-blames-owner]].

## Lo que NO cierra este commit

**Queda device-QA, y es del owner.** El seam `-uitest-secondary-session` enciende el descriptor pero
**no monta un store secundario** (bajo `-uitest` los `ModelConfiguration` devuelven sus variantes
`…-UITest` antes de mirarlo), así que lo comprobado en simulador es la decisión y la pantalla, no el
e2e. Falta, con dos cuentas reales y SIWA:

1. Que la visita complete el onboarding privado y sus datos aparezcan en SU store y no en el del dueño.
2. Que su saldo inicial quede registrado (el arreglo de arriba, en un store real).
3. Que el copy quepa en los idiomas largos (alemán y neerlandés son los candidatos; solo se vio en español).

Por eso el ticket pasa a `qa/` y no a `done`.
