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

5. Guarda la ruta del session file en variable de entorno o archivo temporal:
```bash
   echo $SESSION_FILE > /tmp/current-session
```

6. PRESENTA CONFIRMACIÓN Y DETENTE:
   Informa al usuario:
   - "Sesión iniciada y registrada"
   - "Objetivo: [el objetivo que declaró el usuario]"
   - "Session log creado en: [ruta del archivo]"
   - "Listo para empezar. ¿Qué incremento quieres que implemente?"
   
   CRÍTICO: NO EMPEZAR A IMPLEMENTAR AUTOMÁTICAMENTE
   - Esperar instrucción explícita del usuario
   - El usuario dirá algo como "Implementa Incremento 1" o "Implementa el primer incremento"
   - SOLO después de esa instrucción explícita proceder con implementación

FORMATO DEL LOG:
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

REGLAS:
- Este comando SOLO registra el inicio de sesión, NO implementa código
- La implementación comienza cuando el usuario lo indique explícitamente
- Si el usuario ya tiene un plan de incrementos de /gsd:next, debe referirse a ellos por número