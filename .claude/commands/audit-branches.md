---
description: Audita branches de worktrees paralelos antes de merge
argument-hint: "[branch1] [branch2] ... (opcional, detecta automáticamente)"
---

Invoca al agente branch-auditor para analizar branches paralelos.

## USO

```
/audit-branches                     # Detecta worktrees automáticamente
/audit-branches feature-a bugfix-b  # Branches específicos
```

## EJECUCIÓN

### PASO 1: Detectar branches a auditar

Si hay argumentos ($ARGUMENTS), usar esos branches.

Si no hay argumentos:
```bash
git worktree list
git branch --list | grep -v main | grep -v master
```

### PASO 2: Invocar agente auditor

Usar el agente `branch-auditor` con el Task tool:

```
Usa el agente branch-auditor para:
1. Comparar los branches [lista] contra main
2. Detectar archivos modificados en múltiples branches
3. Identificar conflictos potenciales
4. Recomendar orden de merge
```

### PASO 3: Presentar reporte

Mostrar el reporte del auditor con:
- Conflictos detectados
- Dependencias cruzadas
- Orden de merge recomendado
- Acciones sugeridas

## EJEMPLO DE OUTPUT

```
╔═══════════════════════════════════════════════════════════════╗
║                    AUDITORÍA DE BRANCHES                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  BRANCHES: feature-a, bugfix-b                                ║
║                                                               ║
║  CONFLICTOS: 1 archivo                                        ║
║  ⚠️  TransactionService.swift (ambos modifican fetch())       ║
║                                                               ║
║  ORDEN RECOMENDADO:                                           ║
║  1. bugfix-b → main (menor riesgo)                            ║
║  2. Rebase feature-a sobre main actualizado                   ║
║  3. Resolver conflicto en TransactionService                  ║
║  4. feature-a → main                                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## CUÁNDO USAR

- Antes de mergear branches de worktrees paralelos
- Cuando no estás seguro si hay conflictos
- Para decidir orden de merge óptimo
