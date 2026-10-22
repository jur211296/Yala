---
name: puerta-icloud-rama-privada
description: Paso 4 del rediseño — la rama privada consulta CloudKit antes de pedir reinicio; PR #133, device-QA pendiente con un punto BLOQUEANTE que va primero
metadata:
  type: project
---

**«Primera vez → Tu cuenta en tu iCloud privado» ya no pide reiniciar a ciegas: consulta CloudKit
primero.** PR #133, paso 4 de la cola del rediseño de sesiones. El ticket vive en `tickets/qa/` con su
device-QA dentro (mismo patrón que los pasos 1-3).

**Why:** era un bug medido en device por Jürgen el 2026-09-09 — reinstalabas, elegías privado, la app
pedía reiniciar y al reabrir te metía en el onboarding completo mientras iCloud bajaba tu histórico por
debajo. La rama salía por `leaveWelcome(.privateOnboarding)`, que con el mount neutro persiste el destino
y **no llama** al callback que consultaba si había datos.

**How to apply:**

- **Lo que falta es device-QA y NO es simulable.** CloudKit no existe en simulador: la sonda, el borrado
  de la zona y que el espejo la recree vacía solo se ven en un iPhone con TestFlight.
- **Su punto BLOQUEANTE va primero, y está escrito en el ticket:** comprobar que la sonda no lanza.
  `ICloudPersonalCorpusProbe` baja una lista de `desiredKeys` ÚNICA sobre una zona MULTI-TIPO
  (`CD_isSystemAccount` no existe en `CD_TransactionItem`). Si el servidor validara las keys contra el
  schema de cada tipo, **cada página lanzaría** y la rama privada quedaría en «reintentar» para siempre.
  Es el primer lector de registros de CloudKit del repo: no hay precedente. El plan B está escrito.
- **Decisión de Jürgen del 2026-09-10**: en el aviso del espejo tardío, «cancelar» = **déjalo así** — los
  dos corpus conviven. Lo que el ticket arregla no es que convivan: es que convivieran en silencio.
- **Tres tickets nuevos** de residuales que no toqué: `late-icloud-wipe-can-re-export-between-its-two-halves`
  (medium, su arreglo natural es del paso 9), `coverage-index-meta-counts-drifted-from-reality`,
  `welcome-destructive-buttons-are-plain-text-taps`.
- **La rama de sesión secundaria sigue saltándose la puerta a propósito**: su store nunca espeja a
  iCloud, y M1 se retira entera en el paso 12.

Relacionado: [[rediseno-sesiones-dos-ejes]], [[la-correccion-de-la-lente-reintroduce-el-bug]].
