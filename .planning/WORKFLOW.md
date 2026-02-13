# Flujo de Trabajo Optimizado

## Referencia rápida

```
/clear → /next → Plan Mode → /review-plan → Accept edits
→ Implementar → /verify-ios → /test-smart → /swift-audit
→ /commit-one → /clear
```

---

## Flujos según tipo de tarea

### Flujo estándar (feature normal — 80% del trabajo)
```
/clear → /next → Plan Mode (Shift+Tab) → /review-plan → Accept edits
     ↓
Implementar → /verify-ios → /test-smart → /swift-audit
     ↓
/commit-one → /clear
```

### Flujo rápido (bug fix puntual)
```
/next → Implementar → /verify-ios → /commit-one
```

### Flujo autónomo (tarea mecánica con plan aprobado)
```
/clear → /next → Plan Mode → /review-plan → /yolo
→ [Claude ejecuta TODO sin pausas]
→ Validar reporte final
```

### Flujo complejo (modelo core, multi-archivo, alto riesgo)
```
/clear → /next → /analyze-impact [componente]
→ Plan Mode → /review-plan → Accept edits
→ Implementar → /verify-ios → /test-smart
→ /review-session → aplicar mejoras
→ /swift-audit → /commit-one
→ /context-snapshot → /clear
```

---

## Fases del flujo

### FASE 1: Orientación
| Comando | Propósito |
|---------|-----------|
| `/next` | Ver qué sigue según STATE y ROADMAP |

**Output:** Lista de opciones numeradas para elegir.

---

### FASE 2: Planificación
| Acción | Propósito |
|--------|-----------|
| `Shift+Tab` | Entrar en Plan Mode (Claude explora sin modificar) |
| `/review-plan` | Revisor escéptico del plan generado |

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

### FASE 3: Análisis de impacto (solo para cambios de alto riesgo)
| Comando | Propósito |
|---------|-----------|
| `/analyze-impact [componente]` | Subagentes analizan dependencias en paralelo |
| `/parallel-search [patrón]` | Búsqueda exhaustiva en código/tests/docs |

**Cuándo usar:**
- Cambios a modelos core (Category, Account, TransactionItem)
- Refactors de servicios usados en múltiples lugares
- Renombrar funciones/propiedades
- Eliminar código

---

### FASE 4: Ciclo de implementación

```
┌─────────────────────────────────────────────┐
│                                             │
│   Implementar código                        │
│        ↓                                    │
│   /verify-ios        ← Build check          │
│        ↓                                    │
│   /test-smart        ← Tests relevantes     │
│        ↓                                    │
│   ¿Funciona?                                │
│     │                                       │
│     ├─ No → Corregir → (volver arriba)      │
│     │                                       │
│     └─ Sí → /swift-audit → /commit-one      │
│                                             │
└─────────────────────────────────────────────┘
```

**Comandos durante implementación:**
| Comando | Propósito |
|---------|-----------|
| `/verify-quick` | Check rápido de sintaxis entre cambios |
| `/idea` | Capturar idea sin perder foco |

---

### FASE 5: Cierre
| Comando | Propósito |
|---------|-----------|
| `/context-snapshot` | Guardar contexto mental (si sesión compleja) |
| `/clear` | Liberar contexto completamente |

---

## Skills disponibles (25)

### Orientación
- `/next` — Qué viene después

### Planificación
- `Shift+Tab` — Plan Mode
- `/review-plan` — Revisar plan críticamente

### Análisis
- `/analyze-impact [componente]` — Impacto de cambios con subagentes
- `/parallel-search [patrón]` — Búsqueda paralela exhaustiva

### Verificación
- `/verify-ios` — Build completo
- `/verify-quick` — Check rápido de sintaxis
- `/test-smart` — Tests relevantes para cambios actuales
- `/test-ios` — Todos los tests

### Calidad Swift
- `/swift-audit` — Auditoría completa (try?, !, prints, DS, deprecated, L10n)
- `/swiftdata-check` — Validación de modelos SwiftData
- `/swift-modernize` — Detectar patrones legacy, sugerir APIs modernas

### Review
- `/review-code [archivo]` — Code review con agente swift-reviewer
- `/review-session` — Review de todos los .swift modificados en sesión
- `/pre-deploy-check` — Checklist pre-merge/deploy

### Commits
- `/commit-one` — Commit atómico con actualización de STATE
- `/checkpoint` — Verify + test + commit + actualizar docs en 1 paso

### Contexto
- `/context-snapshot` — Guardar estado mental antes de perderlo
- `/compact` — Comprimir conversación estratégicamente
- `/clear` — Liberar contexto completamente

### Captura
- `/idea` — Capturar idea al Parking Lot sin interrumpir

### Autónomo
- `/yolo` — Claude ejecuta todo sin pausas (implementar+verify+test+commit)

### Auditoría periódica (pre-release, 1x por fase)
- `/deep-scan [dir]` — Escaneo profundo archivo por archivo (bugs, patterns, mejoras)
- `/a11y-audit [dir]` — Accesibilidad: VoiceOver, Dynamic Type, touch targets, contraste
- `/ds-compliance [dir]` — Design System: tokens, componentes, APIs modernas
- `/test-coverage` — Análisis de cobertura + identificación gaps críticos
- `/pre-launch` — Checklist completo pre-App Store (Apple compliance)

---

## Custom Agents disponibles

| Agente | Invocación | Propósito |
|--------|------------|-----------|
| `swift-reviewer` | `/review-code` | Revisa código según convenciones de Yala |
| `test-generator` | `/generate-tests` | Genera tests unitarios |

---

## Tips de eficiencia

1. **Plan Mode no es opcional para features**: El tiempo invertido en planificar se recupera evitando retrabajo.

2. **`/test-smart` SIEMPRE antes de commit**: Cerrar el gap de calidad.

3. **`/swift-audit` reemplaza review+pre-deploy**: Un solo pase unificado de calidad.

4. **`/yolo` para tareas mecánicas**: Si el plan está aprobado, no pierdas tiempo validando paso a paso.

5. **`/idea` preserva el foco**: Capturar y seguir es mejor que interrumpir.

6. **`/context-snapshot` para sesiones complejas**: Si investigaste algo por 30+ minutos, vale un snapshot.

7. **Compacta en puntos naturales**: Después de cada tarea completada, no cuando te quedas sin tokens.

8. **Subagentes para búsquedas**: `/parallel-search` y `/analyze-impact` no consumen contexto principal.
