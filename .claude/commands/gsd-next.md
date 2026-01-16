Analiza STATE y ROADMAP para proponer automáticamente el siguiente incremento de trabajo.

PASOS OBLIGATORIOS:
1. CONTEXTO ACTUAL:
   - Lee ROADMAP.md para identificar la fase actual
   - Lee STATE.md sección "Completed in Current Phase"
   - Lee STATE.md sección "Next Steps"
   - Lee STATE.md sección "Risks" para detectar blockers

2. ANÁLISIS DE DEPENDENCIAS:
   - Identifica qué items de "Next Steps" tienen dependencias pendientes
   - Identifica qué items están bloqueados por "Risks" sin resolver
   - Identifica qué items son completamente independientes y pueden empezar ahora

3. PROPUESTA:
   - Propón el siguiente incremento según esta prioridad:
     a) Resolver Risks críticos que bloquean múltiples items
     b) Completar items iniciados pero no terminados
     c) Empezar el siguiente item independiente según ROADMAP

4. FORMATO DE PROPUESTA:
   Presenta la propuesta con esta plantilla:

   PRÓXIMO INCREMENTO SUGERIDO:
   Contexto
   [Fase actual del ROADMAP]
   [Por qué este incremento ahora]
   [Dependencias que ya están resueltas]
   Requisitos
   [Qué debe lograr este incremento]
   Definition of Done
   [Criterios de aceptación específicos]
   Restricciones
   [Límites de alcance, archivos a NO tocar, etc.]
   Plan Sugerido
   [División en sub-incrementos commiteables si aplica]

CONFIRMACIÓN:
- Pregunta al usuario: "¿Procedo con este incremento o prefieres trabajar en otra cosa?"
- Si el usuario acepta, marca en STATE que este item pasó de "Next Steps" a "In Progress"
- Si el usuario rechaza, pide que especifique qué prefiere trabajar

REGLAS:
- NUNCA sugieras trabajo que tenga dependencias sin resolver
- SIEMPRE prioriza resolver risks que bloquean progreso
- Si hay múltiples opciones equivalentes, explica las razones para elegir una sobre otra
- El plan sugerido debe respetar la filosofía de incrementos pequeños y verificables
