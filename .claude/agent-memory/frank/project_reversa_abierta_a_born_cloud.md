---
name: reversa-abierta-a-born-cloud
description: PR #132 abre «Volver a iCloud» a las cuentas nacidas en la nube; la review cazó DOS defectos graves míos; g15_02 aplicada en los dos entornos y falta el device-QA de CloudKit, que no es simulable.
metadata:
  type: project
---

**«Volver a iCloud» ya está abierta a quien nació en la nube** (PR #132, 2026-09-10, decisión de Jürgen
del mismo día). Eran **dos gates**, uno en cada lado, y ninguno había que construirlo.

**Why:** tras el fresh start del 10-sep toda cuenta nueva nace en la nube, así que el guard por
`migrated_at` cerraba la fila E de la matriz —la única degradación `complete → groups_only` del sistema—
para la población entera.

**How to apply:**

- **El backend ya no pregunta si migraste, pregunta qué eres**: `reverse_claim` exige `kind='complete'`
  **o** `reverted_at` no nulo. `g15_02` aplicada en **staging Y producción** con md5 idéntico
  (`14fc5e2c…`); producción estaba a cero filas, así que no afectó a nadie. Entró en tres pasos
  (`g15_02`, `g15_02b`, `g15_02c`) y el fichero del repo produce el resultado final en uno.
- **El gate del cliente exige el mapa CloudKit solo a quien no consta como born-cloud AQUÍ**
  (`StorageModePersistence.isBornCloud`, marca positiva que escribe el alta). El *migrado sin mapa*
  sigue excluido a propósito: es el riesgo de resurrección de borrados.
- **La premisa del ticket era falsa y bajó el alcance**: no hacía falta escribir un export a CloudKit.
  La reversa monta el mirror y `NSPersistentCloudKitContainer` sube solo; `reverseUpload` solo sondea.
- **Lo que falta y es de Jürgen: el device-QA de CloudKit real, y NO es simulable.** Que el mirror
  exporte por primera vez un corpus born-cloud no está medido en este repo. El guion está en el ticket
  con su testigo aritmético (los testigos con `ckRecordName` pasan de 0 a cubrir las filas vivas).
- **Deja 5 tickets, dos `high` que este cambio agranda** de un caso raro a todo el mundo:
  `reverse-upload-has-no-ceiling-and-no-exit` y `reverse-claim-rejection-has-no-way-out-in-the-client`.
  Los dos son la misma forma: una fase de la reversa sin salida, con el backend ya congelado.

## Lo que no volvería a hacer igual

**La review adversarial cazó DOS defectos graves míos**, y los dos eran de la misma familia: yo había
razonado el caso normal y no el caso en que la señal falla. Están en
[[un-gate-derivado-de-una-ausencia-falla-abierto]]. Si alguien retoma esto: el diseño final es
deliberadamente **conservador en el segundo dispositivo**, y eso tiene ticket
(`reverse-hidden-on-a-born-cloud-second-device`) — no es un olvido.

Y un detalle de andamio que costará una vuelta a quien no lo sepa: **`reverse_complete` degrada `kind` y
`kind` no se puede PATCHear** (lo veta un trigger), así que en `account.goldens.test.ts` el golden 16
CIERRA la puerta para todo lo que venga detrás. Lo resuelve un `beforeAll` idempotente
(`ensureCompleteKind`) que repromueve por la ruta real de la fila F. Un `not_complete` inesperado en esos
goldens es **andamio roto, no RPC roto**.

Relacionado: [[bloque-identidad-nube-rutea]] (el paso 3, del que sale este ticket) ·
[[percent-eleccion-nube-alineado-con-prod]] · [[rediseno-sesiones-dos-ejes]] ·
[[un-timeout-no-distingue-lento-de-colgado]] (el rojo del golden 20, refutado de paso)
