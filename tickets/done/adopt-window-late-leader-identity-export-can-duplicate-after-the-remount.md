---
id: adopt-window-late-leader-identity-export-can-duplicate-after-the-remount
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-25
source: "ticket `displaced-leader-late-identity-export-can-rekey-the-relief-corpus` (2026-09-24), residual del Paso 0"
---

# En el adopt, lo que un líder desplazado exporta tarde también puede duplicar

## El problema, en lenguaje de usuario

Tu segundo teléfono entra en la cuenta de la nube que otro teléfono terminó de activar. Mientras lo hace, un tercer
teléfono que se había quedado sin red vuelve y manda a iCloud sus datos viejos. El segundo podría acabar con algunos
movimientos dos veces.

## Lo medido y lo inferido (2026-09-24)

- **Medido**: la ida ya lo cierra (`MigrationWorkExecutor.restoreRelayIdentities`). El adopt no pasa por ahí: su espejo
  sigue vivo desde el reconcile de huérfanas hasta el remonte, y el pull del runtime tras el remonte crearía un
  born-remote con la copia del backend si la identidad cambió en medio.
- **Inferido**: el adopt no captura las coordenadas de CloudKit de sus testigos (solo `assignIdentity` lo hace), así que
  el mismo mecanismo no le serviría tal cual. El linaje de #242 solo mira antes de subir.
- **Sin medir**: qué valor gana CloudKit (el mismo punto que el ticket de origen; lo mide `cloudRelayIdentityRestored`).

## Criterios de aceptación

- [x] Medido si la ventana del adopt es alcanzable en la práctica y, si lo es, que no duplique.

## Resolución (2026-09-25)

**La ventana es alcanzable si CloudKit le da la razón al líder desplazado, y no era la única.** Qué gana CloudKit sigue sin
medir (dos teléfonos y un corte de red); se diseñó para el peor caso, como en #243, y el canario `cloudRelayIdentityRestored`
lo mide en la flota.

- **Medido, con tests que fallaban sin el arreglo:**
  - **del reconcile al remonte** (la ventana del ticket): el runtime arrancaba tras el remonte, el drain subía la edición
    bajo la identidad nueva y el pull creaba un born-remote con la copia del backend: la categoría dos veces;
  - **antes del reconcile** (más ancha: del remonte del relevo al adopt pueden pasar días): con el marcador del líder,
    `adoptLineageGate` salía en `adoptLineageProven` sin casar nada y la fila re-identificada subía como huérfana. El
    duplicado quedaba en el backend, para todos los teléfonos. Le pasa también al líder desplazado cuando entra en la
    cuenta: la regla decía que el linaje del adopt le re-identificaba sus filas, y con el marcador no lo hacía.
- **Arreglo:**
  - el adopt siembra `RelayIdentityLedger` con sus identidades definitivas, captura las coordenadas de sus testigos y
    deja una marca (`pinAdoptedIdentities`). El runtime, al arrancar tras el remonte y antes de su primer drain, devuelve
    por `Z_PK` las identidades que el espejo cambió (`CloudSyncEngine.restoreAdoptedRelayIdentitiesIfPinned`) y marca el
    registro para retirarlo. Los borrados de la ventana los traduce el drain de #244 sin cambios;
  - en un reintento del adopt, la misma restauración al empezar el reconcile, solo hacia identidades que el backend
    conoce o que ya esperan en el outbox: en el líder desplazado, la restauración por coordenadas de la ida le pondría
    la suya;
  - con el marcador, las filas sin identidad del backend casan por clave de linaje única con las que faltan
    (`rebindRekeyedRows`). Lo que no casa NO bloquea: el líder desplazado trae también filas que creó sin red y que
    tienen que subir.
- **Regla**: «Y en el ADOPT tampoco: el marcador prueba el linaje, no las identidades» en
  `.claude/rules/swiftdata-cloudkit.md`, y corregido el punto (1) de la regla de #243.
- **Review adversarial** (tres lentes sobre un parche de las copias limpias, con el árbol mutado): sin regresión del
  adopt legítimo ni camino que ponga a una fila la identidad de otra. Corregidos: el outbox en la restauración del
  reintento, las filas sin identidad en el casado (el resultado dependía de si el push había fallado) y un test cuyos
  negativos tapaba el filtro.
- **Pruebas**: 11 tests nuevos (10 en `MigrationWorkExecutorTests`, 1 en `CloudSyncRuntimeTests`), el del ticket con su
  control (sin la restauración, la misma categoría dos veces). 17 mutantes muertos: sin restaurar al arrancar, sin sembrar,
  sin casar con marcador, cada condición de la restauración por el registro, sin `onlyTo`, sin el outbox en `onlyTo`, sin
  capturar coordenadas, sin las tablas sin identidad y el ciclo de vida de la marca. Gate: 7899 unit en 754 suites.
- **Residual, con ticket**: las filas re-identificadas que no casan por clave única (categorías del usuario, movimientos
  con el `createdAt` de la migración ligera, tipos de cambio, gemela borrada en el backend) siguen subiendo duplicadas
  (`adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate`).
- **Sin device-QA**: se prueba entero en unit; lo que queda del dispositivo (qué gana CloudKit) lo mide el canario.
