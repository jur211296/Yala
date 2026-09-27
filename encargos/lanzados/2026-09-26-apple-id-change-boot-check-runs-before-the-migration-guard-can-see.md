# En el arranque, la comprobación del cambio de Apple ID ya ve si hay una migración a la nube en marcha

## Contexto
Ticket `tickets/backlog/apple-id-change-boot-check-runs-before-the-migration-guard-can-see.md` (medium, Cola A riesgo real). Sale de la review de `an-unreadable-migration-journal-reads-as-never-started`.

Hoy `AppBootstrapper.checkForAppleIDChange(trigger: "boot")` corre antes de `CloudMigrationController.configureShared`. Su guard `(CloudMigrationController.shared?.uiState ?? .idle) == .idle` ve `shared == nil` y deja pasar siempre: en el arranque la protección «no ofrecer cerrar la sesión privada a mitad de una migración» no existe. Cerrar ahí puede borrar lo local mientras sube.

Cola A autónoma sigue armada tras el merge de #272. Noche América/Lima: no despiertes a Jürgen; elige lo robusto abajo.

## Que se pide
1. Que en el arranque, con una fase de migración transitoria journaleada, no se ofrezca el cierre por cambio de Apple ID.
2. Decisión robusta (ya tomada, no preguntes):
   - Mueve el disparador de arranque detrás de `configureShared` (paso 14.6), **y** haz que el guard lea también el journal por su cuenta (`MigrationPhaseStore.currentPhaseRead`, que ya distingue lectura fallida).
   - Si no se sabe (journal ilegible / fase no `.idle`), no ofrezcas el cierre: el error caro es el falso «parece idle».
3. Test del orden (el guard ve controller o journal) + control positivo sin migración.
4. Gate, mutantes del área, review adversarial de tres lentes. Hallazgos con ticket propio.
5. PR a `2.1`, merge cuando CI verde, board al día (`tickets/` + `docs/TICKETS.md`), `/cerrar-total`.

## MODO AUTÓNOMO (norma Jürgen 2026-09-22, vigente)
Implementa de punta a punta sin pedir «¿Sigo?» tras el plan y sin esperar aprobación aunque toques más de 3 ficheros. Solo AskUserQuestion de producto/acceso real entre 06:00–21:00 Lima; de noche elige lo recomendado/robusto o aparca en ticket si es demasiado grave para asumir. No dejes el PR abierto «para que Jürgen mire»: mergea y cierra.

## Que NO hay que tocar
- marketing/, store, tags, releases.
- clinicas-dentales-bi ni datos de salud.
- No relanzar encargos [EN CURSO].
- No ampliar a rediseño de sesión (paso 9) ni a otros tickets de Apple ID salvo residuales reales del diff.

## Como se sabe que esta bien
- Criterios del ticket cumplidos y marcados.
- Gate verde del área; mutantes del cambio cazados o justificados.
- Review adversarial sin altos/medios abiertos sobre el diff (o con ticket).
- PR mergeado a `2.1`, ticket fuera de backlog, `docs/TICKETS.md` al día, `/cerrar-total` limpio.

## Paso 0

Decisiones (auto-contestadas, noche Lima):

1. **Las dos cosas, no una.** El disparador de arranque pasa detrás del 14.6 (el controller ya existe y su `init` hace
   `refresh()`), y el guard deriva además el estado desde el journal (`MigrationPhaseStore.currentPhaseRead`), porque el
   controller puede no existir nunca (`!CloudBackendConfig.isConfigured`) o faltar un rato (swap de persona, R4).
2. **«En reposo» se decide con la MISMA derivación que la pantalla** (`CloudMigrationUIStateDeriver.derive(read:)`), no con
   una lista de fases propia: reposo = `.idle`. Journal ilegible ⇒ `.journalUnreadable` ⇒ no se ofrece.
3. **Función pura nueva** `AppleIDChangeCloseLogic.migrationAtRest(...)`: el guard vive tras `isRunningTests`, así que la
   única red de comportamiento es la pura; el cableado y el orden van por source-scan.
4. Ficheros: `AppleIDChangeCloseLogic.swift`, `AppBootstrapper.swift`, `AppleIDChangeCloseLogicTests.swift`,
   `qa/coverage-index.json`, ticket + `docs/TICKETS.md`, regla de área si sale trampa durable.
5. Residual asumido: sin controller, el efecto del adopt pendiente (`notStarted` + `.adoptBackendAccount`) no lo ve el
   journal de fase; solo pasa sin backend configurado (sin adopt posible) o en la ventana del swap.
