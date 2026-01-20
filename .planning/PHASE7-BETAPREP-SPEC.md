# Fase 7: Beta Preparation - Especificación Técnica (V1.0)

## Overview

**Objetivo**: Preparar Neto V1.0 para release público en TestFlight con beta testers externos.

**Principio**: Las features están completas. Esta fase se enfoca en calidad, estabilidad y preparación para usuarios reales.

## Subfases

---

## 7.1: Code Quality & Cleanup

### Objetivos
- Código limpio y mantenible
- Cero warnings en build
- Consistencia total en nombres y convenciones

### Tareas

| Tarea | Descripción | Herramienta |
|-------|-------------|-------------|
| TODOs/FIXMEs | Buscar y resolver o documentar | `grep -r "TODO\|FIXME"` |
| Código muerto | Eliminar funciones/vistas no usadas | Xcode + búsqueda manual |
| Código comentado | Eliminar o restaurar | Revisión manual |
| Imports no usados | Limpiar imports innecesarios | Xcode warnings |
| Warnings | Resolver todos los warnings del compilador | Xcode build |

### Revisión de Naming Conventions (IMPORTANTE)

Revisar TODOS los archivos para consistencia de nombres:

| Elemento | Convención | Ejemplo |
|----------|------------|---------|
| Clases/Structs | PascalCase | `TransactionItem`, `PanelViewModel` |
| Funciones/Métodos | camelCase, verbo primero | `fetchTransactions()`, `calculateTotal()` |
| Variables/Properties | camelCase, sustantivo | `selectedPeriod`, `isLoading` |
| Enums | PascalCase, casos camelCase | `enum PaymentType { case recurring }` |
| Protocolos | PascalCase, sufijo -able/-ing/-Protocol | `Identifiable`, `FilteringProtocol` |
| Constantes | camelCase o SCREAMING_CASE para globales | `defaultCurrency`, `MAX_ITEMS` |

**Revisión específica:**
- [ ] Enums: nombres y casos reflejan uso actual (no nombres legacy)
- [ ] ViewModels: métodos con nombres claros de acción
- [ ] Servicios: nomenclatura consistente entre todos
- [ ] Modelos SwiftData: propiedades con nombres semánticos

### Criterios de Aceptación
- [ ] `grep -r "TODO\|FIXME" Neto/` devuelve 0 resultados (o todos documentados)
- [ ] Build sin warnings
- [ ] No hay bloques de código comentado
- [ ] Nombres de funciones/enums revisados y consistentes

---

## 7.2: Performance & Optimización

### Objetivos
- App fluida en dispositivos reales
- Sin memory leaks
- Tiempos de carga aceptables

### Tareas

| Tarea | Descripción | Herramienta |
|-------|-------------|-------------|
| Profiling general | Medir CPU/memoria en flujos principales | Instruments - Time Profiler |
| Memory leaks | Detectar y corregir leaks | Instruments - Leaks |
| SwiftData queries | Verificar no hay N+1 restantes | Logging + revisión |
| Lazy loading | Implementar donde aplique (listas largas) | SwiftUI LazyVStack |
| View body complexity | Reducir cálculos en body de vistas | Revisión manual |

### Flujos a Profilar
1. Panel → scroll de widgets
2. Statistics → cambio entre tabs
3. Records → scroll con muchos registros
4. Filtros → aplicar/quitar filtros
5. Gráficas → interacción con tooltips

### Criterios de Aceptación
- [ ] No hay memory leaks detectados en flujos principales
- [ ] Scroll fluido (60fps) en listas de 500+ items
- [ ] Tiempo de carga inicial < 2s en iPhone 12+

---

## 7.3: Localizaciones y Monedas

### Objetivos
- Cero strings hardcodeados
- Todas las keys en 6 idiomas
- Formatos correctos por locale
- Monedas adicionales para beta testers internacionales

### Idiomas Soportados
1. Español (es) - Base
2. Inglés (en)
3. Francés (fr)
4. Alemán (de)
5. Italiano (it)
6. Portugués (pt-BR)

### Monedas Actuales
- PEN (Sol peruano) - default
- USD (Dólar estadounidense)
- EUR (Euro)

### Monedas a Añadir

| Código | Moneda | Bandera | Tasa aprox vs PEN |
|--------|--------|---------|-------------------|
| **MXN** | Peso mexicano | 🇲🇽 | ~0.22 |
| **COP** | Peso colombiano | 🇨🇴 | ~0.0009 |
| **BRL** | Real brasileño | 🇧🇷 | ~0.75 |
| **GBP** | Libra esterlina | 🇬🇧 | ~4.70 |

**Archivos a modificar por moneda:**
```
CurrencyUtils.swift:
  - CurrencyCode enum (añadir caso)
  - normalizeCurrencyCode() (añadir aliases)
  - rateToPEN() (añadir tasa fallback)
  - currencyInfo() (añadir nombre + bandera)

L10n.swift:
  - Currency namespace (añadir key)

Localizable.strings (x6 idiomas):
  - Añadir "currency.XXX" = "Nombre de la moneda"
```

### Tareas de Localización

| Tarea | Descripción | Herramienta |
|-------|-------------|-------------|
| Auditoría hardcodes | Buscar strings literales en vistas | Script + revisión |
| Keys faltantes | Comparar .strings entre idiomas | Script de comparación |
| Pluralizaciones | Verificar .stringsdict donde aplique | Revisión manual |
| Formatos números | Verificar uso de formatters localizados | Revisión código |
| Formatos fechas | Verificar DateFormatter con locale | Revisión código |
| Añadir monedas | MXN, COP, BRL, GBP | CurrencyUtils + L10n |

### Script de Auditoría (sugerido)
```bash
# Buscar strings literales en vistas SwiftUI
grep -rn 'Text("' Neto/Views/ | grep -v 'Text(String(localized'
grep -rn '\.navigationTitle("' Neto/Views/
```

### Criterios de Aceptación
- [ ] Auditoría de hardcodes: 0 encontrados
- [ ] Todas las keys existen en los 6 archivos .strings
- [ ] App probada en al menos 2 idiomas diferentes

---

## 7.4: Testing & QA

### Objetivos
- Documento de escenarios de prueba manual
- Casos edge documentados y probados
- Cobertura de unit tests revisada

### Documento de Escenarios

Crear archivo: `.planning/QA-SCENARIOS.md`

**Estructura por módulo:**
```markdown
## [Nombre del Módulo]

### Escenario: [Nombre descriptivo]
**Precondiciones:** [Estado inicial requerido]
**Pasos:**
1. [Paso 1]
2. [Paso 2]
**Resultado esperado:** [Qué debe pasar]
**Casos edge:**
- [Variante 1]
- [Variante 2]
```

### Módulos a Cubrir
1. **Transacciones**: Crear, editar, eliminar, transferencias
2. **Cuentas**: CRUD, balances, multimoneda
3. **Categorías**: CRUD, subcategorías, iconos/colores
4. **Presupuestos**: CRUD, tracking, alertas
5. **Filtros**: Periodo, categorías, cuentas, etiquetas, notas
6. **Estadísticas**: Trends, Categories, Records
7. **Panel**: Widgets, navegación, periodo
8. **Pagos Planificados**: CRUD, calendario, widget
9. **Importación**: CSV, multimoneda
10. **Configuración**: Preferencias, personalización

### Casos Edge Prioritarios
- App con 0 datos (empty states)
- App con muchos datos (1000+ transacciones)
- Valores extremos (montos muy grandes/pequeños)
- Fechas límite (inicio/fin de mes, año)
- Cambio de idioma en runtime
- Cambio de moneda principal
- Eliminación en cascada (categoría con transacciones)

### Criterios de Aceptación
- [ ] QA-SCENARIOS.md creado con todos los módulos
- [ ] Al menos 3 escenarios por módulo
- [ ] Casos edge documentados y probados

---

## 7.5: UX para Nuevos Usuarios

### Objetivos
- Empty states informativos en todas las vistas
- Textos de ayuda donde sea necesario
- Primera experiencia clara

### Empty States a Revisar

| Vista | Estado actual | Acción |
|-------|---------------|--------|
| Panel (sin transacciones) | ? | Verificar mensaje + CTA |
| Records (sin registros) | ? | Verificar mensaje + CTA |
| Trends (sin datos) | ? | Verificar mensaje |
| Categories (sin gastos) | ? | Verificar mensaje |
| Presupuestos (vacío) | ? | Verificar mensaje + CTA |
| Pagos Planificados (vacío) | ? | Verificar mensaje + CTA |
| Cuentas (solo default) | ? | Verificar mensaje |
| Etiquetas (vacío) | ? | Verificar mensaje + CTA |

### Textos de Ayuda en Settings

Revisar secciones de configuración que podrían beneficiarse de texto explicativo:
- Moneda principal (qué implica cambiarla)
- Primer día de semana (efecto en gráficas)
- Widgets del panel (cómo personalizarlos)
- Exportar/Importar (formatos soportados)

### Criterios de Aceptación
- [ ] Todos los empty states tienen mensaje útil
- [ ] CTAs claros donde aplique ("Crear primera transacción")
- [ ] Textos de ayuda en configuraciones clave

---

## 7.6: Preparación App Store

### Objetivos
- Assets listos para App Store Connect
- Metadata en todos los idiomas
- Privacy policy publicada

### Assets Requeridos

**Screenshots (por idioma):**
| Tamaño | Dispositivo | Cantidad |
|--------|-------------|----------|
| 6.7" | iPhone 15 Pro Max | 5-10 |
| 6.5" | iPhone 14 Plus | 5-10 |
| 5.5" | iPhone 8 Plus | 5-10 (opcional) |

**Pantallas sugeridas:**
1. Panel principal con widgets
2. Estadísticas - gráfica de tendencias
3. Estadísticas - pie de categorías
4. Lista de transacciones con filtros
5. Presupuestos con progreso
6. Pagos planificados con calendario

**App Icon:**
- Verificar que existe en todos los tamaños
- Verificar versión para App Store (1024x1024)

### Metadata

| Campo | Caracteres | Notas |
|-------|------------|-------|
| App Name | 30 | "Neto - Finanzas Personales" |
| Subtitle | 30 | "Gastos, presupuestos y más" |
| Keywords | 100 | Separados por coma |
| Description | 4000 | Descripción completa |
| What's New | 4000 | Para updates |
| Promotional Text | 170 | Puede cambiar sin review |

### Privacy Policy
- [ ] URL pública con política de privacidad
- [ ] Mencionar uso de CloudKit (sync)
- [ ] Declarar que no se comparten datos con terceros

### Criterios de Aceptación
- [ ] Screenshots generados para 2+ tamaños
- [ ] Metadata escrito en español (base)
- [ ] Privacy policy URL funcional

---

## 7.7: Estabilidad Pre-Release

### Objetivos
- Error handling robusto
- Validaciones completas
- Comportamiento offline predecible

### Error Handling

Revisar manejo de errores en:
- Operaciones SwiftData (save, delete, fetch)
- Importación de CSV
- Cálculos con datos faltantes
- Navegación con datos inválidos

### Validaciones de Datos

| Entidad | Validaciones |
|---------|--------------|
| TransactionItem | amount != 0, account != nil, subcategory != nil |
| Account | name no vacío, currency válida |
| Category | name no vacío, al menos 1 subcategoría |
| Budget | amount > 0, categorías seleccionadas |
| ScheduledPayment | campos requeridos completos |

### Comportamiento Offline

- [ ] App funciona sin conexión (SwiftData local)
- [ ] Sync con CloudKit cuando hay conexión
- [ ] No hay crashes por falta de red

### Migración de Datos

- [ ] Verificar que migraciones existentes funcionan
- [ ] Probar upgrade desde versión anterior (si aplica)
- [ ] Datos de prueba no quedan en release

### Criterios de Aceptación
- [ ] No hay crashes en flujos principales
- [ ] Validaciones previenen datos inválidos
- [ ] App usable sin conexión

---

## 7.8: Primer Uso y Onboarding Básico

### Objetivos
- App lista para usuarios que nunca la han usado
- Defaults sensatos según contexto del usuario
- Onboarding mínimo para capturar preferencias esenciales

### Detección de Idioma del Sistema

```swift
// Leer idioma preferido del sistema
let preferredLanguage = Locale.preferredLanguages.first ?? "en"
let languageCode = Locale(identifier: preferredLanguage).language.languageCode?.identifier ?? "en"

// Mapear a idiomas soportados
let supportedLanguages = ["es", "en", "fr", "de", "it", "pt"]
let appLanguage = supportedLanguages.contains(languageCode) ? languageCode : "en"
```

### Onboarding Flow (MUY básico)

**Pantalla 1: Bienvenida**
- Logo + nombre de la app
- "Configura tu experiencia en 30 segundos"
- Botón "Comenzar"

**Pantalla 2: Tu nombre**
- Campo de texto: "¿Cómo te llamas?"
- Placeholder: "Tu nombre"
- Se usa para personalizar la app (ej: "Hola, Juan")
- Botón "Continuar" (puede omitirse)

**Pantalla 3: Tu moneda**
- "¿Cuál es tu moneda principal?"
- Lista de monedas con banderas (PEN, USD, EUR, MXN, COP, BRL, GBP)
- Pre-seleccionar según región del dispositivo:
  - Perú → PEN
  - México → MXN
  - Colombia → COP
  - Brasil → BRL
  - España → EUR
  - UK → GBP
  - USA/Default → USD
- Botón "Continuar"

**Pantalla 4: Listo**
- "¡Todo listo!"
- Resumen de configuración
- "Puedes cambiar esto en Configuración"
- Botón "Empezar a usar Neto"

### Defaults Según Contexto

| Setting | Default | Lógica |
|---------|---------|--------|
| Idioma | Sistema | `Locale.preferredLanguages` |
| Moneda | Por región | `Locale.current.region` |
| Primer día semana | Por región | Lunes (mayoría) o Domingo (USA) |
| Nombre usuario | nil | Capturado en onboarding |

### Detección de Región para Moneda

```swift
func suggestedCurrency() -> CurrencyCode {
    let region = Locale.current.region?.identifier ?? ""
    switch region {
    case "PE": return .pen
    case "MX": return .mxn
    case "CO": return .cop
    case "BR": return .brl
    case "ES", "FR", "DE", "IT", "PT": return .eur
    case "GB": return .gbp
    default: return .usd
    }
}
```

### Persistencia de Primer Uso

```swift
enum OnboardingState {
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
    }
}
```

### Criterios de Aceptación
- [ ] Onboarding se muestra solo en primer uso
- [ ] Idioma se detecta del sistema
- [ ] Moneda se sugiere según región
- [ ] Usuario puede omitir nombre
- [ ] Configuración se persiste correctamente
- [ ] Usuario puede cambiar todo después en Settings

---

## Orden de Ejecución Sugerido

1. **7.1 Code Quality** - Limpiar antes de optimizar
2. **7.3 Localizaciones + Monedas** - Añadir monedas, detectar hardcodes
3. **7.2 Performance** - Optimizar código limpio
4. **7.8 Primer Uso** - Onboarding y defaults
5. **7.5 UX Nuevos Usuarios** - Mejorar empty states
6. **7.7 Estabilidad** - Solidificar antes de testing
7. **7.4 Testing & QA** - Documentar y probar
8. **7.6 App Store** - Preparar para submit

---

## DoD General (Fase 7 Completa)

- [ ] Build sin warnings
- [ ] Nombres de funciones/enums consistentes y actualizados
- [ ] Cero strings hardcodeados
- [ ] 7 monedas soportadas (PEN, USD, EUR, MXN, COP, BRL, GBP)
- [ ] Onboarding básico funcionando (nombre + moneda)
- [ ] Defaults detectados del sistema (idioma, región)
- [ ] QA-SCENARIOS.md completo y ejecutado
- [ ] Empty states revisados
- [ ] Screenshots y metadata listos
- [ ] App estable para beta testers externos
- [ ] TestFlight build subido y distribuido

---

*Documento creado: 2026-01-20*
*Última actualización: 2026-01-20*
