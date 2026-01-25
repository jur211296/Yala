---
description: Inicia una nueva sesión de trabajo con logging automático.
---

Inicia una nueva sesión de trabajo con logging automático.

## DETECCIÓN DE CONTEXTO

Detecta automáticamente:
- Mac: del directorio actual (/Users/jur/Yala o /Users/work/Yala)
- Si viene de /next: ya tenemos objetivo y plan definidos en la conversación

## MODO RÁPIDO (viene de /next)

Si en la conversación actual ya se definió:
- El item/objetivo a trabajar
- El plan de incrementos (opcional)

Entonces:
1. Crear archivo de sesión
2. Registrar objetivo y plan en el log
3. Preguntar: "¿Comenzamos con el incremento 1?"
4. NO volver a preguntar objetivo ni planificar

## MODO NORMAL (ejecución directa)

Si se ejecuta `/session-start` sin contexto previo de `/next`:

1. Crear archivo de sesión:
   ```bash
   SESSION_FILE=".claude/sessions/$(date +%Y-%m-%d-%H%M%S).log"
   echo "# Session Started: $(date -Iseconds)" > $SESSION_FILE
   ```

2. Mostrar contexto rápido (sin preguntas):
   ```
   Fase actual: [fase]
   Últimos commits: [3 commits]
   ```

3. Preguntar: "¿En qué vas a trabajar en esta sesión?"

4. Preguntar: "¿Quieres que divida el trabajo en incrementos?"
   - Si sí: proponer plan
   - Si no: empezar directo

5. Guardar ruta: `echo $SESSION_FILE > /tmp/current-session`

## CICLO DE TRABAJO

Una vez iniciada la sesión, por cada incremento:

1. Implementar el incremento
2. Ejecutar /verify-ios (o /verify-quick)
3. Si hay tests relevantes: /test-smart
4. Presentar resultado:
   ```
   ✓ Incremento [N] implementado
   - Build: OK/Error
   - Tests: OK/Error/N/A

   ¿Validaste que funciona? (sí/no/ajustes)
   ```
5. Esperar confirmación:
   - "sí" → /commit-one → siguiente incremento
   - "no/ajustes" → corregir → volver a 1

## FORMATO DEL LOG

```markdown
# Session Started: [timestamp ISO]

## Context
- Phase: [fase]
- Recent: [commits]

## Goal
[objetivo]

## Plan
1. [incremento 1]
2. [incremento 2]

## Timeline
[eventos conforme ocurren]

## Outcomes
[se llena con /session-end]
```

## REGLAS

- Detectar Mac automáticamente, NO preguntar
- Si viene de /next, NO repetir preguntas ya respondidas
- Ser conciso en el output
- La implementación comienza solo cuando el usuario confirme
