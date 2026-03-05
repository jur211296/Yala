# Architectural Decisions Record

Este archivo preserva decisiones de diseño importantes con su contexto y razonamiento.

## Formato de Decisiones

Cada decisión sigue esta estructura:

### [FECHA] [TÍTULO BREVE]
**Contexto:** ¿Qué situación o problema motivó esta decisión?
**Decisión:** ¿Qué se decidió hacer?
**Razones:** ¿Por qué esta opción y no las alternativas?
**Consecuencias:** ¿Qué implicaciones tiene esta decisión?
**Estado:** [Activa | Superada | Pendiente revisar]

---

## Decisiones Activas

### [2026-01-30] Widget de Tipo de Cambio: Single Source of Truth

**Contexto:** El widget de tipo de cambio tenía un sistema complejo de 3 niveles de prioridad: (1) selección manual local en cache, (2) secondaryCurrencies de Settings/onboarding, (3) defaults hardcodeados (USD, EUR). Además incluía un selector de divisas con sheet que era redundante con la configuración en Settings.

**Decisión:** Simplificar a usar ÚNICAMENTE `secondaryCurrencies` (UserDefaults) como fuente de verdad. Eliminar selector de divisas del widget, cache local, y defaults hardcodeados. Mostrar estado vacío cuando no hay divisas secundarias seleccionadas.

**Razones:**
- Elimina confusión sobre cuál es la configuración activa (ahora solo hay una fuente)
- Reduce duplicación de UI (configuración solo en Settings, no en widget)
- Evita inconsistencias entre lo que el usuario configuró y lo que ve
- Hace el widget reactivo automáticamente a cambios en Settings
- Simplifica el código eliminando 152 líneas (sheet, cache, lógica de prioridades)

**Consecuencias:**
- Widget ahora requiere que el usuario configure divisas secundarias en onboarding o Settings
- Si no hay configuración, se muestra estado vacío con indicación de dónde configurar
- Configuración centralizada en un solo lugar (mejor UX)
- Widget totalmente automático (no requiere interacción del usuario)

**Estado:** Activa

---

### [2026-02-02] iCloud Sync: Integración Nativa SwiftData + CloudKit

**Contexto:** Implementar sincronización de datos entre dispositivos del usuario. Se evaluaron dos enfoques: (1) integración nativa SwiftData + CloudKit con `cloudKitDatabase: .private()`, (2) implementación manual con CKSyncEngine.

**Decisión:** Usar integración nativa SwiftData + CloudKit.

**Razones:**
- SwiftData maneja automáticamente push, pull y conflict resolution
- Conflict resolution "last-writer-wins" es suficiente para finanzas personales (no hay edición colaborativa)
- Reduce complejidad de implementación significativamente
- Apple recomienda este enfoque para apps nuevas

**Consecuencias:**
- Requiere que TODAS las relaciones sean opcionales (CloudKit limitation)
- `Subcategory.category` cambió de `Category` a `Category?` - impacto en ~50 archivos
- Se agregó helper `safeCategory` para acceso seguro en código existente
- `ExchangeRate.dateKey` perdió `@Attribute(.unique)` - deduplicación manejada en servicio
- Usuario debe reiniciar app al cambiar preferencia de sync (ModelContainer es inmutable)
- Toggle de iCloud sync está desactivado por defecto (opt-in)

**Estado:** Activa

---

### [2026-02-08] Dark Mode: De Deep Slate Blue a Negro Puro

**Contexto:** El dark mode usaba tonalidades "deep slate blue" (azul oscuro) que no se alineaban con el estándar iOS de fondos negros puros para OLED.

**Decisión:** Cambiar `deepSlate` de `#0F172A` a `#000000` (negro puro) y `yalaCard` dark de `rgb(0.11, 0.16, 0.28)` ≈ `#1C2847` a `#1C1C1E` (`UIColor.secondarySystemBackground` dark).

**Razones:**
- Negro puro aprovecha pantallas OLED (píxeles apagados = ahorro de batería)
- Consistencia con el estándar visual de iOS en dark mode
- Elimina el tinte azul que no aportaba valor funcional

**Colores azules preservados para futuro tema "Azul" (Fase 11):**
| Token | Valor original | Descripción |
|-------|---------------|-------------|
| `deepSlate` | `#0F172A` | Background principal dark |
| `yalaCard` dark | `rgb(0.11, 0.16, 0.28)` ≈ `#1C2847` | Superficie cards/modales dark |

**Consecuencias:**
- 226+ vistas actualizan automáticamente vía colores semánticos (`yalaBackground`, `yalaCard`)
- Sin cambios en light mode
- Colores azules documentados aquí para reutilizar en sistema de temas

**Estado:** Activa

---

### [2026-03-05] Filtros Excluir: Income/Expense siempre usa semántica de inclusión

**Contexto:** Al implementar modo excluir en filtros, se evaluó si el chip Income/Expense debería soportar exclusión.

**Decisión:** Income/Expense (TransactionNature) siempre usa semántica de inclusión. La sección se oculta en modo excluir.

**Razones:**
- Excluir "Income" equivale a incluir "Expense" — no añade capacidad nueva
- UI más simple al no mostrar una opción que no aporta valor en modo excluir
- Evita confusión semántica ("excluir ingresos" vs "mostrar solo gastos")

**Estado:** Activa

---

### [2026-03-05] Filtros Excluir: Amount y Search siempre usan semántica de inclusión

**Contexto:** Se evaluó si los filtros de monto y búsqueda de texto deberían invertirse en modo excluir.

**Decisión:** Solo filtros basados en `Set<PersistentIdentifier>` y `Set<CurrencyCode>`/`Set<SubcategoryNature>` soportan exclusión. Amount y Search mantienen semántica de inclusión siempre.

**Razones:**
- Invertir "monto > 100" a "excluir monto > 100" es confuso y poco intuitivo
- Invertir búsqueda de texto ("excluir notas que contengan X") tiene uso marginal
- Consistencia: los filtros de valor/texto funcionan igual independientemente del modo

**Estado:** Activa

---

### [2026-03-05] Filtros Excluir: Limpiar selecciones al cambiar modo

**Contexto:** Al cambiar entre incluir↔excluir, se evaluó si preservar o limpiar las selecciones activas.

**Decisión:** Limpiar todas las selecciones de filtros de entidad al cambiar de modo.

**Razones:**
- Preservar selecciones invierte la intención (lo que antes incluías ahora lo excluyes)
- Limpiar es más seguro y predecible — el usuario siempre parte de estado conocido
- Evita resultados inesperados donde el usuario no entiende por qué ve ciertos datos

**Estado:** Activa

---

## Decisiones Superadas

[Decisiones que ya no aplican pero queremos preservar el razonamiento histórico]
