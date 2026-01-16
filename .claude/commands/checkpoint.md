Ejecuta un checkpoint completo del proyecto: verifica, commitea, actualiza documentación y prepara para continuar con tokens frescos.

PROPÓSITO:
Este comando es tu protocolo de "guardar y cerrar sesión limpiamente" o "estoy cerca del límite de tokens y necesito resetear contexto".

PASOS OBLIGATORIOS (EN ORDEN):
1. VERIFICACIÓN:
   - Ejecuta /verify-ios completo
   - Si falla, detén TODO y reporta. NO continúes hasta que el build pase.

2. TESTS (si aplica):
   - Si el trabajo actual tocó lógica o datos, ejecuta /test-ios
   - Si falla, detén y reporta. NO continúes.

3. COMMIT:
   - Si hay cambios sin commitear, ejecuta /commit-one
   - Si hay múltiples temas, fuerza división en commits separados
   - Si hay commits wip: pendientes, pregunta si se deben combinar

4. ACTUALIZACIÓN DE STATE:
   - Lee STATE.md actual
   - Analiza Recent Progress (últimos commits)
   - Actualiza sección "Completed in Current Phase" con resumen de lo logrado desde el último checkpoint
   - Actualiza "Next Steps" basándote en ROADMAP y lo que falta del incremento/fase actual
   - Actualiza "Risks" si detectaste problemas o decisiones importantes
   - Limpia items obsoletos de Parking Lot

5. LIMPIEZA DE CLAUDE.MD:
   - Lee CLAUDE.md actual
   - Identifica secciones temporales o contexto ya obsoleto
   - Ejemplos de contenido obsoleto:
     * Referencias a bugs ya corregidos
     * Notas sobre decisiones ya tomadas y documentadas en STATE
     * Contexto de incrementos ya completados hace más de una semana
   - Propón qué eliminar y pide confirmación antes de editar
   - Si hay información valiosa para archivar, muévela a un archivo DECISIONS.md

6. RESUMEN FINAL:
   - Presenta al usuario un resumen ejecutivo:
     * Estado del build: ✓ o ✗
     * Tests: ✓ o ✗ o N/A
     * Commits realizados: lista con hashes
     * Próximo trabajo sugerido según STATE y ROADMAP
     * Memoria liberada: cambios hechos en CLAUDE.md
   - Declara: "Checkpoint completo. Contexto listo para continuar o cerrar sesión."

CUÁNDO EJECUTAR ESTE COMANDO:
- Te acercas al límite de tokens (75% o más)
- Terminas tu sesión de trabajo del día
- Completaste una fase completa del ROADMAP
- Vas a cambiar de feature o contexto
- Detectaste que la conversación perdió foco o coherencia
