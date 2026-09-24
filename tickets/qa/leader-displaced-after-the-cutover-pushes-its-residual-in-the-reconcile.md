---
id: leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `displaced-migration-leader-keeps-uploading-after-a-takeover` (2026-09-24), lente de bypass"
---

# El teléfono que pierde el relevo DESPUÉS del cutover sigue subiendo lo que escribe

## El problema, en lenguaje de usuario

Activo la nube en el teléfono A, que llega casi al final y se queda esperando a que reabra Yala. Tardo más de una hora. Otro
teléfono B entra en la cuenta y toma el relevo. Cuando reabro A, sube lo que escribí mientras tanto encima de lo que B está
subiendo, y lo vuelve a intentar cada vez que abro la app.

## Lo medido (2026-09-24, leyendo el código; sin ejecutar)

- `displaced-migration-leader-keeps-uploading-after-a-takeover` cerró la subida y la verificación: una puerta del lease antes
  de cada página. No cubre lo que va detrás del `cutover(.serverConfirmed)`.
- En `cutover(.markerWritten)` y `.mirrorOff` el runner no late (`MigrationRunner.swift`, `driveCutover`), así que el lease
  puede caducar esperando al marcador o al relanzamiento asistido.
- La copia de staging de `claim_account` (`qa/cloud/g15_01_account_kind.sql`, la rama del relevo) mira
  `migration_in_progress`, el líder y la edad del lease; NO mira `migrated_at`. Medido en el SQL del repo, no en producción.
- En `done`, `.runLeaderReconcileFromFrozenCloudKit` hace `drainOnce` y empuja el residual del outbox
  (`MigrationWorkExecutor.swift`, `runLeaderReconcileFromFrozenCloudKit`) ANTES del `complete`, que es lo único que contesta
  `other_leader`. El efecto lanza y se reintenta en cada arranque.
- Previo a ese ticket: no lo abre, pero tampoco lo cierra.

## Candidatas (sin medir)

- Servidor: que `claim_account` no dé el relevo sobre una cuenta con `migrated_at` puesto (el líder ya pasó el cutover y el
  modo local ya es `.cloud`: el relevo no tiene sentido ahí). Hay que medir el cuerpo vivo de producción primero.
- Cliente: la misma puerta del lease delante del push del reconcile.
- Latir en `markerWritten`/`mirrorOff` mientras se espera.

## Criterios de aceptación

- [x] Un teléfono que perdió el lease después del cutover no sube nada a la cuenta (mientras el otro lidera).
- [x] Sale o se recupera: se recupera. Sin texto nuevo, a propósito (ver «Lo hecho»).

## Lo hecho (2026-09-24)

**Para quien usa la app:** el teléfono que activó la nube y perdió el relevo después del último paso ya no sube lo que
escribió encima de la activación del otro dispositivo, ni lo reintenta en bucle. Mientras el otro sigue, espera sin subir
nada; cuando el otro termina, se une a la cuenta como un dispositivo más y empieza a sincronizar (hasta hoy se quedaba sin
sincronizar para siempre con «Nube activa» en pantalla). Si el otro abandona, a los 60 min recupera el relevo y termina él.

**No sale a iCloud**, a diferencia de #237: tras el cutover el marcador ya se exportó y sus datos ya están verificados en
la cuenta, así que volver atrás contradiría «el cutover jamás hace rollback». Tampoco hay texto nuevo: no hay nada que la
persona pueda decidir, y «Nube activa» es verdad en cuanto se une.

**Cómo:** `MigrationWorkExecutor.resolvePostCutoverLease` antes del drain y del push del reconcile de `done`: latido →
`complete` (desempata su propio cierre perdido) → claim de migración directo (`created` vuelve a liderar,
`claiming_in_progress` espera, `existing_stable` se une con `.routeReturningUser`). El push del barrido lleva el
`continueWhile` de 30 min y un push cortado no deja salir el `complete`. Canario `cloudPostCutoverLeaseLost`.
Regla del área: «Y después del cutover el líder desplazado no sube, no sale». Servidor intacto (ticket aparte:
`claim-grants-a-takeover-after-the-leader-passed-the-cutover`).

**Verificado:** 12 tests nuevos en `MigrationWorkExecutorTests` (`postCutover_*`) y uno reparado que se había quedado
vacío; 10 mutantes muertos; review de dos lentes (servidor/carreras y consumidores), sin hallazgos que suban nada.

## Guion de device-QA (dos iPhone, misma cuenta, build de TestFlight)

1. iPhone A en iCloud con datos. Ajustes → Almacenamiento → «Migrar a la nube», iniciar sesión y dejar que llegue al
   final (pide cerrar y reabrir Yala). **No reabras A.** Ponlo en modo avión.
2. Espera **más de 60 min**.
3. iPhone B (misma cuenta de Apple/Google): Ajustes → Almacenamiento → activar la nube. Debe tomar el relevo y avanzar.
4. Con B a medias, quita el modo avión a A y abre Yala. **Esperado:** A no sube nada (en Almacenamiento sigue «Nube
   activa») y B termina su activación sin fallar la verificación.
5. Cuando B termine, cierra y abre Yala en A. **Esperado:** A se une: crea un gasto en A y aparece en B tras sincronizar.
6. Fallo si: B sale con error en la verificación, A no sincroniza nunca tras el paso 5, o aparecen datos duplicados.
