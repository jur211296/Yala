# Al eliminar una cuenta con movimientos, preguntar si moverlos a otra cuenta o borrarlos (nunca dejarlos sin cuenta en silencio)

## Contexto
Card del kanban: tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst (Yala, versión 2.1, prioridad alta).

Visto en el QA guiado del 15-oct (iPhone de QA, Yala Dev): Jürgen eliminó la cuenta «Efectivo QA» que tenía dos gastos (Taxi 25, Teléfono 33). Los dos siguen en Registros sin cuenta asignada y nada lo indica. Medido en el código: `Account.transactions` es `deleteRule: .nullify` (ver `Yala/Models/TransactionItem.swift`) y `AccountFormViewModel.deleteAccount` (`Yala/App/ViewModels/Accounts/AccountFormViewModel.swift`) hace `context.delete` sin preguntar qué hacer con los movimientos. No lo causó la vuelta a iCloud: pasa al borrar. Además el texto `account.deleteBalanceError` («no puedes eliminar con saldo distinto de cero») existe en los Localizable pero ningún código lo usa.

Decisión de Jürgen (2026-10-15, opción A): al eliminar una cuenta que tiene movimientos, la app pregunta qué hacer con ellos:
- Moverlos a otra cuenta (opción principal, la recomendada).
- Borrarlos también (destructiva, con confirmación clara de cuántos movimientos se borran).
Si la cuenta no tiene movimientos, se elimina como hoy.

## Que se pide
1. Antes de eliminar, contar los movimientos de la cuenta y, si hay, ofrecer las dos opciones de la decisión A. Al mover: elegir la cuenta destino entre las demás cuentas del usuario; si la divisa de destino es distinta, respetar las reglas de divisa del repo (`.claude/rules/currency-fx.md`) y no dejar conversiones sin recalcular. Si no hay otra cuenta a la que mover, decirlo y dejar solo borrar o cancelar.
2. Revisar lo que también apunta a la cuenta y quedaría huérfano igual: transferencias (la otra pata), pagos programados, favoritos y cualquier otra relación a `Account`. Ninguno debe quedar apuntando a nada sin que el usuario lo sepa. Respetar `.claude/rules/swiftdata-cloudkit.md` y la sincronización (modo nube y grupos): el cambio de cuenta de los movimientos y el borrado deben sincronizar bien entre dispositivos.
3. Decidir qué hacer con `account.deleteBalanceError`: usarlo si encaja con la decisión A o retirarlo de los Localizable si ya no aplica. Textos nuevos en todos los idiomas del proyecto, español neutro en es-419.
4. Tests unitarios de la lógica (mover, borrar, sin movimientos, sin otra cuenta, divisa distinta) con un mutante comprobado en rojo, y un UITest del flujo de eliminar con movimientos. Review adversarial del cambio, porque toca persistencia de datos financieros.
5. Capturas de antes y después del diálogo de eliminar en `capturas/` del worktree (`antes.png`, `despues.png`) y listadas en el resumen.

Simulador: se usa a cualquier hora, siempre uno a la vez. Nunca dos simuladores a la vez.

Pipeline serial de la Mini (sin paralelizar pasos que pelean por CPU/RAM):
1. Limpiar (sims muertos, basura previa, DerivedData de sesiones ya cerradas, cachés de XcodeBuildMCP de worktrees que ya no existen). Sin preguntar.
2. Build con `nice -n 10 xcodebuild -jobs 2` sin simulador booteado.
3. Bootear 1 simulador.
4. Tests.
5. Apagar y limpiar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests: no compilar con un sim ya booteado, no correr tests mientras compila, no dejar el sim vivo al terminar.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión (la carpeta de build de su worktree) y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques el DerivedData ni las cachés de un worktree que sigue vivo. Si el borrado falla, dilo en el cierre.

Gate después del CI del PR anterior: la sesión arranca ya sobre origin/2.1. Justo antes del gate, mira si el PR anterior a 2.1 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

Cierre: PR contra la rama 2.1 (no 2.2). Justo antes de abrirlo, `git fetch origin` y `git rebase origin/2.1`; resuelve conflictos si los hay y vuelve a pasar los tests afectados. Al cerrar, Mini limpia: simulador apagado y borrado de datos, sin DerivedData de esta sesión. Mueve la card tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst según el resultado (con firma --agente frank).

## Que NO hay que tocar
- La sesión tmux `Yala--qa-guiado-2-1` ni el worktree `encargo/2026-10-14-qa-guiado-2-1` (QA en curso de Jürgen), ni sus simuladores.
- La rama 2.2 ni los PR de la auditoría UX 2.2.
- Nada de marketing/ ni de salud/clínicas.
- Sin deploy ni cambios de esquema de CloudKit en producción.

## Como se sabe que esta bien
Eliminar una cuenta con movimientos nunca deja movimientos sin cuenta sin que el usuario lo sepa y pueda resolverlo: la app pregunta, mover deja los movimientos en la cuenta elegida con saldos y conversiones correctas, borrar los elimina tras confirmar, y nada (transferencias, pagos programados, favoritos) queda apuntando a una cuenta inexistente. Tests unitarios y UITest en verde, mutante en rojo comprobado, capturas antes/después, PR abierto contra 2.1 tras fetch + rebase.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cuándo pregunta la app?** → Cuando la cuenta tiene movimientos **o** pagos programados, favoritos o borradores pendientes. Sin nada de eso, se elimina como hoy (sin preguntar).
Por qué: el punto 2 pide que nada quede apuntando a una cuenta inexistente sin que el usuario lo sepa, y un programado sin movimientos también quedaba huérfano en silencio. Alternativa descartada: preguntar solo con movimientos (dejaba el alquiler programado sin cuenta sin decirlo).

**D2 · Forma del diálogo** → Una sola hoja con fases (elegir → confirmar → trabajando/error), no alerts encadenados.
Por qué: `swiftui-ds.md` — dos `.alert` del mismo anchor pueden brickear el router; las fases dan sitio al «trabajando» de la conversión y al error. Alternativa descartada: `confirmationDialog` (en iOS 26 no pinta Cancelar anclado a un botón).

**D3 · Mover con otra divisa** → Se reusa la conversión del cambio de divisa de cuenta (`AccountCurrencyMigrationService`): movimientos y borradores pendientes a la tasa de su fecha, programados y favoritos a la de hoy, tasas traídas ANTES de tocar importes; si no llegan, no se mueve nada y se dice.
Por qué: es la regla ya decidida por Jürgen para el mismo dinero (opción 2A, 2026-10-08) y la columna `amount` no tiene reparador. Alternativa descartada: cambiar solo la etiqueta de divisa (es el bug de `bulkUpdateAccount`, ver Encontrado).

**D4 · Lo que no se puede convertir** → Una cuenta destino en otra divisa queda **deshabilitada con su motivo** si algún movimiento que habría que convertir es transferencia, gasto de grupo o liquidación, o hay programados/borradores de grupo. Las cuentas en la misma divisa siguen disponibles.
Por qué: `AccountCurrencyChangeLogic` ya mide que esas conversiones no se sostienen (el puente las pisa o las borra).

**D5 · Borrar con movimientos de grupo** → «Borrarlos» se deshabilita si algún movimiento tiene puntero de grupo (`splitExpenseID`/`splitSettlementID`); queda mover o cancelar.
Por qué: `RecordContextActionLogic` — borrar uno vivo lo resucita el siguiente sync como borrador; el editor tampoco deja.

**D6 · Transferencias al BORRAR** → La pata de esta cuenta se borra; la otra pata, en otra cuenta, se queda como movimiento normal (se le quita `transferPairID` y el tipo transferencia), y la confirmación lo dice.
Por qué: el saldo de la otra cuenta no cambia por borrar esta en la app; es la misma reparación que hace `TransferPairReconcileService` (caso 2) con una pareja ausente, así que no deja estado nuevo. Alternativa descartada: borrar las dos patas como Registros (descuadraría la otra cuenta) o dejar la pata colgada (el reconciliador intentaría emparejarla por heurística).

**D7 · Transferencias al MOVER** → Una transferencia con la otra pata en otra cuenta pasa a salir de la cuenta destino. Si la otra pata está **en la propia cuenta destino**, las dos patas se quitan (dentro de una cuenta no mueven dinero; el saldo resultante es idéntico) y la confirmación lo cuenta.
Por qué: una transferencia «de D a D» no tiene representación en el editor. Alternativa descartada: dejarla de D a D.

**D8 · Programados, favoritos y borradores al BORRAR** → Se quedan, sin cuenta, y la confirmación lo dice: la cuenta se elige al registrarlos (el borrador ya exige cuenta para aprobar). Los borradores aprobados/rechazados no se tocan (son historia del Inbox con su nombre de cuenta en caché).
Por qué: no destruir lo que el usuario no eligió borrar; el modelo ya admite cuenta nula en los tres.

**D9 · Destinos posibles** → Las demás cuentas del usuario no archivadas y no de sistema (las de Grupos no se eligen a mano).

**D10 · `account.deleteBalanceError`** → Se retira de los 16 Localizable y de `L10n.swift`.
Por qué: con la decisión A el saldo nunca impide eliminar (mover lo conserva; borrar lo decide el usuario). Alternativa descartada: usarlo — contradiría la decisión A.

**D11 · Fallo al guardar** → Todo va en un único `save()` (movimientos, borrados y la cuenta); si falla, `rollback()` y la hoja dice «No se eliminó la cuenta». *Cambiado tras la review*: sin deshacerlo, el autoguardado consolidaba lo hecho mientras la hoja decía lo contrario (lo cazaron las tres lentes).

**D12 · Presupuestos** → *Cambiado tras la review.* Al MOVER, los presupuestos que miraban la cuenta pasan a mirar la cuenta destino (M2M y espejo CSV juntos), y la hoja lo dice. Al BORRAR, un presupuesto que solo miraba esta cuenta queda sin filtro de cuentas (= todas): la hoja lo avisa, y eso basta para que pregunte aunque la cuenta no tenga nada más. Por qué: quitar la cuenta sin más cambiaba en silencio lo que el presupuesto cuenta (de una cuenta a todas), que es peor que la alternativa descartada.

**D13 · Lo que se borra es lo que se confirmó** → «Borrar» solo sigue si los movimientos de la cuenta son exactamente los que la hoja enseñó; si llegó otro por sync mientras tanto, no borra nada y lo dice.

**D14 · Saldo inicial al mover** → El saldo inicial de la cuenta que se va entra en el destino como **ajuste**: el modelo da por hecho un saldo inicial por cuenta.

**D15 · Filas que ya venían desemparejadas** → Una transferencia o movimiento de grupo estampado en otra divisa que su cuenta (histórico anterior al bloqueo) se mueve **sin convertir**: queda igual de desemparejado que estaba. Solo bloquea si es la mudanza la que lo desemparejaría.

**D16 · Parejas de transferencia** → Se reconocen con el id normalizado (mayúsculas, sin espacios) y solo si son de dos filas exactas; con tres o más (colisión) no se tocan, como `TransferPairReconcileService`. Con divisas distintas, quitar las dos patas (D7) deja el saldo igual salvo la diferencia de cambio de esa transferencia.

**Residual aceptado (ticket `account-deletion-can-still-orphan-records-that-arrive-later`)** → La comprobación ve lo que ya está en el teléfono. Si la cuenta se elimina con la importación de iCloud a medias, o si otro dispositivo apunta un movimiento en ella antes de recibir el borrado, ese movimiento llega sin cuenta. Cerrarlo pide esperar a una importación asentada que en algunos casos no llega nunca.
