# Visual Audit Report — 2026-03-22

## Metodología
Auditoría visual navegando ~36 pantallas en simulador iPhone 17 Pro usando `agent-device` + XcodeBuildMCP screenshots. App en estado post-onboarding con 1 cuenta (Cuenta Principal, PEN) y sin transacciones.

---

## Hallazgos

### ALTO — Errores de texto

| # | Pantalla | Hallazgo | Archivo | Fix |
|---|----------|----------|---------|-----|
| V-1 | Estadísticas → Resumen | **"Sin datos aun"** — falta tilde en "aún" | `es.lproj/Localizable.strings:876` key `insights.emptyTitle` | Cambiar a `"Sin datos aún"` |
| V-2 | Notificaciones → Resumen semanal | **"tu gastos"** — error gramatical. Template `"Cada %2$@ recibirás tu %1$@ de la semana"` con %1$@ = "gastos" produce "tu gastos" | `es.lproj/Localizable.strings:2352` key `notifications.weeklyReport.hint` | Reformular: `"Cada %2$@ recibirás un resumen de %1$@ de la semana"` o similar que funcione con todos los dataTypes (saldo, gastos, ingresos, categoría con más gasto) |

### MEDIO — UI/UX

| # | Pantalla | Hallazgo | Impacto |
|---|----------|----------|---------|
| V-3 | Notificaciones | **Títulos de notificación truncados** — "Resumen men...", "Pagos planific..." se cortan en la lista | Legibilidad reducida. Considerar layout multiline o títulos más cortos |
| V-4 | Divisa y Cambio | **Banderas de divisa muestran "?"** — iconos de bandera no renderizan correctamente (2 cuadrados con "?" por cada divisa) | Verificar en dispositivo real. Si es solo simulador, ignorar. Si es general, revisar emoji de banderas en CurrencyCode |
| V-5 | Notificaciones → Resumen semanal | **"Categoría Con Más Gasto"** — capitalización inconsistente en el selector ¿Qué quieres ver? | Los otros ítems son "Saldo", "Gastos", "Ingresos" (una palabra). Este usa title case completo. Considerar renombrar a "Top categoría" o "Categoría principal" |

### BAJO — Observaciones menores

| # | Pantalla | Hallazgo |
|---|----------|----------|
| V-6 | Panel → Widgets vacíos | Empty states usan texto inline, no `YalaEmptyState` component — consistencia variable entre widgets |
| V-7 | Panel | Banner Pro upsell siempre visible — no se puede cerrar definitivamente (diseño intencional?) |
| V-8 | Siri Tip | Card de Siri siempre visible en Panel — se puede cerrar pero reaparece |

---

## Pantallas Auditadas (36)

### Panel (7 pantallas)
1. **Panel principal** — Header, cuentas, Siri tip, Pro upsell banner ✅
2. **Panel widgets parte 1** — Tendencia de Saldo, Flujo neto, Categorías (empty states) ✅
3. **Panel widgets parte 2** — Top subcategorías (con chips filtro), Últimos registros ✅
4. **Panel widgets parte 3** — Fondo del scroll ✅
5. **FAB expandido** — Voz (PRO), Imagen (PRO), Manual ✅
6. **Búsqueda (campo)** — Empty state, campo búsqueda inferior ✅
7. **Búsqueda (vista completa)** — Título "Buscar", empty state ✅

### Estadísticas (3 pantallas)
8. **Resumen** — Coach mark, empty state ⚠️ V-1
9. **Tendencias** — Tendencia de Saldo, Flujo de Efectivo (empty) ✅
10. **Categorías** — Análisis del gasto, Necesidades (empty) ✅

### Planificación (2 pantallas)
11. **Presupuestos** — Filtros Semanal/Mensual/Anual/Único, empty state ✅
12. **Pagos planificados** — Resumen PEN 0, lista/calendario, empty state ✅

### Más (1 pantalla)
13. **Más** — Registros, Reporte, Perfil ✅

### Registros (1 pantalla)
14. **Registros** — Empty state, filtros, toolbar ✅

### Reporte Financiero (2 pantallas)
15. **Comparativa** — Filtros Tipo/Profundizar, empty state ✅
16. **Flujo de caja** — Empty state ✅

### Nuevo Registro (3 pantallas)
17. **Coach marks** — "Tres tipos de registro" (1/3) ✅
18. **Gasto** — Formulario completo, monto rosa, acciones ✅
19. **Ingreso** — Monto púrpura, sin Calcular ✅
20. **Transferencia** — Cuenta origen/destino, sin categoría ✅

### Perfil (4 pantallas)
21. **Perfil parte superior** — Avatar, nombre, Organización ✅
22. **Perfil parte media** — Preferencias, Funcionalidades IA (badges PRO) ✅
23. **Perfil parte inferior** — Datos, Seguridad ✅
24. **Perfil fondo** — Ayuda, Legal, versión ✅

### Perfil → Organización (2 pantallas)
25. **Cuentas** — Lista con Cuenta Principal ✅
26. **Categorías** — 11 categorías con iconos/colores ✅
27. **Etiquetas** — Empty state ✅

### Perfil → Preferencias (4 pantallas)
28. **Personalización parte 1** — Modo uso, Interfaz ✅
29. **Personalización parte 2** — Calendario, Indicadores ✅
30. **Notificaciones** — Lista tipos con toggles ⚠️ V-3
31. **Resumen semanal config** — Hora, contenido, día ⚠️ V-2, V-5

### Perfil → Preferencias (2 pantallas)
32. **Icono de aplicación** — 4 opciones (1 free + 3 PRO) ✅
33. **Temas** — 6 opciones (3 free + 3 PRO) ✅

### Perfil → Datos (1 pantalla)
34. **Sincronización iCloud** — Estado "Sin cuenta iCloud", warning ✅
35. **Divisa y Cambio** — Divisa preferida, tipos cambio ⚠️ V-4

### Perfil → Seguridad (1 pantalla)
36. **Yala Pro (Suscripciones)** — Paywall, features, planes Anual/Mensual ✅

---

## Resumen

| Severidad | Cantidad | Acción requerida |
|-----------|----------|------------------|
| ALTO | 2 | Fix antes de release (errores de texto visibles) |
| MEDIO | 3 | Evaluar para release o post-release |
| BAJO | 3 | Observaciones de mejora futura |

### Impresión general
La app se ve **profesional y pulida**. El Design System es consistente, los colores de marca son atractivos, y el flujo de navegación es claro. Las pantallas de suscripción y paywall son especialmente bien diseñadas. Los hallazgos son principalmente de copy/texto, no de diseño visual.

### Fixes prioritarios para release
1. `insights.emptyTitle`: "Sin datos aun" → "Sin datos aún" (1 línea, 6 locales)
2. `notifications.weeklyReport.hint`: reformular template para evitar "tu gastos" (1 línea, 6 locales)
