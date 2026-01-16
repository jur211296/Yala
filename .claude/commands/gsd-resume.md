---
description: Lee la última sesión y presenta resumen para continuar trabajo.
---

Lee la última sesión y presenta resumen para continuar trabajo.

PASOS:
1. Encuentra el session log más reciente:
   ```bash
   ls -t .claude/sessions/*.log | head -1
   ```

2. Lee y analiza el log completo

3. Presenta RESUMEN EJECUTIVO:
   ```
   ÚLTIMA SESIÓN: [fecha]
   Objetivo: [lo que se intentó hacer]
   Resultado: [logrado/pendiente]

   Commits realizados:
   - [lista con hashes y mensajes]

   Estado actual del código:
   - Build: [último estado conocido]
   - Tests: [último estado conocido]

   Trabajo pendiente:
   [Lo que quedó sin terminar]

   Learnings clave:
   - [puntos importantes de la sesión anterior]
   ```

4. Consulta ROADMAP y STATE actuales

5. PROPUESTA DE CONTINUACIÓN:
   - Basándote en el trabajo pendiente de la sesión anterior
   - Considerando el estado actual de STATE.md
   - Sugiere el siguiente paso más lógico

Este comando es poderoso porque convierte tu memoria implícita en explícita. Ya no dependes de recordar qué estabas haciendo, el sistema te lo dice basándose en datos reales.
