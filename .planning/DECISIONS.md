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

## Decisiones Superadas

[Decisiones que ya no aplican pero queremos preservar el razonamiento histórico]
