---
description: Ejecuta un checkpoint completo del proyecto: verifica, commitea, actualiza documentación y prepara para continuar con tokens frescos.
allowed-tools: Bash(git:*), Bash(xcodebuild:*), Bash(grep:*), Read, Write, Edit, Glob, Grep, Agent
---

Protocolo de "guardar y cerrar sesión limpiamente". Usar cuando te acercas al límite de tokens, terminas el día, o cambias de contexto.

PASOS OBLIGATORIOS (EN ORDEN):

1. VERIFICACIÓN:
   - Ejecutar /verify-ios
   - Si falla: DETENER TODO y reportar. NO continuar.

2. COMMIT (si hay cambios):
   - Ejecutar /commit-one (ya incluye: swift-audit + test gate + state update)
   - Si hay múltiples temas, forzar división en commits separados
   - Si no hay cambios: skip al paso 3

3. LIMPIEZA DE CLAUDE.md:
   - Leer CLAUDE.md actual
   - Identificar contenido obsoleto:
     * Decisiones recientes con TTL vencido
     * Referencias a bugs ya resueltos en secciones temporales
     * Conteos de tests desactualizados
   - Proponer qué eliminar y pedir confirmación antes de editar
   - Si hay info valiosa para archivar, moverla a DECISIONS.md

4. RESUMEN FINAL:
   ```
   ## Checkpoint

   Build: ✓/✗
   Tests: ✓/✗ (N tests, M suites)
   Commits: [lista con hashes]
   Próximo trabajo: [siguiente item según STATE]
   CLAUDE.md: [cambios hechos o "sin cambios"]

   Listo para /clear o continuar.
   ```

CUÁNDO EJECUTAR:
- Te acercas al límite de tokens (75%+)
- Terminas la sesión del día
- Completaste una fase del ROADMAP
- Vas a cambiar de feature o contexto
