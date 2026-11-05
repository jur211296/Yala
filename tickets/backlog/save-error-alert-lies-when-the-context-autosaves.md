---
id: save-error-alert-lies-when-the-context-autosaves
status: backlog
priority: low
area: "accounts, swiftdata"
created: 2026-09-09
updated: 2026-10-08
source: review adversarial de changing-an-account-currency-orphans-its-whole-history (2026-09-09)
---

# «No se pudo guardar» aparece después de que los cambios ya estén en el contexto compartido

## Qué le pasa al usuario

Guarda una cuenta, el guardado falla y sale «No se pudo guardar». Pulsa Entendido y cierra. Pero el
Panel, Registros y los widgets ya enseñan los cambios: se le dijo que no se guardó nada y se guardó
todo.

## Lo medido (2026-09-09)

`Yala/App/ViewModels/Accounts/AccountFormViewModel.saveAccount`: si `try context.save()` lanza, se
enciende `isShowingSaveError` y se devuelve `false`, **sin `context.rollback()`**. Es el
`mainContext` compartido —no hay ningún `autosaveEnabled = false` en el árbol— así que las
mutaciones ya hechas se persisten en el siguiente turno del runloop, y los `@Query` de las demás
pantallas cuelgan de ese mismo contexto.

Precedentes de rollback en el repo: `Yala/Services/CloudSync/SyncApplyEngine.swift:199`,
`Yala/App/Services/CategoryDeduplicationService.swift:403,433`.

**Es preexistente** —la forma es la misma desde que existe el formulario— pero desde
`changing-an-account-currency-orphans-its-whole-history` un guardado fallido puede dejar además el
histórico entero de una cuenta ya reexpresado, así que el mensaje engaña sobre mucho más.

Segundo efecto medido en la misma zona: tras un fallo, `allTransactions` conserva modelos que
`InitialBalanceService.setInitialBalance` ya borró del contexto (`:105-107`), y el array no se
recarga. También preexistente.

## Criterio de hecho (AC)

- [ ] Decidido qué hace el formulario cuando `save()` lanza: revertir, reintentar, o cambiar el
      mensaje para que no prometa una atomicidad que no hay. (Ojo: `rollback()` sobre el
      `mainContext` descarta también lo que hayan escrito otras pantallas.)
- [ ] Test que fije la decisión.

## Relacionados

- `changing-an-account-currency-orphans-its-whole-history` — de donde sale la medición.

## Medido en 2.1 (triage 2026-10-08)

- `AccountFormViewModel.saveAccount` (`AccountFormViewModel.swift:569`): el `catch` de `:635-642` enciende
  `isShowingSaveError` y devuelve `false`, sin `rollback()`. Sigue habiendo cero `autosaveEnabled = false`.
- `low`: el `save()` del formulario rara vez lanza, y no se pierde nada; el defecto es un mensaje falso.

Triage 2026-10-08: abierto · medium → low · saveAccount sigue encendiendo isShowingSaveError sin rollback sobre el mainContext compartido; los commits posteriores (93d2cdc41, b8a371f9d, 4ec6f0c5e) no tocaron esa rama.

## Medido (2026-11-05, lote P5 de la 2.3): `rollback()` aquí TUMBA la app

Se probó el arreglo obvio —`context.rollback()` en el `catch` del `save()` y recargar lo cargado— con un seam que hace
fallar el guardado (`persistChanges`) y tests contra el store. **Dos de los cuatro casos tumbaron el proceso**
(`SIGABRT`, `swift_dynamicCast` dentro de SwiftData, desde `context.rollback()` en `saveAccount`): los que editan la
cuenta y cambian su saldo inicial. Aislado con sondas, una por proceso (iPhone 17 Pro, iOS 27.2):

| Pendiente antes del `rollback()` | Resultado |
|---|---|
| borrar un movimiento guardado | ok |
| insertar un movimiento enlazado a la cuenta | ok |
| `setInitialBalance` (borra el saldo inicial viejo e inserta otro), con o sin la subcategoría «Ajustes de saldo» nueva | ok |
| un campo de la cuenta cambiado DESPUÉS de `setInitialBalance` | ok |
| un campo de la cuenta cambiado + insertar, sin borrar | ok |
| un campo de la cuenta cambiado + borrar, sin insertar | ok |
| **un campo de la cuenta cambiado ANTES de `setInitialBalance`** (cualquiera de los cuatro probados) | **aborta** |
| lo mismo con un store EN DISCO (no en memoria) | **aborta** |

`saveAccount` hace exactamente eso: `applyBaseAccountProperties` y luego el saldo inicial. ⇒ **el «revertir» con
`rollback()` no es viable tal cual**: cambiaría un mensaje falso por un cierre de la app. Decisión pendiente (pregunta al
bot del 2026-11-05).
