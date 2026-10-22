---
id: groups-background-emitter-no-upload
status: done
priority: medium
area: groups
created: 2026-08-02
updated: 2026-08-28
source: YalaWiki/Backlog/groups-emisor-segundo-plano-no-sube.md
---


# El gasto de grupo no sale del teléfono hasta que vuelves a abrir la app


## Estado 2026-08-18

En árbol de `2.1` vía [PR 19](https://github.com/jur211296/Yala/pull/19). Merge `b9526c8e` (head `c1577137`).

Código: al crear o editar un gasto de grupo, se pide `beginBackgroundTask` y un ciclo (debounce 2 s). No es `BGAppRefresh`.

CI de #19: coverage-index + tests verde. **QA device pendiente.** No PASS. No ok_. 2.1 en TestFlight, build 11 (VALID). No corregir a 1.

## Problema

Añades un gasto compartido, guardas el teléfono en el bolsillo y sigues con tu
vida. Para ti está hecho. Para el resto del grupo no ha pasado nada: no lo ven,
no les llega notificación, y el balance sigue como estaba. El gasto no sube
hasta que **tú** vuelves a abrir Yala.

Si además la otra persona te pregunta y tú miras tu teléfono, lo ves ahí
perfectamente — porque en tu dispositivo sí está. Desde fuera parece que Yala
perdió el gasto o que el grupo está roto.

No hay pérdida de datos: en cuanto reabres la app sube todo lo pendiente de
golpe. Pero el retraso es indefinido y el usuario no tiene forma de saber que
está pasando.

## Por qué pasa

La subida del canal de Grupos la mueve un loop que cicla cada 60 segundos
(`GroupsSyncClient.runLoop`, intervalo en `SyncCadencePolicy`). Cuando la app
va a segundo plano iOS la suspende y ese loop deja de ciclar. **No hay nada más
que dispare la subida en el emisor**: ni `BGAppRefreshTask`, ni
`BGProcessingTask`, ni una tarea de fondo colgada del guardado.

El silent push sí despierta al que **recibe** (`YalaAppDelegate` →
`syncNowFromPush`), pero eso solo sirve después de que alguien haya subido. El
emisor es justamente el eslabón sin despertador.

Comportamiento correcto de iOS, no un bug del código. Es un hueco de producto.

## Lo medido (2026-08-02, build 9, producción, dos iPhones)

- Con la app **en primer plano** y sin tocar nada, el gasto se captura y sube
  sola en ~27 s. Verificado con el `GroupsSyncOutboxMirror` en el log del
  device y el `POST /groups/push` en el tail.
- Ese mismo día hubo **siete minutos** de silencio con dos cambios pendientes
  en el emisor, que se resolvieron al instante al volver a la app.

Honestidad sobre la evidencia: lo primero está **medido**; que los siete
minutos fueran por segundo plano es la explicación que encaja con todo, pero
no se midió (no había consola conectada). Si al implementar esto aparece un
silencio con la app **delante**, es otra cosa y hay que mirar el ciclo de vida
del loop, no el segundo plano.

## Solución a evaluar

El seam ya existe y está declarado como diferido: **`SyncCadencePolicy.pushDebounce`
(= 2 s) no tiene ni un consumidor** en todo el código. Esta es la tarea que lo
justifica.

Opciones, de menos a más ambiciosa:

1. **Tarea de fondo corta al guardar.** Al crear o editar un gasto de grupo,
   pedir una `UIApplication.beginBackgroundTask` y correr un ciclo. Da ~30 s de
   ejecución después de que el usuario salga de la app, que cubre el caso
   dominante —crear el gasto y guardar el teléfono— sin depender del criterio
   de iOS. Es la de mejor relación coste/beneficio.
2. **`BGAppRefreshTask`** como red para lo que quede. iOS decide cuándo y puede
   tardar horas, así que no sustituye a la 1: la complementa para el teléfono
   que se queda días sin abrirse.
3. **No hacer nada** y asumir la consistencia eventual, que es lo que hay hoy.
   Defendible si el uso real es «abro la app, apunto y me quedo un rato», pero
   entonces conviene decirlo en el ticket y cerrarlo, no dejarlo implícito.

Antes de elegir, medir cuánto tarda de verdad el caso real: si el patrón de uso
es apuntar el gasto y salir de la app en menos de 60 s, la opción 1 cambia el
comportamiento del 100 % de los casos y no de una minoría.

## Cuidado con

- **No metas un warm-up ni un ciclo extra "por si acaso" sin medir.** Ya pasó
  con `AppAttestClient.ensureRegistered`, que prometía calentar el token y
  nunca tuvo un solo call-site: costó una vuelta entera de diagnóstico porque
  alguien lo usó como punto de observación. Ver `.claude/rules/gateway-attest.md`.
- Un ciclo que falla **gasta la escalera de backoff**, y el toque real que
  llegue después se encuentra la ventana consumida. Mismo argumento que allí.
- La observación de este subsistema son los breadcrumbs de
  `GroupsSyncBreadcrumb` (`logger.notice`, **fuera de `#if DEBUG` a propósito**,
  emiten en TestFlight). Se leen con Console.app sobre el iPhone conectado
  filtrando `GroupsSync`; `log stream --device` ya no existe en macOS 26+.

## Contexto

Salió de la matriz de dos dispositivos del 2026-08-02, la que verificó que el
canal de Grupos por backend mueve datos en producción. Ver
[[MODO-NUBE-DECISION-RELEASE-2.1]] §D-R1 y [[MODO-NUBE-ROLLBACK]] §1, donde
consta como abierto y no bloqueante.

No confundir con el chip `task_736f2831` (transacciones fantasma al borrar un
gasto de grupo), que es otro defecto de la misma sesión.

migrated from YalaWiki Backlog/groups-emisor-segundo-plano-no-sube.md @ 1934e8ad

## Owner check 2026-08-28 (Jurgen, Lima, TF 2.1 build 12) — QA device PASS

- Dos teléfonos en el mismo grupo, binario de campo **TF 2.1 build 12**.
- Teléfono A (emisor): crea un gasto de grupo y se va al **Home de iOS**. **Sin force-quit**.
- Teléfono B (receptor): en el feed. A **no se vuelve a abrir**.
- El gasto apareció en B en **~30 s**. Veredicto del owner: **PASS**.
- Es el caso dominante que abrió el ticket —apunto el gasto y guardo el teléfono—, el que antes se
  quedaba en silencio indefinido hasta que el emisor reabría Yala.

⇒ **Cerrado por QA device**: el PASS drena el «QA device pendiente» del estado del 2026-08-18.

**Este cierre es QA, no un fix nuevo.** El código ya estaba en el árbol de `2.1` vía
[PR 19](https://github.com/jur211296/Yala/pull/19) (merge `b9526c8e`, head `c1577137`) y aquí no se toca
Swift. Medido hoy en este árbol, lo implementado es la **opción 1**: `GroupsSaveSyncTrigger.swift:72`
pide el `beginBackgroundTask` y `:83` duerme `SyncCadencePolicy.pushDebounce` antes de pedir UN ciclo,
colgado del save local por `GroupExpenseService.swift:29-32` — el seam que este ticket declaraba
huérfano ya tiene consumidor.

**Lo que este PASS no dice.** Hoy **no hubo subida a TestFlight**: el PASS es sobre el build 12 que ya
estaba en campo, no sobre ningún build posterior. Los ~30 s son **una** medición del caso dominante, no
una distribución ni un techo garantizado — el tiempo de fondo lo concede iOS. Y la **opción 2**
(`BGAppRefreshTask` para el teléfono que se queda días sin abrirse) sigue sin implementar; medido hoy,
ningún ticket de `tickets/` la cubre y este cierre no abre uno.
