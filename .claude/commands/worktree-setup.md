---
description: Prepara worktrees para trabajo paralelo en múltiples tareas
argument-hint: "[nombre-tarea-1] [nombre-tarea-2] ..."
---

Configura git worktrees para trabajar en múltiples tareas en paralelo.

## USO

```
/worktree-setup feature-auth bugfix-crash refactor-models
```

## EJECUCIÓN

### PASO 1: Validar estado actual

```bash
# Verificar que no hay cambios sin commitear
git status --porcelain
```

Si hay cambios pendientes:
```
⚠️ Hay cambios sin commitear en el worktree principal.
Commitea o stashea antes de crear worktrees.

¿Qué prefieres?
1. Ejecutar /commit-one primero
2. Hacer git stash
3. Cancelar
```

### PASO 2: Crear worktrees

Para cada nombre proporcionado en $ARGUMENTS:

```bash
# Crear directorio hermano con worktree
git worktree add "../Yala-[nombre]" -b "[nombre]"
```

### PASO 3: Preparar cada worktree

Para cada worktree creado:
1. Copiar configuración de Claude si existe (.claude/settings.json)
2. Verificar que el proyecto compila

### PASO 4: Generar instrucciones

```
╔═══════════════════════════════════════════════════════════════╗
║                 WORKTREES CONFIGURADOS                        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Worktrees creados:                                           ║
║                                                               ║
║  1. ../Yala-[nombre1]                                         ║
║     Branch: [nombre1]                                         ║
║     Terminal: cd ../Yala-[nombre1] && claude                  ║
║                                                               ║
║  2. ../Yala-[nombre2]                                         ║
║     Branch: [nombre2]                                         ║
║     Terminal: cd ../Yala-[nombre2] && claude                  ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  INSTRUCCIONES                                                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  1. Abre [N] terminales adicionales                           ║
║                                                               ║
║  2. En cada terminal, ejecuta el comando correspondiente:     ║
║     Terminal 1: cd ../Yala-[nombre1] && claude                ║
║     Terminal 2: cd ../Yala-[nombre2] && claude                ║
║                                                               ║
║  3. En cada sesión de Claude, usa /session-start              ║
║                                                               ║
║  4. Trabaja en cada tarea independientemente                  ║
║                                                               ║
║  5. Al terminar, desde el worktree principal:                 ║
║     git worktree remove ../Yala-[nombre]                      ║
║     git branch -d [nombre]  # si ya mergeaste                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## LIMPIEZA DE WORKTREES

Comando para limpiar después:
```bash
# Ver worktrees activos
git worktree list

# Remover worktree específico
git worktree remove ../Yala-[nombre]

# Limpiar referencias huérfanas
git worktree prune
```

## NOTAS

- Cada worktree tiene su propia sesión de Claude Code
- Los commits en un worktree no afectan a otros
- Puedes mergear branches cuando termines
- El worktree principal (este) no se modifica
