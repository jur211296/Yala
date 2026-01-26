# Refinamientos de Flujo UX (Subfases 8.3 + 8.4)

**Creado:** 2026-01-25
**Alcance:** Flujo completo desde FAB hasta aprobación de draft

---

## 1. FAB MENU (Punto de entrada)

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 1.1 | Orden de opciones en menú (¿Voz→Imagen→Manual?) | UX | ❌ Descartado (orden actual OK) |
| 1.2 | Feedback/transición al seleccionar opción | UX | ❌ Descartado (animación actual OK) |

---

## 2. VOZ: VoiceRecordingView

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 2.1 | Sin monto detectado → ¿permitir crear draft igual para editar después? | UX | ❌ Descartado |
| 2.2 | Confirmación antes de procesar (preview duración) | UX | ✅ Completado |
| 2.3 | Cancelar durante procesamiento STT/LLM | UX | ✅ Completado |
| 2.4 | Múltiples drafts de una grabación ("50 en café y 100 en uber") | Feature | Pendiente |
| 2.5 | Retry después de error sin cerrar la vista | UX | ✅ Completado |

---

## 3. IMAGEN: ImageSelectionView

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 3.1 | Preview de imagen mientras procesa | UX | ✅ Completado (fbff205) |
| 3.2 | Contador de drafts detectados antes de navegar | UX | ✅ Completado (7b65b05) |
| 3.3 | Sin transacciones → ¿crear draft manual con imagen como referencia? | UX | ❌ Descartado (solo mostrar mensaje) |
| 3.4 | Cancelar durante procesamiento OCR | UX | ✅ Completado (fbff205) |
| 3.5 | Selección múltiple de imágenes | Feature | Pendiente |

---

## 4. CREACIÓN DEL DRAFT

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 4.1 | Currency sin cuenta match → ¿guardar hint para mostrar al usuario? | Lógica | Pendiente |
| 4.2 | Subcategoría ambigua → ¿mostrar sugerencias? | Lógica | Pendiente |
| 4.3 | Tags nuevos creados automáticamente → ¿informar al usuario? | UX | ✅ Completado (badge "Nuevo") |
| 4.4 | Evidence/rawText accesible para verificar extracción | UX | Pendiente |

---

## 5. NAVEGACIÓN POST-CREACIÓN

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 5.1 | 1 draft → edit sheet directo vs ir a Inbox siempre | UX | ✅ Ya implementado (voz e imagen) |
| 5.2 | N drafts → alert con opciones | UX | Implementado |
| 5.3 | Toast/confirmación visual de draft creado | UX | ✅ Ya implementado (edit sheet o result view) |
| 5.4 | Volver atrás después de crear → ¿a dónde va? ¿se pierde? | UX | ✅ Completado (d3e8c17) |

---

## 6. EDICIÓN: InboxDraftEditSheet

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 6.1 | Campos obligatorios no claros visualmente | UX | ✅ Completado (49c7abc) |
| 6.2 | Validación al intentar aprobar (mensaje o botón deshabilitado) | UX | ✅ Completado (49c7abc) |
| 6.3 | Cerrar sheet sin guardar → confirmación "¿Descartar cambios?" | Edge case | ✅ Completado (1312846) |
| 6.4 | Editar monto con signo → toggle gasto/ingreso claro | UX | ✅ Ya implementado (transactionTypeSelector) |
| 6.5 | Ver texto original (rawText) para verificar | UX | ✅ Completado |
| 6.6 | Confidence indicators → ¿son útiles para el usuario? | UX | ❌ Descartado (no mostrar al usuario) |
| 6.7 | Quick actions (duplicar draft, dividir en múltiples) | Feature | ❌ Descartado (solo en transacciones) |

---

## 7. LISTA: InboxView

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 7.1 | Ordenar por fecha de transacción, dividir por días (como RecordsTabView) | UX | ✅ Completado |
| 7.2 | Indicador visual de campos faltantes en cada celda | UX | ✅ Ya implementado |
| 7.3 | Bulk actions → ¿es descubrible? | UX | ✅ Completado (hint visual) |
| 7.4 | Filtros útiles (Pendientes/Archivados) | UX | ❌ Descartado (no filtros en bandeja) |
| 7.5 | Empty state instructivo | UX | ✅ Ya implementado |
| 7.6 | **Contador de archivados incluye eliminados** | **Bug** | ✅ Completado (41c10e3) |
| 7.7 | **Montos siempre con decimales** (consistencia con resto de app) | **Bug** | ✅ Completado (ff9bf1b) |

---

## 8. APROBACIÓN

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 8.1 | Feedback al aprobar (toast, animación) | UX | ✅ Completado |
| 8.2 | Navegación post-aprobar (¿lista? ¿cierra? ¿transacción?) | UX | ✅ Completado |
| 8.3 | Aprobar con campos mínimos (¿sin nota? ¿sin tags?) | Lógica | ✅ Ya implementado (monto+cuenta requeridos) |
| 8.4 | Aprobar múltiples (bulk) → feedback y manejo de errores | UX | ✅ Completado |
| 8.5 | Deshacer aprobación | Feature | ❌ Descartado (usuario puede eliminar transacción) |

---

## 9. ERRORES Y EDGE CASES

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 9.1 | Sin conexión (voz) → sugerir usar imagen (offline) | Error | Pendiente |
| 9.2 | API key inválida → link a Settings | Error | Pendiente |
| 9.3 | Draft huérfano si falla save | Edge case | Pendiente |
| 9.4 | Imagen corrupta → mensaje claro + reintentar | Error | Pendiente |
| 9.5 | Permisos denegados → deep link a Settings sistema | Error | Pendiente |

---

## 10. MEJORAS UI (al final)

| # | Punto | Tipo | Estado |
|---|-------|------|--------|
| 10.1 | Consistencia de colores/iconos entre Voz e Imagen | UI | Pendiente |
| 10.2 | Animaciones de transición entre estados | UI | Pendiente |
| 10.3 | Tamaños de botones y áreas touch | UI | Pendiente |
| 10.4 | Tipografía y espaciado en celdas de Inbox | UI | Pendiente |
| 10.5 | Dark mode verificar contraste | UI | Pendiente |
| 10.6 | Iconos de sourceType claros y distintivos | UI | Pendiente |
| 10.7 | Estados de carga consistentes (spinners, skeletons) | UI | Pendiente |
| 10.8 | Feedback háptico en acciones importantes | UI | Pendiente |
| 10.9 | Accesibilidad (VoiceOver labels) | UI | Pendiente |
| 10.10 | Pulido general de InboxDraftEditSheet | UI | Pendiente |

---

## Resumen Priorizado

### Bugs (arreglar primero)
- [x] 7.6 - Contador archivados incluye eliminados (41c10e3)
- [x] 7.7 - Montos sin decimales en Inbox (ff9bf1b)

### UX Crítico
- [x] 6.3 - Cerrar sheet sin guardar → confirmación (1312846)
- [x] 6.1/6.2 - Campos obligatorios claros + validación (49c7abc)
- [x] 5.4 - Navegación clara post-crear (d3e8c17)
- [x] 7.2 - Indicador de drafts incompletos (ya implementado en InboxDraftRowView)

### UX Importante
- [x] 3.1 - Preview imagen con countdown 3s antes de procesar (fbff205)
- [x] 3.2 - Contador de drafts en imagen (7b65b05)
- [x] 3.4 - Cancelar durante countdown (antes de gastar tokens) (fbff205)
- [x] 2.1 - Sin monto → permitir crear draft (descartado - re-grabar es mejor UX)
- [x] 6.5 - Ver rawText en edición
- [x] 8.1/8.2 - Feedback post-aprobar (pantalla éxito con Editar/Aceptar/Aprobar siguiente)

### Features deseables
- [ ] 2.4 - Múltiples drafts de una grabación
- [ ] 3.5 - Selección múltiple de imágenes

### UI (al final)
- [ ] 10.1-10.10 - Pulido visual general

---

*Actualizar conforme se completen items*
