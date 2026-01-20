# Fase 8: Registro Inteligente - Especificación Técnica (V1.1)

## Overview

**Objetivo**: Automatizar la entrada de transacciones mediante voz e imágenes, con una bandeja de borradores para revisión antes de confirmar.

**Principio core**: La cuenta define la divisa. NO se infiere moneda en ningún extractor.

## Arquitectura General

```
┌─────────────────────────────────────────────────────────────┐
│                         FUENTES                              │
├──────────────┬──────────────┬──────────────┬────────────────┤
│     VOZ      │  SCREENSHOT  │  SCREENSHOT  │    RECIBO      │
│   (Audio)    │    LIST      │   SINGLE     │    (Foto)      │
└──────┬───────┴──────┬───────┴──────┬───────┴───────┬────────┘
       │              │              │               │
       ▼              ▼              ▼               ▼
┌──────────────────────────────────────────────────────────────┐
│                    EXTRACTORES                                │
│  ┌─────────┐  ┌────────────┐  ┌────────────┐  ┌───────────┐  │
│  │  STT +  │  │  OCR +     │  │  OCR +     │  │  OCR +    │  │
│  │  LLM    │  │  Row       │  │  Pattern   │  │  Fallback │  │
│  │  Parser │  │  Clustering│  │  Matching  │  │  Cloud    │  │
│  └────┬────┘  └─────┬──────┘  └─────┬──────┘  └─────┬─────┘  │
└───────┼─────────────┼───────────────┼───────────────┼────────┘
        │             │               │               │
        ▼             ▼               ▼               ▼
┌──────────────────────────────────────────────────────────────┐
│                   MERCHANT MEMORY                             │
│         (Canonicalización + Sugerencia subcategoría)          │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                    INBOX DRAFTS                               │
│    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐     │
│    │ pending │   │ pending │   │ pending │   │ pending │     │
│    └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘     │
└─────────┼─────────────┼─────────────┼─────────────┼──────────┘
          │             │             │             │
          ▼             ▼             ▼             ▼
┌──────────────────────────────────────────────────────────────┐
│              ACCIONES USUARIO (UX)                            │
│       Aprobar  │  Editar  │  Eliminar  │  Lote               │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                  TRANSACCIONES (SwiftData)                    │
│                    TransactionItem                            │
└──────────────────────────────────────────────────────────────┘
```

---

## Módulo 1: Bandeja de Entrada (Inbox Drafts)

### Modelo de Datos

```swift
@Model
final class InboxDraft {
    // Campos del draft
    var note: String                          // Descripción/nota
    var amount: Decimal?                      // Monto con signo (nil si no detectado)
    var date: Date?                           // Fecha (nil si no detectada)
    var account: Account?                     // Requerido para aprobar
    var subcategory: Subcategory?             // Opcional
    var tags: [Tag]                           // Opcional, relación N:N

    // Metadatos de origen
    var sourceType: DraftSourceType           // voice, receiptPhoto, screenshotList, screenshotSingle, emailAlert
    var rawText: String?                      // Texto crudo OCR/STT
    var evidence: String?                     // Extracto breve que justifica la extracción

    // Confianza por campo (0.0 - 1.0)
    var confidenceAmount: Double?
    var confidenceDate: Double?
    var confidenceMerchant: Double?
    var confidenceSubcategory: Double?

    // Estado y validación
    var needsUserInput: [String]              // ["account", "amount", etc.]
    var status: DraftStatus                   // pending, approved, rejected

    // Timestamps
    var createdAt: Date
    var updatedAt: Date
}

enum DraftSourceType: String, Codable {
    case voice
    case receiptPhoto
    case screenshotList
    case screenshotSingle
    case emailAlert
}

enum DraftStatus: String, Codable {
    case pending
    case approved
    case rejected
}
```

### Reglas de Validación

| Campo | Requerido para aprobar | Notas |
|-------|------------------------|-------|
| account | **Sí** | Define la divisa |
| amount | **Sí** | Debe tener valor |
| subcategory | **Sí** | Debe asignarse |
| date | No | Default: createdAt |
| note | No | Puede estar vacío |
| tags | No | Opcional |

### UX

**Acceso**: Toolbar del Panel, lado izquierdo (junto al perfil). Badge con contador de pendientes.

**Vista lista**:
- Filtros: Pendientes (default) / Archivados (rechazados)
- Cada celda muestra: sourceType icon, nota truncada, monto (o "Sin monto"), fecha relativa
- Indicadores visuales de campos faltantes (needsUserInput)

**Acciones individuales**:
- Tap → Edición rápida (sheet con campos editables)
- Swipe left → Eliminar/Rechazar
- Swipe right → Aprobar (si válido)

**Acciones en lote**:
- Modo selección múltiple
- "Asignar cuenta a seleccionados"
- "Asignar subcategoría a seleccionados"
- "Aprobar seleccionados" (solo válidos)
- "Eliminar seleccionados"

### Persistencia

- SwiftData + CloudKit
- Migración: nueva entidad InboxDraft
- Al aprobar: crear TransactionItem y cambiar status a .approved
- Drafts aprobados/rechazados se mantienen 30 días para auditoría, luego cleanup automático

---

## Módulo 2: Ingesta de Imágenes (Clasificación + OCR)

### Pipeline

```
Imagen → OCR (Vision) → Preclasificación → Extractor específico → Draft(s)
```

### Preclasificación de Tipo de Imagen

**Heurísticas (V1)**:

| Tipo | Señales |
|------|---------|
| `screenshotList` | Múltiples líneas con montos, patrón de lista, presencia de fechas repetidas |
| `screenshotSingle` | Palabras clave: "consumo", "compra", "cargo", "aprobado", formato de alerta |
| `emailAlert` | Estructura de email, "De:", "Asunto:", patrones de notificación bancaria |
| `receiptPhoto` | Palabras: "TOTAL", "SUBTOTAL", "IVA", formato de ticket, baja densidad de texto |

**Criterios de decisión**:
```
Si múltiples_lineas_con_monto >= 3 → screenshotList
Si contiene("consumo de" | "cargo" | "compra aprobada") → screenshotSingle/emailAlert
Si contiene("TOTAL" | "SUBTOTAL") Y baja_densidad → receiptPhoto
Si ambiguo → LLM clasificador (V2)
```

**V2 (con LLM)**: Solo si heurísticas no son concluyentes. Prompt mínimo para clasificar en 4 tipos.

### Manejo de Errores

| Problema | Estrategia |
|----------|------------|
| Imagen borrosa | Detectar con Vision (blur score), mostrar warning, permitir reintento |
| Imagen recortada | Procesar lo disponible, marcar baja confianza |
| Tema oscuro | OCR generalmente funciona; si falla, invertir colores y reintentar |
| Sin texto detectado | Rechazar con mensaje "No se detectó texto" |

### Estrategia Offline

- OCR Vision funciona offline
- Clasificación heurística funciona offline
- LLM clasificador (V2) requiere conectividad → fallback a heurística
- Drafts se guardan localmente, sync con CloudKit cuando hay conexión

---

## Módulo 3: Extractor "ScreenshotList"

### Objetivo

Procesar screenshots de listas de movimientos bancarios/apps financieras y generar **N drafts** (uno por transacción visible).

### Algoritmo

```
1. Recibir resultados OCR con bounding boxes
2. Clustering por coordenada Y (agrupar texto en filas)
   - Tolerancia: ~15-20 puntos de altura
3. Para cada fila:
   a. Detectar monto (regex robusto)
   b. Detectar fecha (si existe en la fila)
   c. Resto del texto → merchant/nota
4. Si no hay fecha en fila → heredar de encabezado/contexto
5. Generar InboxDraft por fila válida
```

### Regex para Montos

```swift
// Patrones soportados:
// -$1,234.56 | $1,234.56- | ($1,234.56) | -1234.56 | 1.234,56
let amountPattern = #"""
(?<sign>-|\+)?
(?<currency>\$|€|£)?
\s*
(?<amount>[\d.,]+)
(?<trailingSign>-|\+)?
|
\((?<parenAmount>[\d.,]+)\)
"""#
```

### Manejo de Ambigüedades

| Caso | Estrategia |
|------|------------|
| Fila partida en 2 líneas | Merge si Y-gap < threshold y no hay monto en segunda línea |
| Monto sin signo | Marcar confianza media, usuario decide en bandeja |
| Fecha faltante | Usar fecha de encabezado o fecha actual |
| Múltiples montos en fila | Tomar el último (generalmente es el total) |

### Output

```swift
InboxDraft(
    note: "Starbucks Coffee",
    amount: -45.00,
    date: detectedDate ?? headerDate ?? Date(),
    account: nil,              // Usuario asigna
    subcategory: nil,          // Merchant Memory puede sugerir
    sourceType: .screenshotList,
    rawText: "Starbucks Coffee    -$45.00    10/01",
    evidence: "Fila 3 de 8",
    confidenceAmount: 0.95,
    confidenceDate: 0.85,
    confidenceMerchant: 0.90,
    needsUserInput: ["account"],
    status: .pending
)
```

### Métricas de Calidad

- % de filas correctamente detectadas (target: >90%)
- % de montos correctamente parseados (target: >95%)
- % de fechas correctamente parseadas (target: >85%)

---

## Módulo 4: Extractor "ScreenshotSingle / EmailAlert"

### Objetivo

Procesar pantallas de detalle de consumo o alertas de email/notificación y generar **1 draft**.

### Patrones Soportados

**Alertas bancarias**:
```
"Consumo de $XXX en MERCHANT"
"Compra aprobada por $XXX"
"Cargo de $XXX - MERCHANT"
"Tu tarjeta *1234 - Compra $XXX"
```

**Fechas**:
```
"10 de enero de 2026"
"10/01/2026"
"2026-01-10"
"10:25 AM" (hora, fecha de hoy)
"Hoy", "Ayer" → resolver a fecha absoluta
```

**Merchants**:
```
"Establecimiento: MERCHANT"
"Comercio: MERCHANT"
Texto dominante después de monto
```

### Algoritmo

```
1. Buscar patrón de monto con contexto ("consumo de", "compra", etc.)
2. Extraer fecha si existe (múltiples formatos)
3. Extraer merchant del contexto
4. Si fecha es relativa ("hoy", "ayer") → resolver
5. Generar InboxDraft
```

### Manejo de Fechas Relativas

```swift
func resolveRelativeDate(_ text: String, referenceDate: Date = Date()) -> Date? {
    let lower = text.lowercased()
    if lower.contains("hoy") || lower.contains("today") {
        return referenceDate
    }
    if lower.contains("ayer") || lower.contains("yesterday") {
        return Calendar.current.date(byAdding: .day, value: -1, to: referenceDate)
    }
    return nil
}
```

### Output

```swift
InboxDraft(
    note: "Uber Eats - Pedido #12345",
    amount: -89.50,
    date: Date(), // Detectada o inferida
    account: nil,
    subcategory: nil, // Merchant Memory puede sugerir
    sourceType: .screenshotSingle, // o .emailAlert
    rawText: "Consumo de $89.50 en Uber Eats...",
    evidence: "Patrón 'Consumo de $X en Y'",
    confidenceAmount: 0.98,
    confidenceDate: 0.70, // Fecha relativa
    confidenceMerchant: 0.95,
    needsUserInput: ["account"],
    status: .pending
)
```

---

## Módulo 5: Extractor "ReceiptPhoto" + Fallback Cloud

### Objetivo

Procesar fotos de recibos/tickets y extraer total, fecha y merchant. **V1 no hace itemización**.

### Pipeline

```
Foto → OCR Vision → Buscar TOTAL/fecha/merchant
                          ↓
                   ¿Confianza suficiente?
                          ↓
              Sí ────────┴──────── No
              ↓                     ↓
         Generar Draft      Fallback Cloud (si habilitado)
                                    ↓
                              Generar Draft
```

### Extracción On-Device (V1)

**Total**:
```swift
// Buscar líneas con "TOTAL", "TOTAL A PAGAR", "GRAN TOTAL"
// Excluir "SUBTOTAL", "IVA", "PROPINA"
let totalPatterns = [
    #"TOTAL\s*:?\s*\$?([\d.,]+)"#,
    #"TOTAL A PAGAR\s*:?\s*\$?([\d.,]+)"#,
    #"GRAN TOTAL\s*:?\s*\$?([\d.,]+)"#
]
```

**Fecha**:
```swift
// Formatos comunes en tickets
let datePatterns = [
    #"\d{2}/\d{2}/\d{4}"#,
    #"\d{2}-\d{2}-\d{4}"#,
    #"\d{4}-\d{2}-\d{2}"#
]
```

**Merchant**: Primeras líneas del ticket (generalmente nombre del establecimiento).

### Criterios de Fallback Cloud

| Condición | Acción |
|-----------|--------|
| Total no detectado | Activar fallback |
| Confianza total < 0.6 | Activar fallback |
| Fecha no detectada Y total detectado | NO activar (fecha menos crítica) |
| Usuario deshabilitó cloud | NO activar, draft con campos faltantes |

### Proveedores Cloud (Evaluar)

| Proveedor | API | Pros | Contras |
|-----------|-----|------|---------|
| AWS Textract | AnalyzeExpense | Especializado en recibos, extrae campos estructurados | Costo por página |
| Google Document AI | Expense Parser | Alta precisión, múltiples idiomas | Costo, setup más complejo |

**Decisión**: Investigar costos y precisión antes de elegir. Implementar abstracción para cambiar proveedor.

### Privacidad

- Enviar solo región de interés (crop del ticket), no imagen completa
- No enviar metadatos de ubicación
- Opción en Settings para deshabilitar cloud OCR

### Output

```swift
InboxDraft(
    note: "Restaurante El Buen Sabor",
    amount: -234.50,
    date: detectedDate,
    account: nil,
    subcategory: nil,
    sourceType: .receiptPhoto,
    rawText: "EL BUEN SABOR\nAv. Principal 123\n...\nTOTAL $234.50",
    evidence: "TOTAL detectado línea 15",
    confidenceAmount: 0.92,
    confidenceDate: 0.88,
    confidenceMerchant: 0.75,
    needsUserInput: ["account"],
    status: .pending
)
```

---

## Módulo 6: Voz (STT + LLM Parser)

### Configuración

**Settings → Registro Inteligente → Idioma de voz**:
- Sistema (default): Toma idioma preferido del dispositivo, mapea a es/en
- Español
- Inglés

### Pipeline

```
Audio → STT Cloud → Texto → LLM Parser → InboxDraft
         │                      │
         │                      └─ Structured Outputs (JSON)
         │
         └─ gpt-4o-mini-transcribe (default)
            gpt-4o-transcribe (fallback si baja confianza)
```

### STT: Criterios de Fallback

```swift
// Activar gpt-4o-transcribe si:
// - Confianza promedio < 0.7
// - Múltiples [inaudible] o [unclear] en transcripción
// - Duración > 30s y resultado muy corto

func shouldUsePremiumSTT(result: TranscriptionResult) -> Bool {
    if result.averageConfidence < 0.7 { return true }
    if result.text.contains("[inaudible]") { return true }
    if result.duration > 30 && result.text.count < 50 { return true }
    return false
}
```

### LLM Parser: Prompt

```
Sistema: Eres un parser de gastos para una app de finanzas personales.
Extrae información de la transcripción y devuelve JSON estructurado.

Reglas de fecha:
- "hoy", "ahorita", "recién", "acabo de" → fecha de hoy
- "ayer" → fecha de ayer
- Sin mención de fecha → fecha de hoy
- Fecha explícita → usar esa fecha

Reglas de campos:
- monto: número con signo negativo para gastos, positivo para ingresos
- nota: descripción del gasto, incluir merchant si se menciona
- subcategoriaId: null (no inferir a menos que sea MUY obvio)
- etiquetas: solo si el usuario las menciona explícitamente
- cuentaId: solo si el usuario menciona una cuenta específica

Input: "{transcripción}"

Output JSON:
{
  "amount": number | null,
  "date": "YYYY-MM-DD",
  "note": string,
  "subcategoryId": string | null,
  "tags": string[],
  "accountId": string | null,
  "confidence": {
    "amount": 0.0-1.0,
    "date": 0.0-1.0,
    "merchant": 0.0-1.0
  }
}
```

### Edge Cases

| Caso | Manejo |
|------|--------|
| Monto ambiguo ("como cincuenta pesos") | Parsear como 50, confianza 0.7 |
| Negación ("no gasté nada") | No crear draft |
| Múltiples gastos ("gasté 50 en café y 100 en uber") | Crear 2 drafts |
| Ruido/ininteligible | Draft con needsUserInput: ["amount", "note"] |
| Moneda mencionada ("50 dólares") | Ignorar moneda, solo monto. Nota: "50 dólares en..." |

### Output

```swift
InboxDraft(
    note: "Starbucks café",
    amount: -85.00,
    date: Date(), // "acabo de gastar" → hoy
    account: nil,
    subcategory: nil,
    sourceType: .voice,
    rawText: "Acabo de gastar ochenta y cinco pesos en Starbucks por un café",
    evidence: "Monto: 85, Merchant: Starbucks",
    confidenceAmount: 0.95,
    confidenceDate: 0.99, // "acabo de" es muy claro
    confidenceMerchant: 0.98,
    needsUserInput: ["account"],
    status: .pending
)
```

### Métricas

- Latencia STT + LLM (target: <3s)
- Tasa de corrección de monto por usuario
- Tasa de corrección de merchant por usuario
- % de drafts que requieren edición

---

## Módulo 7: Memoria de Comercios (Merchant Memory)

### Objetivo

Aprender de las aprobaciones del usuario para sugerir (o autoasignar) subcategorías basándose en el merchant.

### Modelo de Datos

```swift
@Model
final class MerchantMemory {
    var merchantCanonical: String             // Nombre normalizado
    var subcategory: Subcategory?             // Subcategoría más frecuente
    var countApproved: Int                    // Veces aprobado con esta subcat
    var countCorrected: Int                   // Veces que usuario cambió la sugerencia
    var lastApprovedAt: Date
    var aliases: [String]                     // Variantes del nombre

    var correctionRate: Double {
        guard countApproved + countCorrected > 0 else { return 0 }
        return Double(countCorrected) / Double(countApproved + countCorrected)
    }

    var confidence: Double {
        // Alta confianza: muchas aprobaciones, pocas correcciones
        let baseConfidence = min(Double(countApproved) / 5.0, 1.0)
        return baseConfidence * (1.0 - correctionRate)
    }
}
```

### Canonicalización

```swift
func canonicalize(_ merchantRaw: String) -> String {
    var result = merchantRaw
        .uppercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Remover prefijos comunes de procesadores de pago
    let prefixes = ["DP*", "IZI*", "SQ *", "PAYPAL *", "MPOS*"]
    for prefix in prefixes {
        if result.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
        }
    }

    // Colapsar espacios y símbolos
    result = result
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: #"[^\w\s]"#, with: "", options: .regularExpression)

    return result.trimmingCharacters(in: .whitespaces)
}
```

### Política de Sugerencia vs Autoasignación

| Condición | Acción |
|-----------|--------|
| countApproved < 3 | No sugerir |
| countApproved >= 3 AND correctionRate > 0.3 | Sugerir (baja confianza) |
| countApproved >= 3 AND correctionRate <= 0.3 | Sugerir (alta confianza) |
| countApproved >= 5 AND correctionRate <= 0.1 | Autoasignar (usuario puede cambiar) |

### Actualización al Aprobar

```swift
func updateMemory(merchant: String, subcategory: Subcategory, wasCorrection: Bool) {
    let canonical = canonicalize(merchant)

    if let existing = fetchMemory(canonical) {
        if wasCorrection {
            existing.countCorrected += 1
            existing.subcategory = subcategory // Actualizar a la nueva
        } else {
            existing.countApproved += 1
        }
        existing.lastApprovedAt = Date()
    } else {
        // Crear nueva entrada
        let memory = MerchantMemory(
            merchantCanonical: canonical,
            subcategory: subcategory,
            countApproved: 1,
            countCorrected: 0,
            lastApprovedAt: Date(),
            aliases: [merchant]
        )
        modelContext.insert(memory)
    }
}
```

### Decay (Olvido)

Si un merchant no se usa en 6 meses, reducir confidence gradualmente:
```swift
func applyDecay() {
    let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
    let staleMemories = fetchMemories(lastApprovedBefore: sixMonthsAgo)

    for memory in staleMemories {
        memory.countApproved = max(0, memory.countApproved - 1)
        if memory.countApproved == 0 {
            modelContext.delete(memory)
        }
    }
}
```

---

## Módulo 8: Sistema de Confianza

### Campos y Umbrales

| Campo | Umbral bajo | Umbral alto | Acción si bajo |
|-------|-------------|-------------|----------------|
| amount | 0.5 | 0.8 | needsUserInput, no mostrar valor |
| date | 0.4 | 0.7 | Usar fecha actual como fallback |
| merchant | 0.5 | 0.8 | Mostrar rawText en nota |
| subcategory | 0.6 | 0.9 | No autoasignar |

### Reglas de Decisión

```swift
struct ConfidencePolicy {
    // STT: Reintento con modelo premium
    static func shouldRetrySTT(confidence: Double) -> Bool {
        return confidence < 0.7
    }

    // OCR: Fallback cloud para recibos
    static func shouldUseCloudOCR(
        sourceType: DraftSourceType,
        amountConfidence: Double?,
        dateConfidence: Double?
    ) -> Bool {
        guard sourceType == .receiptPhoto else { return false }
        let amount = amountConfidence ?? 0
        let date = dateConfidence ?? 0
        return amount < 0.6 || (amount < 0.8 && date < 0.5)
    }

    // Merchant Memory: Sugerir vs autoasignar
    static func subcategoryAction(memory: MerchantMemory?) -> SubcategoryAction {
        guard let memory = memory else { return .none }

        if memory.confidence >= 0.8 && memory.countApproved >= 5 {
            return .autoAssign(memory.subcategory)
        } else if memory.confidence >= 0.5 && memory.countApproved >= 3 {
            return .suggest(memory.subcategory)
        }
        return .none
    }
}

enum SubcategoryAction {
    case none
    case suggest(Subcategory?)
    case autoAssign(Subcategory?)
}
```

### Telemetría Mínima (Local)

```swift
@Model
final class IngestMetrics {
    var date: Date
    var sourceType: DraftSourceType
    var usedCloudFallback: Bool
    var usedPremiumSTT: Bool
    var fieldsEdited: [String]        // ["amount", "subcategory", etc.]
    var wasApproved: Bool
    var timeToApprove: TimeInterval?  // Segundos desde creación hasta aprobación
}
```

**Métricas agregadas** (calculadas localmente, no enviadas):
- % de drafts que usan fallback cloud
- % de drafts editados por campo
- Tiempo promedio de aprobación
- Tasa de rechazo

---

## Dependencias Técnicas

### Nuevas Dependencias

| Dependencia | Propósito | Notas |
|-------------|-----------|-------|
| OpenAI Swift SDK | STT y LLM | Añadir desde cero |
| Vision Framework | OCR on-device | Ya incluido en iOS |
| Speech Framework | (Opcional) STT on-device fallback | Ya incluido en iOS |

### Configuración Requerida

1. **OpenAI API Key**: Almacenar en Keychain, configurar en Settings
2. **Cloud OCR** (futuro): API keys de AWS/GCP según proveedor elegido
3. **Permisos**:
   - Micrófono (voz)
   - Cámara (foto de recibo)
   - Photo Library (importar screenshots)

---

## Fases de Implementación

### Subfase 8.1: Infraestructura Base
- [ ] Modelo InboxDraft (SwiftData)
- [ ] Vista de bandeja (lista, filtros, badge)
- [ ] Acciones básicas (ver detalle, eliminar)
- [ ] Navegación desde Panel toolbar

### Subfase 8.2: Edición y Aprobación
- [ ] Sheet de edición rápida
- [ ] Validación de campos requeridos
- [ ] Flujo de aprobación → crear TransactionItem
- [ ] Acciones en lote

### Subfase 8.3: Voz (MVP)
- [ ] Integración OpenAI SDK
- [ ] STT con gpt-4o-mini-transcribe
- [ ] LLM parser básico
- [ ] Configuración de idioma en Settings

### Subfase 8.4: Imágenes (MVP)
- [ ] Pipeline OCR con Vision
- [ ] Clasificación heurística
- [ ] Extractor ScreenshotSingle
- [ ] Extractor ScreenshotList básico

### Subfase 8.5: Merchant Memory
- [ ] Modelo MerchantMemory
- [ ] Canonicalización
- [ ] Actualización al aprobar
- [ ] Sugerencia de subcategoría

### Subfase 8.6: Refinamiento
- [ ] Sistema de confianza completo
- [ ] Fallback STT premium
- [ ] Extractor ReceiptPhoto
- [ ] Métricas locales

### Subfase 8.7: Cloud Fallback (Opcional)
- [ ] Investigar proveedor (AWS vs GCP)
- [ ] Implementar fallback cloud para recibos
- [ ] Configuración de privacidad

---

## Criterios de Aceptación (DoD Fase 7)

### Funcionales
- [ ] Usuario puede grabar nota de voz y generar draft
- [ ] Usuario puede importar imagen y generar draft(s)
- [ ] Bandeja muestra todos los drafts pendientes
- [ ] Usuario puede aprobar draft válido → crea TransactionItem
- [ ] Usuario puede editar campos antes de aprobar
- [ ] Usuario puede eliminar/rechazar drafts
- [ ] Acciones en lote funcionan correctamente
- [ ] Merchant Memory sugiere subcategorías después de 3+ aprobaciones

### No Funcionales
- [ ] Latencia voz: <3s (STT + LLM)
- [ ] Latencia imagen: <2s (OCR + clasificación + extracción)
- [ ] Funciona offline (OCR, heurísticas) con degradación graceful
- [ ] API keys almacenadas en Keychain

### Exclusiones V1
- Itemización de recibos (líneas individuales)
- Cloud OCR (diferido a 7.7 o Fase 8)
- Detección de duplicados (diferido)
- Notificaciones de drafts pendientes (Fase 8)

---

*Documento creado: 2026-01-20*
*Última actualización: 2026-01-20*
