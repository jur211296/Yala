# Flujo de Trabajo Optimizado

## Referencia rápida

```
/next → Plan Mode → /review-plan → /session-start
     ↓
[/analyze-impact] → Implementar → /verify-ios → /test-smart → /commit-one
     ↓                              ↑__________________|
[/idea si surge algo]                    (repetir)
     ↓
/pre-deploy-check → /session-end → /compact → /clear
```

---

## Fases del flujo

### FASE 1: Orientación
| Comando | Propósito |
|---------|-----------|
| `/next` | Ver qué sigue según STATE y ROADMAP |

**Output esperado:** Lista de opciones numeradas para elegir.

---

### FASE 2: Planificación
| Acción | Propósito |
|--------|-----------|
| `Shift+Tab` | Entrar en Plan Mode (Claude explora sin modificar) |
| `/review-plan` | Revisor escéptico del plan generado |
| `Ctrl+G` | Editar plan si necesita ajustes |

**Cuándo usar Plan Mode:**
- Features nuevas
- Refactors que tocan múltiples archivos
- Cambios en modelos de datos
- Cualquier cosa donde "explorar primero" ahorre retrabajo

**Cuándo saltar Plan Mode:**
- Bug fixes puntuales
- Cambios cosméticos
- Ajustes menores a código que ya conoces

---

### FASE 3: Análisis de impacto (opcional)
| Comando | Propósito |
|---------|-----------|
| `/analyze-impact [componente]` | Subagentes analizan dependencias en paralelo |
| `/parallel-search [patrón]` | Búsqueda exhaustiva en código/tests/docs |

**Cuándo usar:**
- Cambios a modelos core (Category, Account, TransactionItem)
- Refactors de servicios usados en múltiples lugares
- Renombrar funciones/propiedades
- Eliminar código

**Output:** Mapa de impacto con nivel de riesgo y recomendación.

---

### FASE 4: Inicio de sesión
| Comando | Propósito |
|---------|-----------|
| `/session-start` | Crear log, registrar objetivo |

**Se integra con /next:** Si vienes de /next con plan definido, no repite preguntas.

---

### FASE 5: Ciclo de incremento

```
┌─────────────────────────────────────────────┐
│                                             │
│   Implementar código                        │
│        ↓                                    │
│   /verify-ios        ← Build check          │
│        ↓                                    │
│   /test-smart        ← Tests relevantes     │
│        ↓                                    │
│   Usuario valida     ← Probar en simulador  │
│        ↓                                    │
│   ¿Funciona?                                │
│     │                                       │
│     ├─ No → Corregir → (volver arriba)      │
│     │                                       │
│     └─ Sí → /commit-one                     │
│              ↓                              │
│         ¿Más incrementos?                   │
│           │                                 │
│           ├─ Sí → (volver arriba)           │
│           │                                 │
│           └─ No → Siguiente fase            │
│                                             │
└─────────────────────────────────────────────┘
```

**Comando útil durante implementación:**
| Comando | Propósito |
|---------|-----------|
| `/idea` | Capturar idea sin perder foco |

---

### FASE 6: Validación final
| Comando | Propósito |
|---------|-----------|
| `/pre-deploy-check` | Checklist automático de calidad |

**Verifica:**
- `try?` sin manejo de error
- Force unwraps (`!`)
- Prints sin `#if DEBUG`
- TODOs pendientes
- Credenciales hardcodeadas
- QA-SCENARIOS actualizado

**Output:** LISTO PARA DEPLOY o BLOQUEADO con lista de issues.

---

### FASE 7: Cierre de tarea
| Comando | Propósito |
|---------|-----------|
| `/session-end` | Resumen de la sesión, outcomes |

**Genera:**
- Estadísticas (commits, builds, tests)
- Key learnings
- Trabajo pendiente si quedó algo

---

### FASE 8: Gestión de contexto
| Comando | Propósito |
|---------|-----------|
| `/context-snapshot` | Guardar contexto mental antes de perderlo |
| `/compact` | Comprimir conversación estratégicamente |
| `/clear` | Liberar contexto completamente |

**Decisión:**
- ¿Hay contexto valioso no commiteado? → `/context-snapshot` primero
- ¿Solo ruido acumulado? → `/compact` directo
- ¿Cambio total de tarea? → `/clear`

---

## Comandos por categoría

### Orientación
- `/next` - Qué viene después

### Planificación
- `Shift+Tab` - Plan Mode
- `/review-plan` - Revisar plan críticamente

### Análisis
- `/analyze-impact [componente]` - Impacto de cambios
- `/parallel-search [patrón]` - Búsqueda paralela

### Sesión
- `/session-start` - Iniciar sesión con log
- `/session-end` - Cerrar sesión con resumen

### Verificación
- `/verify-ios` - Build completo
- `/verify-quick` - Check rápido de sintaxis
- `/test-smart` - Tests relevantes
- `/test-ios` - Todos los tests
- `/pre-deploy-check` - Checklist pre-merge

### Commits
- `/commit-one` - Commit atómico con actualización de STATE
- `/checkpoint` - Verify + commit + actualizar docs

### Captura
- `/idea` - Capturar idea al Parking Lot

### Contexto
- `/context-snapshot` - Guardar estado mental
- `/compact` - Comprimir estratégicamente
- `/clear` - Liberar todo

---

## Flujos alternativos

### Flujo rápido (bug fix puntual)
```
/next → /session-start → Implementar → /verify-ios → /commit-one → /session-end
```

### Flujo profundo (feature compleja)
```
/next → Shift+Tab → /review-plan → /analyze-impact → /session-start
     → [múltiples incrementos con verify/test/commit]
     → /pre-deploy-check → /session-end → /context-snapshot → /compact
```

### Flujo de exploración (no sé qué hacer)
```
/next → Shift+Tab (solo explorar) → /context-snapshot → /clear
```

---

## Tips de eficiencia

1. **Usa subagentes para búsquedas**: `/parallel-search` y `/analyze-impact` no consumen tu contexto principal.

2. **Compacta en puntos naturales**: Después de cada tarea completada, no cuando te quedas sin tokens.

3. **Plan Mode no es opcional para features**: El tiempo invertido en planificar se recupera evitando retrabajo.

4. **`/idea` preserva el foco**: Capturar y seguir es mejor que interrumpir para "no olvidar".

5. **`/pre-deploy-check` antes de PR**: Atrapa errores comunes antes de que lleguen a code review.

6. **Snapshots para contexto complejo**: Si investigaste algo por 30+ minutos, vale un snapshot.
