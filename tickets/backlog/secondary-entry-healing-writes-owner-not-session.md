---
id: secondary-entry-healing-writes-owner-not-session
status: backlog
priority: medium
area: modo-nube
created: 2026-09-05
updated: 2026-09-05
---

# El kill-recovery de la entrada secundaria repara el cajón equivocado

## El síntoma, en lenguaje de usuario

Presto mi móvil a alguien para que entre con su cuenta. Justo en el segundo en que confirma la
entrada, la app se cierra —una llamada, batería, lo que sea—. Al volver a abrir, ella no entra a
su Yala: **le sale la pantalla de bienvenida, como si acabara de instalar la app**, y detrás no
hay nada suyo.

No se queda atrapada: puede elegir «es mi primera vez» y salir de ahí. Pero es el arranque
exacto que el código tiene escrito para evitar.

## Lo medido (2026-09-05, sobre `833b9f40`)

`SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded` tiene una curación de arranque para
esa ventana de kill, y **su docblock nombra el daño que evita**: «sin el healing, el boot mostraría
el Welcome sobre el store secundario vacío y un re-sign-in caería en el adopt CLÁSICO, que escribe
el PAR global `.cloud`+`mirrorOffArmed` del dueño».

El orden dentro de esa función, medido en el árbol:

| # | Paso | Dominio en el que actúa |
|---|---|---|
| 1 | `seedSessionDomain` — la siembra del cajón | copia de `.standard` **al CAJÓN**, con sentinel propio |
| 2 | `republishWidgetSeal` | App Group |
| 3 | `guard !isEntryPurgeDone` | — |
| 4 | custodia del consent + `purge()` + cancelación de avisos | `.standard` / App Group |
| 5 | **el healing de los flags de onboarding** | **`.standard`, el dominio del DUEÑO** |

⇒ en el arranque del kill-recovery, **la siembra (1) copia el `false` que el kill dejó y el healing
(5) lo arregla sólo en `.standard`**. El cajón se queda con `false` y con su sentinel
`session.deviceKeysSeeded` ya puesto, así que la siembra **no vuelve a correr nunca** — y ningún
otro camino repone esa key en el cajón.

Y el lector que decide si se muestra el Welcome (`ContentView.swift:16`, `@AppStorage` bajo
`.defaultAppStorage(SessionDefaults.current)`) lee **el cajón**. Por eso el healing, que existe
para impedir ese Welcome, hoy no lo impide.

## Por qué aparece ahora y no antes

No es una regresión de un commit: es la **mitad que se quedó atrás** cuando entró el dominio de
preferencias por sesión (`prefs-domain-per-secondary-session`, 2026-08-26). Antes del cajón,
escritor y lector de esa key vivían los dos en `.standard` y el healing funcionaba. Al bajar los
lectores al cajón, la reparación se quedó apuntando al dominio de antes.

Es la misma familia exacta que el defecto que cerró `258a90c3` —un par escritor/lector partido
entre los dos dominios— aplicado a la FRONTERA en vez de al onboarding, y por eso se anota aparte:
allí el owner decidió el dominio de la key *dentro* de la sesión; esto pregunta por el de la
*reparación*, que es una decisión distinta.

## Lo NO medido

- Si el re-sign-in desde ese Welcome cae de verdad en el adopt clásico **hoy** (el docblock lo
  afirma, pero es anterior al cajón y a los guards de M1). Es la mitad que convierte esto de
  molestia en daño al dominio del dueño, así que es lo primero que hay que comprobar.
- Cuánto dura la ventana de kill en un teléfono real. Entre `activate` y el relanzamiento hay
  segundos, no minutos.

## Las dos salidas, para que la decisión no haya que reconstruirla

1. **El healing escribe en los DOS dominios.** Barato y local: el `defaults.set` de los flags se
   acompaña de su gemelo en el cajón. Contra: duplica una escritura y deja dos verdades que hay
   que mantener alineadas — justo lo que el dominio por sesión vino a quitar.
2. **La siembra deja de ser one-shot cuando lo que copió era `false`.** Ataca la causa (el cajón
   heredó un valor que el healing iba a corregir un instante después) pero cambia el contrato de
   idempotencia de `seedDeviceKeysIfNeeded`, que se escribió a propósito con sentinel propio (D3).

Hay una tercera que parece obvia y **está cerrada**: mover la siembra detrás del healing. La
siembra vive FUERA del guard one-shot por decisión D3 del owner —con el cajón, sembrar dejó de ser
kill-recovery y pasó a ser el camino normal— y el healing vive DENTRO. Reordenarlas es cambiar esa
decisión, no moverlas de sitio.

## Criterio de hecho

- El arranque de kill-recovery deja `hasCompletedOnboarding` coherente **en el dominio que el
  lector del Welcome consulta**, con test que lo ejercite por la variante inyectable de la función.
- Mutación: quitar la reparación del cajón tiene que dar exit 65.
- La medición de «lo NO medido» resuelta antes de elegir salida: si el adopt clásico ya no es
  alcanzable, esto es una molestia de UX y no un bloqueante del encendido.

## Relacionados

- [[secondary-visitor-writes-owner-domain]] — el ticket madre; su vía 5 describía la otra mitad
  de este mismo hueco (el marker `entryPurgeDone` fuera del barrido de prefs)
- [[prefs-domain-per-secondary-session]] — el trabajo que introdujo el cajón
