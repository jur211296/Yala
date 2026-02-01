---
description: Distribuye un plan de múltiples features a worktrees paralelos
---

Toma un plan con múltiples features/tareas y prepara worktrees con instrucciones específicas para cada uno.

## PRERREQUISITO

Debes tener un plan generado (de Plan Mode o escrito). Ejemplo:
```
Plan:
1. Feature A: Implementar filtro por fechas
2. Feature B: Agregar exportación CSV
3. Feature C: Corregir bug de sincronización
```

## EJECUCIÓN

### PASO 1: Identificar las partes del plan

Pedir al usuario que confirme las partes:
```
Detecté [N] tareas en el plan:

1. [Nombre tarea 1] - [descripción breve]
2. [Nombre tarea 2] - [descripción breve]
3. [Nombre tarea 3] - [descripción breve]

¿Es correcto? ¿Cuáles quieres ejecutar en paralelo?
```

### PASO 2: Crear worktrees

Para cada tarea seleccionada:
```bash
git worktree add "../Yala-[nombre-corto]" -b "[nombre-branch]"
```

### PASO 3: Crear instrucciones para cada worktree

Para cada worktree, crear archivo `.claude/TASK.md`:

```markdown
# Tarea asignada

## Contexto
Este worktree fue creado para trabajar en paralelo.
Branch: [nombre]
Creado: [fecha]

## Objetivo
[Descripción de la tarea específica]

## Plan detallado
[Copiar la parte relevante del plan]

## Instrucciones
1. Ejecuta /session-start
2. Implementa según el plan
3. Usa /verify-ios y /test-smart después de cada incremento
4. Usa /commit-one para guardar progreso
5. Cuando termines, ejecuta /session-end

## Archivos relevantes
[Lista de archivos que probablemente tocará]

## NO tocar
[Archivos que otros worktrees modificarán - evitar conflictos]
```

### PASO 4: Mostrar instrucciones al usuario

```
╔═══════════════════════════════════════════════════════════════╗
║              PLAN DISTRIBUIDO A WORKTREES                     ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Worktrees creados: [N]                                       ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐  ║
║  │  TERMINAL 1                                             │  ║
║  │  Tarea: [Nombre tarea 1]                                │  ║
║  │  Comando: cd ../Yala-[nombre1] && claude                │  ║
║  │                                                         │  ║
║  │  Al iniciar, decir:                                     │  ║
║  │  "Lee .claude/TASK.md y ejecuta la tarea asignada"      │  ║
║  └─────────────────────────────────────────────────────────┘  ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐  ║
║  │  TERMINAL 2                                             │  ║
║  │  Tarea: [Nombre tarea 2]                                │  ║
║  │  Comando: cd ../Yala-[nombre2] && claude                │  ║
║  │                                                         │  ║
║  │  Al iniciar, decir:                                     │  ║
║  │  "Lee .claude/TASK.md y ejecuta la tarea asignada"      │  ║
║  └─────────────────────────────────────────────────────────┘  ║
║                                                               ║
║  [... más terminales ...]                                     ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  SIGUIENTE PASO                                               ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  1. Abre [N] terminales adicionales                           ║
║  2. Ejecuta el comando de cada terminal                       ║
║  3. En cada una, di: "Lee .claude/TASK.md y ejecuta"          ║
║  4. Opcionalmente agrega "modo /yolo" para autónomo           ║
║                                                               ║
║  Cuando todos terminen:                                       ║
║  /audit-branches [lista de branches]                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## VARIANTE: MODO YOLO PARALELO

Si el usuario quiere que los agentes trabajen sin validaciones:

En el archivo TASK.md agregar al inicio:
```markdown
## Modo de ejecución: YOLO

Ejecuta TODO el plan sin pausas para validación.
Al terminar, genera reporte completo para validación manual.
```

Y decirle al usuario que inicie cada terminal con:
```
"Lee .claude/TASK.md y ejecuta en modo /yolo"
```

## NOTAS IMPORTANTES

- Cada worktree tiene contexto INDEPENDIENTE
- Los agentes NO se comunican entre sí
- Evitar que toquen los mismos archivos (listar en "NO tocar")
- El usuario es el orquestador que decide cuándo mergear
- Usar /audit-branches antes de mergear para detectar conflictos
