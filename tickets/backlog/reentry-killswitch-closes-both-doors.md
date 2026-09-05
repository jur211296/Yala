---
id: reentry-killswitch-closes-both-doors
status: backlog
created: 2026-09-05
updated: 2026-09-05
source: tickets/qa/reentry-counts-as-fresh-install.md (§4, §5 y §6)
---


# Con el kill-switch, quien vuelve se queda sin las DOS puertas

Sale de `reentry-counts-as-fresh-install`, cuyas piezas 1-3 quedaron cerradas el 2026-09-05. Lo que
sigue aquí es lo que **no** se tocó: una pieza que necesita decisión de producto y dos que son diseño y
comentario, no fix. Se separan para que el ticket padre pueda irse a QA sin arrastrarlas.

**Las coordenadas de abajo vienen del ticket padre y NO se re-midieron en esta sesión.** Greppea antes de
abrir una línea citada.

## 1 · El residual escrito solo menciona una de las dos puertas

El comentario en el código dice que «un usuario nube que REINSTALA bajo el kill no ve la card → no
re-entra hasta re-encendido». Lo que el padre midió es que la fila **«Dónde viven tus datos»** de
Ajustes —la segunda puerta, la de la adopción por marcador— **también desaparece**: su gate es
`remoteEnabled || isEngaged` (`StorageRowGateLogic`) y una reinstalación no puede ser engaged. El faro
además deja de encaminar, porque `cloudEntryAvailable` se deriva de la card que se fue
(`WelcomeAccountChoiceLogic`).

Para un born-cloud, la única card que queda («Restaurar desde iCloud») termina en **«No encontramos tus
datos»** con sus datos intactos en el backend.

**Por qué no entró:** tocar el gate del kill-switch es una decisión de producto de Jürgen —el encargo del
5-sep lo excluía explícitamente— y lo barato mientras tanto es que el residual del código deje de
describir mal lo que hace. Lo mínimo aquí es corregir ese comentario; lo completo es decidir si la
segunda puerta debe seguir viva bajo el kill.

## 2 · El relanzamiento cero llegó al alta y no a la re-entrada

En un móvil recién instalado los dos caminos montan el mismo store neutro. El alta born-cloud pregunta
al testigo de mount y termina en «¡Tu cuenta está lista!» arrancando el motor **en sesión**; el adopt no
pregunta nada y cae en la terminal «Ya casi está — reinicia Yala».

Medido en el padre: `startAdoptWithExistingSession` **no** llama a `startRuntimeIfStable()`, así que hoy
el relanzamiento es lo único que arranca el motor — la pantalla es honesta en el efecto, pero el
comentario de `CloudWelcomeSignInFlow` («el relaunch ya se resolvió en otro proceso — terminal
equivalente») describe mal este caso: aquí ningún proceso resolvió nada.

**Es una oportunidad de producto, no un defecto**, y por eso no se implementó: si el motor arrancara en
sesión como en el alta, la re-entrada podría dejar de pagar su relanzamiento. Necesita decisión antes que
código.

## 3 · Un belt que se justifica con una premisa falsa

El paso 4 de `runAdoptFlow` acepta `markerCount == 0` con un breadcrumb porque «la ruta ya validó el
marcador al abrir la pantalla» (`MigrationWorkExecutor`). Cierto para la puerta de Ajustes; **falso para
la puerta del Welcome**, que nunca mira ningún marcador. En un móvil recién instalado el marcador es
*imposible* (vive en el mirror de CloudKit y el proceso montó sin mirror) ⇒ el breadcrumb «marker absent»
es el caso **normal** de este recorrido, no una anomalía a investigar.

Es un docblock, y la prioridad del padre decía «con el siguiente cambio que toque esos ficheros». Las
piezas 2 y 3 no tocaron `MigrationWorkExecutor.swift`, así que sigue esperando a quien lo haga.

## Relacionados

- [[reentry-counts-as-fresh-install]] — el padre, en `qa/` desde el 2026-09-05
