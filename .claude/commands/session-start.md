---
description: Inicia una nueva sesión de trabajo con logging automático.
---

Inicia una nueva sesión de trabajo con logging automático.

PASOS:
1. Crea archivo de session log con timestamp:
   ```bash
   SESSION_FILE=".claude/sessions/$(date +%Y-%m-%d-%H%M%S).log"
   echo "# Session Started: $(date -Iseconds)" > $SESSION_FILE
   echo "## Context" >> $SESSION_FILE
   ```

2. Lee y registra contexto inicial:
   - Fase actual del ROADMAP
   - Últimos 3 commits de git log
   - Next Steps de STATE.md
   - Cualquier Risk activo

3. Pregunta al usuario: "¿En qué vas a trabajar en esta sesión?"

4. Registra el objetivo de la sesión en el log

5. PLANIFICACIÓN DE INCREMENTOS:
   - Analiza el objetivo declarado
   - Divide el trabajo en incrementos pequeños y verificables
   - Cada incremento debe poder completarse con un /commit-one
   - Presenta el plan al usuario en formato:
     ```
     ## Plan de trabajo para esta sesión:
     1. [Incremento 1] - [qué se logra]
     2. [Incremento 2] - [qué se logra]
     3. [Incremento N] - [qué se logra]

     ¿Comenzamos con el incremento 1?
     ```
   - ESPERA confirmación del usuario antes de implementar

6. Guarda la ruta del session file en archivo temporal:
   ```bash
   echo $SESSION_FILE > /tmp/current-session
   ```

7. Una vez el usuario confirme, comienza con el primer incremento del plan.

FORMATO DEL SESSION LOG:
```markdown
# Session Started: [timestamp ISO]

## Context
- Current Phase: [fase del ROADMAP]
- Recent Commits:
  - [hash] [mensaje]
- Next Steps: [lista de STATE]
- Active Risks: [si hay]

## Session Goal
[Lo que el usuario declaró que va a trabajar]

## Timeline
[Se irá poblando automáticamente con eventos]

## Outcomes
[Se llenará al final con session-end]
```

SESSION LOGGING (para otros comandos):
En /verify-ios, /test-ios, /commit-one:
1. Verifica si existe /tmp/current-session
2. Si existe, lee la ruta del session file
3. Agrega entrada al log:
   ```bash
   echo "[$(date -Iseconds)] [COMANDO] [resultado] [detalles breves]" >> $SESSION_FILE
   ```

De esta forma cada acción importante queda registrada automáticamente sin esfuerzo adicional.
