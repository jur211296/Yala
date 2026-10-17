# Borrados y movimientos sin cuenta: dar salida a los huérfanos, cerrar el hueco de los que llegan tarde y borrar en D1 lo que queda al eliminar una cuenta

## Contexto
Sesión AGRUPADA de 2.1 que cubre tres cards del tablero (léelas enteras con `tablero ver <id>` y sus tickets antes de empezar):

a) «Los movimientos que quedaron sin cuenta por borrados anteriores siguen invisibles» — card tablero-los-movimientos-que-quedaron-sin-cuenta-sovw, prioridad alta. Ticket tickets/backlog/records-orphaned-by-earlier-account-deletions-stay-invisible.md. Antes del arreglo de PR #512, eliminar una cuenta dejaba sus movimientos sin cuenta (`Account.transactions` es `.nullify`). #512 impide que pase más pero no repara lo ya pasado: medido en simulador (seed `cuenta-con-movimientos`) el Panel pasa de S/ 942 a S/ 1.000, «Gastos» S/ 0,00, Estadísticas › Registros lista las filas sin nombre de cuenta; en el iPhone de QA de Jürgen siguen Taxi 25 y Teléfono 33 de «Efectivo QA».
   DECISIÓN YA TOMADA (Jürgen, 2026-10-15 17:04, no reabrir): avisar que hay movimientos huérfanos de borrados antiguos y dejar elegir a qué cuenta moverlos.

b) «Eliminar una cuenta todavía puede dejar sin cuenta movimientos que llegan después» — card tablero-eliminar-una-cuenta-todavia-puede-dejar-mjzx, prioridad media. Ticket tickets/backlog/account-deletion-can-still-orphan-records-that-arrive-later.md. `AccountRemovalService.inventory` solo lee el store local: (1) importación de iCloud a medias (la cuenta llegó, sus movimientos no) → se elimina sin preguntar y los que llegan quedan huérfanos; (2) otro dispositivo escribe a la vez. Esperar a `hasCompletedFirstImport` puede no abrirse nunca (`ICloudRestoreInProgressLogic`, «es una ventana, no un interruptor»), así que no bloquear el borrado ahí. El propio ticket dice que el arreglo natural va con (a): dar salida a los movimientos sin cuenta vengan de donde vengan (el aviso de (a) debe detectar también los que lleguen tarde, no solo un barrido único de los antiguos).

c) «Al eliminar una cuenta no se borran la clave de App Attest ni el contador de uso en D1» — card tablero-al-eliminar-una-cuenta-no-se-borran-la-c-3sge, prioridad alta. Sin ticket propio: salió en el cierre del PR #469 (textos legales 2.1). «Eliminar mi cuenta» (Modo Nube, `Yala/Services/CloudSync/AccountDeletionService.swift`) borra los datos de la cuenta pero en el gateway (Cloudflare D1, `gateway/`, ver `gateway/migrations/0001_init.sql`) quedan la clave de App Attest y el contador de uso. La política de privacidad promete el borrado. Hecha cuando: tras eliminar una cuenta no queda en D1 la clave de App Attest ni el contador ligados a ella (o la política dice qué se conserva y por qué), con PR mergeado a 2.1. Crea el ticket que falta en tickets/.

Antecedente: hay capturas de la sesión previa (la de PR #512, «eliminar cuenta: mover o borrar movimientos») en ~/Claude/worktrees/_capturas/2026-10-15-eliminar-cuenta-mover-o-borrar-movimientos/ (antes-1/2, despues-1/2/3). Míralas: muestran el diálogo mover/borrar ya existente y el estado huérfano; reutiliza su lenguaje visual y no dupliques lo que #512 ya hizo.

## Qué se pide
1. (a) Aviso de movimientos sin cuenta + elegir cuenta destino y moverlos (con conteo y efecto en saldos/Gastos/Registros correctos tras moverlos). Copy en español, coherente con el diálogo de #512.
2. (b) Cerrar el hueco de los que llegan tarde apoyándose en (a) (detección continua, no solo migración única), sin bloquear el borrado esperando la importación. Si queda algún caso residual, ticket + card.
3. (c) En gateway/: medir con tests qué filas de D1 quedan tras el borrado de cuenta y borrarlas (o justificar retención con tests y ajustar la política). Si hay que tocar D1 remoto: SOLO staging; prod queda documentado en el RUNBOOK del gateway, salvo que sea un deploy de código normal ya previsto.
4. Puede ser un PR o uno por card si conviene, pero todo en esta sola sesión. Rama base origin/2.1: `git fetch` + rebase sobre origin/2.1 antes de abrir CADA PR, sin esperar el CI del PR anterior (#518 puede estar aún en cola de merge; no dependes de él).
5. Pipeline serial de simulador: limpiar simuladores muertos/iniciados, `xcodebuild -jobs 2` sin ningún simulador iniciado, iniciar UN simulador, probar, apagarlo y borrarlo; al final quedan solo «iPhone 17 Pro» y «iPad Pro 11-inch (M5)» apagados.
6. Pruébalo sola al máximo: unit tests, XCUITest donde aplique, y capturas antes/después según /barrido-qa (guárdalas en ~/Claude/worktrees/_capturas/2026-10-15-borrados-movimientos-sin-cuenta/).
7. Tablero: las tres cards ya están en «in progress» (frank). Al cerrar: done con evidencia (PR + capturas/tests) cada una; solo lo que sí o sí pide un iPhone real (p. ej. reparar Taxi 25 / Teléfono 33 en el iPhone de QA, importación real de iCloud o dos dispositivos) queda para Jürgen: la card de (a) a «in qa» asignada a jurgen con guion corto. Todo ticket nuevo con card en el tablero (1:1, o una card que lo cubra y cuyo cierre lo cierre).
8. CIERRA SOLA con /cerrar-total sin esperar a Jürgen (no requiere validación urgente).

## Qué NO hay que tocar
- Nada de tmux `salud--…` ni `sat-lab--…`, ni clinicas-dentales-bi ni salud.
- D1/Supabase de producción: no se escribe a mano (solo staging; prod documentado en RUNBOOK).
- No escribirle a nadie.
- No reabrir la decisión de Jürgen en (a). No rehacer el diálogo mover/borrar de #512.

## Cómo se sabe que está bien
- Con datos huérfanos sembrados, la app avisa con su cifra, permite elegir cuenta, y tras moverlos el Panel/Gastos/Registros cuadran (XCUITest + capturas antes/después).
- Un movimiento que llega después de eliminar su cuenta también aparece en ese aviso (test).
- Tests del gateway demuestran que tras eliminar la cuenta no quedan la clave de App Attest ni el contador ligados (o retención justificada + política ajustada).
- PR(s) a 2.1 con auto-merge, cards cerradas o en qa con guion, simuladores limpios, worktree cerrado con /cerrar-total.

## Paso 0 (Frank, 2026-10-15, auto-contestado: modo autónomo)

Medido antes de decidir:
- Nadie crea a propósito un movimiento sin cuenta: solo sale del `.nullify` al borrar una cuenta (builds anteriores a #512) o de un movimiento que llega después. Panel (saldo, «Gastos») y el resumen de Registros los excluyen; la lista de Registros los enseña sin cuenta.
- Gateway: `attest_keys` de D1 va por keyId del DISPOSITIVO, sin columna de cuenta; el vínculo cuenta↔clave vivía en `attest_keys` de Supabase y ya lo borra `delete_personal_account`. La app no llama a `/attest/bind`. El único contador ligado a la cuenta es el Durable Object `sub:<sub>` (lo usa `requireUser` en producción); el del dispositivo (keyId) guarda el cupo de prueba de la IA, que no se repone nunca.

Decisiones:
1. Dos PR: (a)+(b) app iOS; (c) gateway + política web. Independientes, lentes distintas.
2. (a) Dónde avisar: aviso en el Panel (pila de avisos), que abre una hoja «Movimientos sin cuenta» con la cifra, la lista y «Mover a» (mismo lenguaje visual que la hoja de #512). Solo mover: es la decisión de Jürgen.
3. Qué es «sin cuenta»: `account == nil` y SIN puntero de grupo. Una fila de grupo sin cuenta es ambigua (pata virtual con su cuenta de sistema aún sin hidratar) y el puente la gobierna: fuera, con ticket residual.
4. (b) Detección continua: el Panel recuenta en cada recarga (cubre lo que llega tarde por sync). El aviso solo sale con el import quieto (`SyncQuiescenceCoordinator.isImportQuiescent`), para no avisar de filas a medio hidratar en una restauración. No se bloquea el borrado de cuentas.
5. Mover: reglas de #512 (`AccountRemovalLogic.moveVerdict` por divisa; convierte con el tipo de cambio de su fecha; quita las dos patas de una transferencia cuya otra pata ya está en el destino; un saldo inicial pasa a ajuste). Solo se mueven las filas que la persona vio y siguen sin cuenta.
6. (c) Al eliminar la cuenta se borra el contador de la cuenta (`sub:<sub>`). La clave de App Attest y su contador se conservan: son del dispositivo, no llevan nada de la cuenta y el contador guarda el cupo de prueba (borrarlo lo repondría con cada alta y baja). La política lo dice (6 idiomas). Sin migración D1; el despliegue del Worker queda en `gateway/RUNBOOK.md`.
