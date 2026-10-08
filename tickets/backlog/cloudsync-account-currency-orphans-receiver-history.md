---
id: cloudsync-account-currency-orphans-receiver-history
status: backlog
priority: medium
area: "cloudsync, accounts, currency, fx"
created: 2026-09-09
updated: 2026-10-07
source: AC nº4 de changing-an-account-currency-orphans-its-whole-history (2026-09-09)
---

# Cambiar la divisa de una cuenta en un teléfono desempareja el histórico del otro

## Qué le pasa al usuario

Tiene la app en dos teléfonos con Modo Nube. En el primero cambia la divisa de una cuenta y acepta
convertir su histórico: ahí todo queda coherente. En el segundo llega el cambio de la **cuenta**,
pero sus transacciones locales no se tocan hasta que lleguen las filas convertidas — y si no llegan,
o llegan a medias, el segundo teléfono se queda con una cuenta en dólares llena de movimientos en
soles. El mismo desemparejamiento que el formulario ya no permite crear a mano.

## Lo medido (2026-09-09)

`Yala/Services/CloudSync/EntityApplyMap.swift`, bloque `table: "accounts"`:

```swift
"currency_code": Apply.stringReq(\.currencyCode),
```

Es un applier por columna: escribe la divisa que trae el cable y no mira nada más. El receptor no
tiene ninguna noción de «esta cuenta acaba de cambiar de divisa, mira sus transacciones».

**Corrección de una premisa que circulaba en dos tickets.** El ticket de origen apuntaba a
`EntityApplyMap.swift:158`, que es el applier de **`tx_items`**, e infería que el daño venía de
escribir `currency_code` sin contrastar con el `account_ref` de unas líneas más abajo. Medido: ahí
la divisa del cable viene coherente desde el emisor, así que esa rama no crea nada. La que propaga
el daño es la de **`accounts`**, y no hace falta que las transacciones «lleguen del otro device»:
basta con que la cuenta cambie debajo, exactamente igual que pasaba en local.

Dato relacionado y contraintuitivo, ya medido antes: cambiar `currencyCode` **no emite un grupo
`money` parcial** — no emite el grupo en absoluto. Ni `currency_code` ni `account_ref` pertenecen a
grupo alguno en `EntityEmissionMap`, así que el guard `coherenceGroupPartial` ni llega a evaluarse.
Importa al diagnosticar: invita a buscar el fallo en un guard que nunca corrió.

## Segunda mitad, medida el 2026-09-09: no hay atomicidad cross-entidad

El histórico convertido y el `accounts.currency_code` viajan como **N+1 deltas independientes**, con
`syncID` y HLC propios y sin ninguna relación de coherencia entre ellos. `SyncPushClient.swift:160`,
`:176`, `:269` sube en **chunks de 50 con progreso incremental** (`:236-241`), y el outbox se drena
por `createdAt` (`CloudSyncEngine.swift:2510`) —el orden del changeset del History—, no con la cuenta
primero ni con la cuenta al final.

⇒ Una cuenta con 300 movimientos sube en varios chunks. Si la red se corta antes del que lleva
`accounts`, el otro teléfono ve 250 filas en la divisa nueva dentro de una cuenta que sigue diciendo
la vieja, y `AccountBalanceCalculator` las suma en crudo rotulando con la de la cuenta. No hay
marcador de operación ni reconciler que cierre la brecha.

**Lo que SÍ está cubierto, para no volver a medirlo:** el grupo `money` viaja completo. `amount`
tiene grupo (`EntityEmissionMap.swift:179`), `DeltaEmitter` expande el grupo entero y el guard
`coherenceGroupPartial` no se dispara. `tx_items.currency_code` sigue sin pertenecer a ningún grupo
—ni en el cliente ni en el manifiesto del servidor— y viaja como unidad singleton con el mismo HLC,
así que dentro de una fila el desemparejamiento solo sale con otra escritura concurrente. Ojo a la
asimetría: `budgets.currency_code` **sí** está en su grupo.

## Por qué es medium y no high

El daño necesita dos dispositivos y una ventana de sync. Y desde
`changing-an-account-currency-orphans-its-whole-history` el emisor ya convierte su histórico, así
que lo que viaja es un estado coherente: lo que falta es que el receptor no pueda quedarse en el
intermedio. Un cliente en una versión anterior de la app sí puede seguir emitiendo el cambio de
cuenta sin convertir nada, y ése es el caso que hay que acotar.

## Criterio de hecho (AC)

- [ ] Decidido qué hace el receptor cuando la divisa de una cuenta cambia y sus transacciones
      locales no coinciden: esperar, reexpresar, o marcar la cuenta hasta que cuadre.
- [ ] Medido si el orden de llegada (`accounts` antes que `tx_items`, o al revés) puede dejar una
      ventana visible, y cuánto dura.
- [ ] Test que fije la decisión con un receptor que tiene histórico propio.

## Relacionados

- `changing-an-account-currency-orphans-its-whole-history` — el lado local, ya cerrado.
- `saving-a-mismatched-transaction-relabels-it-without-converting` — qué hace Guardar sobre una fila
  ya desemparejada, que es como se vería este caso desde la UI del receptor.

## Decisión de Jürgen (2026-10-07)

Opción 2A, la misma en los tres tickets de moneda: **antes de cambiar la moneda de una cuenta, Yala avisa y muestra qué se
va a convertir; los pagos programados y los favoritos se convierten a la tasa de hoy; el historial no se toca.**

Los tres tickets que la comparten:
- `account-currency-change-leaves-scheduled-and-favorites-stale`
- `saving-a-mismatched-transaction-relabels-it-without-converting`
- `cloudsync-account-currency-orphans-receiver-history`

A qué parte corresponde: este ticket no tiene opciones con nombre; su primer AC pide decidir qué hace **el receptor**
cuando la divisa de una cuenta cambia y sus transacciones locales no coinciden (esperar, reexpresar o marcar). La parte
que le toca es **«el historial no se toca»**: el receptor no re-expresa por su cuenta el histórico local. Lectura de esta
sesión, por confirmar antes de implementar. Los pagos programados y favoritos que el emisor convierta viajan como filas
convertidas. Siguen abiertos los AC 2 y 3 (medir la ventana por orden de llegada y el test con receptor con histórico).
