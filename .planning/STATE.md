# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 5 — Visualizaciones Categorías

## Current Position

Phase: 5 of 8 (Visualizaciones Categorías)
Plan: Not started
Status: Ready to plan
Last activity: 2026-01-15 — Fase 4 completada (TabView configurable)

Progress: ██████████ 100% (Fase 4)

---

## Fase 4 completada: Panel y Navegación ✅

### TabView Configurable (Sesión 2026-01-15)

**Commits realizados:**
1. `17ef9ab` - feat(tabbar): Añadir modelo TabBarConfiguration para tabs configurables
2. `4b31e43` - feat(tabbar): Integrar TabBarConfiguration en MainTabView
3. `9375882` - feat(tabbar): Añadir TabBarConfigView para configurar tabs
4. `e424d90` - feat(tabbar): Añadir entrada de configuración en ProfileView
5. `3119903` - feat(tabbar): Mostrar tabs ocultos en vista Más
6. `d15d984` - feat(tabbar): Mover config a Personalización y añadir reordenamiento
7. `78cda31` - fix(tabbar): Usar List con EditMode para reordenamiento funcional
8. `fa2527a` - fix(tabbar): Corregir parpadeo y navegación temporal desde Más
9. `8787bab` - fix(tabbar): Mejorar animaciones de tabs temporales y sheets
10. `c6d44ba` - fix(tabbar): Intentar mitigar parpadeo en sheet de ProfileView

**Funcionalidad completa:**

**Configuración de tabs:**
- Acceso: Perfil → Personalización → Personalizar navegación
- Sección "Tabs activos": reordenables con drag & drop
- Sección "Disponibles": tabs ocultos que se pueden añadir
- Validación: mínimo 1, máximo 3 tabs activos
- Persistencia en @AppStorage

**Navegación desde "Más":**
- Tabs ocultos aparecen en vista "Más" con navegación directa
- Tab temporal: aparece en TabView mientras está activo
- Se limpia automáticamente al navegar a otro tab permanente
- Profile funciona como sheet (sin cambios)

**Archivos clave:**
```
Neto/App/Models/TabBarConfiguration.swift        # Modelo con activeTabs, inactiveTabs
Neto/App/Models/SessionState.swift               # +temporaryTab para navegación temporal
Neto/App/ContentView.swift                       # MainTabView dinámico + MorePlaceholderView
Neto/App/Views/Settings/TabBarConfigView.swift   # Sheet de configuración con reordenamiento
Neto/App/Views/Settings/PersonalizationSettingsView.swift  # Entrada a config
```

**Limitaciones conocidas:**
- Parpadeo leve al cerrar sheets (limitación de SwiftUI, no resuelto)

---

### Widget de Presupuestos (Sesión anterior)

**Widget en Panel:**
- Muestra budgets favoritos ordenados por `favoriteOrder`
- Soporte `.medium` (top 3) y `.large` (top 5)
- Empty states con botón "Seleccionar favoritos"
- Tap en budget aplica sus filtros globalmente

**Gestión de favoritos:**
- `BudgetsFavoritesSettingsView` en Profile → Organización
- Toggle estrella + reordenamiento drag & drop
- Refresco inmediato del widget

---

### Chevron en widgets ✅

- Widgets navegan a detalle al tocar chevron

---

## Completed (Fases 1-4) ✅

| Fase | Nombre | Completado |
|------|--------|------------|
| 1 | Estabilidad Core | 2026-01-13 |
| 2 | Periodos y Filtros | 2026-01-14 |
| 3 | Gestión Categorías | 2026-01-14 |
| 4 | Panel y Navegación | 2026-01-15 |

## Next Phase: Fase 5 — Visualizaciones Categorías

Según ROADMAP.md:
- Pie de etiquetas en carrusel
- Var% vs periodo anterior en barras
- Carrusel naturaleza compacto con variación

## Risk/Notes

- `selectedSubcategoryIDs` usa `PersistentIdentifier` para evitar duplicados por nombre
- `temporaryTab` en SessionState para navegación desde "Más"
- Parpadeo de sheets es limitación de SwiftUI, no crítico
- cornerRadius: 24 es el estándar para botones/cards

## Session Continuity

Last session: 2026-01-15 14:00
Stopped at: Fase 4 completada
Next step: Planificar Fase 5 (Visualizaciones Categorías)
Resume file: None
