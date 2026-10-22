---
id: groups-reassociation-does-not-restore-the-bridge-link
status: backlog
priority: very-low
area: "groups, modo-nube"
created: 2026-09-11
source: "paso 10 (`groups-account-association-in-storage-row`): la mitad del AC que no se pudo cumplir sin un ancla inventada"
updated: 2026-10-08
---

# Al re-asociar la misma cuenta, los movimientos conservados no vuelven a ENLAZARSE con su gasto de grupo

## El problema, en lenguaje de usuario

Solté mi cuenta de grupos conservando los gastos que había pagado, y luego la volví a asociar. Mis grupos
vuelven y los gastos **no aparecen duplicados** —eso funciona—, pero los movimientos que conservé siguen
siendo movimientos personales sueltos: si alguien edita el importe del gasto en el grupo, el mío no se
entera.

## Por qué quedó así (2026-09-11)

El criterio de aceptación del paso 10 pedía «0 duplicados **y** los 3 vuelven a estar enlazados». Se
cumplió la primera mitad. La segunda exige guardar «devuélvele el puntero a ESA fila», y **no hay ancla
honesta con la que hacerlo**: `TransactionItem` no tiene identidad propia serializable (ni `id`, ni UUID
estable — `syncID` es opcional y en una sesión privada es `nil`). Las dos alternativas se descartaron con
su porqué:

- Un campo nuevo en `TransactionItem` da el ancla, pero ese modelo vive en el container CloudKit personal
  y un field key nuevo exige deploy a Production: sin él, el mirror rechaza el record entero y el sync
  personal muere para todo el parque (incidente `isOpeningBalance`).
- Un `PersistentIdentifier` persistido o una huella por importe+fecha+cuenta es el ancla-por-contenido que
  ya dio un incidente de identidad colapsada en este repo.

Lo que se hizo en su lugar: un libro de gastos conservados sellado con el `sub` de la cuenta
(`GroupsDetachedBridgeLedger`), que impide el duplicado sin inventar un ancla.

## Lo que se espera

Si Jürgen quiere el enlace de vuelta, la vía es el campo nuevo **con su deploy de schema coordinado**:
`dormantGroupLink: String?` en `TransactionItem` (y su gemelo en `InboxDraft`), actualizar
`Cloudkit Schemas/yala-production.ckdb` y desplegar a Production en el MISMO PR. Con eso, re-asociar la
misma cuenta rehidrata el puntero antes de que el canal arranque y el bridge reconcilia por
`splitExpenseID` como pide el ticket original.

## Medido en 2.1 (triage 2026-10-08)
- `dormantGroupLink` no existe en `Yala/`.
- Desde `15c764808` (2026-10-01) el libro de conservados guarda por movimiento su `persistentModelID` y una huella (`GroupsAssociationDetach.swift:220-246`). Solo se usa para saber si el movimiento sigue en el Panel; la regla de `swiftdata-cloudkit.md` dice que con el movimiento vivo una edición remota no lo recrea y remite a este ticket.
- La premisa «no hay ancla» cambió en parte: hay un ancla local, pero es por store y no sobrevive a recrearlo.

## Pregunta para Jürgen (triage 2026-10-08)
- **A.** Campo nuevo `dormantGroupLink` en `TransactionItem`/`InboxDraft` con deploy de schema a Production en el mismo PR.
- **B.** Reenlazar con el ancla del libro (identidad + huella) sin campo nuevo, aceptando que se pierde si el store se recrea.
- **C.** Dejarlo: los movimientos conservados quedan como personales sueltos, sin duplicados.
- **Recomendación: C** — caso raro (soltar y volver a asociar la misma cuenta) y A cuesta un deploy de schema. Con C no queda trabajo, por eso `very-low`.

Triage 2026-10-08: abierto · medium → very-low · Sigue sin enlace; el libro de conservados guarda desde 15c764808 la identidad y la huella de cada movimiento, pero solo para saber si sigue ahí, no para reenlazar. Necesita decisión.
