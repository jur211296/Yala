# Subfase 8.4: Imágenes MVP - Resumen de Progreso

**Fecha**: 2026-01-24
**Sesión**: subfase-8.4-images-mvp
**Branch**: 1.1

---

## INCREMENTOS COMPLETADOS: 2/8 ✅

### ✅ Incremento 1: Toggle UI y AppStorage (Commit: bf9175d)

**Archivos modificados**:
- `ProfileView.swift`: Toggle "Entrada con Imágenes" en Settings > Preferencias
- `L10n.swift`: Enums Settings, Voice, Inbox, VoiceLanguage, Panel
- 6 archivos de localización: Keys para Settings, Voice, Inbox, Panel
- `Package.resolved`: Auto-actualizado

**Funcionalidad**:
- Toggle `imageInputEnabled` persistente en AppStorage
- Localizaciones completas en 6 idiomas (ES, EN, DE, FR, IT, PT)
- **IMPORTANTE**: También se agregaron localizaciones faltantes para Voice, Inbox, Panel (prerequisitos para compilación del branch 1.1)

**Commit**: `feat(settings): add image input toggle and missing localizations`

**Validación**:
- ✅ Build: OK
- ✅ Tests: N/A (cambios de UI y localizaciones)

---

### ✅ Incremento 2: Opción en FAB (Commit: e0bcc7b)

**Archivos modificados**:
- `PanelView.swift`: Lógica FAB con 1/2/3 opciones dinámicas
- `L10n.swift`: `Panel.fabImage`
- 6 archivos de localización: `panel.fabImage`
- `STATE.md`: Auto-actualizado

**Archivos nuevos**:
- `Yala/App/Views/Image/ImageSelectionView.swift`: Placeholder

**Funcionalidad**:
- FAB muestra opciones según toggles:
  - Solo voz habilitado → 2 opciones (Voz, Manual)
  - Solo imagen habilitado → 2 opciones (Imagen, Manual)
  - Ambos habilitados → 3 opciones (Voz, Imagen, Manual)
  - Ninguno habilitado → 1 opción (Manual, FAB simple)
- ImageSelectionView placeholder con mensaje "Próximamente"

**Commit**: `feat(panel): add image option to FAB menu`

**Validación**:
- ✅ Build: OK
- ✅ Tests: N/A (cambios de UI)

---

## INCREMENTOS PENDIENTES: 6/8

### 🔄 Incremento 3: Pipeline OCR Base con Vision

**Archivos a crear**:
- `App/Services/ImageOCR/ImageOCRService.swift`
- `App/Services/ImageOCR/OCRResult.swift`

**Tareas**:
1. Implementar `ImageOCRService` con Vision framework
2. Crear struct `OCRResult` con texto y bounding boxes
3. Manejo de errores (noTextDetected, visionRequestFailed, imageProcessingFailed)
4. Tests básicos con imagen de prueba

**Commit esperado**: `feat(ocr): add Vision-based OCR service for text extraction`

---

### 🔄 Incremento 4: Clasificador Heurístico

**Archivos a crear**:
- `App/Services/ImageOCR/ImageClassifier.swift`

**Tareas**:
1. Enum `ImageType` (screenshotList, screenshotSingle, receiptPhoto, unknown)
2. Método `classify(ocrResult:) -> ImageType`
3. Heurísticas:
   - screenshotList: múltiples líneas con monto
   - screenshotSingle: keywords bancarios + monto
   - receiptPhoto: keywords de recibo + monto
4. Tests con 4 tipos de imágenes

**Commit esperado**: `feat(ocr): add heuristic image classifier`

---

### 🔄 Incremento 5: Extractor ScreenshotSingle

**Archivos a crear**:
- `App/Services/ImageOCR/Extractors/ScreenshotSingleExtractor.swift`
- `App/Services/ImageOCR/Extractors/AmountParser.swift`
- `App/Services/ImageOCR/Extractors/DateParser.swift`

**Tareas**:
1. `AmountParser`: Múltiples formatos ($, €, £, paréntesis, negativos)
2. `DateParser`: Fechas relativas (hoy, ayer) y absolutas (dd/MM/yyyy, etc.)
3. `ScreenshotSingleExtractor`: Alertas bancarias → 1 InboxDraft
4. Extracción de merchant con regex
5. Tests con 5+ alertas bancarias reales

**Commit esperado**: `feat(ocr): add ScreenshotSingle extractor for bank alerts`

---

### 🔄 Incremento 6: Extractor ScreenshotList

**Archivos a crear**:
- `App/Services/ImageOCR/Extractors/ScreenshotListExtractor.swift`
- `App/Services/ImageOCR/Extractors/RowClusterer.swift`

**Tareas**:
1. `RowClusterer`: Agrupación por coordenada Y (tolerance: 3%)
2. `ScreenshotListExtractor`: Listas de movimientos → N InboxDrafts
3. Herencia de fecha de headers
4. Tests con listas de 3+ transacciones

**Commit esperado**: `feat(ocr): add ScreenshotList extractor for transaction lists`

---

### 🔄 Incremento 7: Integración UI Completa

**Archivos a modificar**:
- `ImageSelectionView.swift`: Reemplazar placeholder con funcionalidad completa

**Tareas**:
1. Agregar PhotosPicker
2. Pipeline completo: Imagen → OCR → Clasificar → Extraer → Drafts
3. Estados de loading con mensajes claros
4. Manejo de errores con localizaciones
5. Auto-dismiss después de crear drafts
6. Localizaciones en 6 idiomas (15+ keys nuevas)

**Localizaciones necesarias**:
```
imageSelection.title
imageSelection.description
imageSelection.selectImage
imageSelection.loadingImage
imageSelection.extractingText
imageSelection.analyzingContent
imageSelection.creatingDrafts
imageSelection.errorLoadingImage
imageSelection.errorReceiptNotSupported
imageSelection.errorUnknownType
```

**Commit esperado**: `feat(ocr): integrate image selection and OCR pipeline with UI`

---

### 🔄 Incremento 8: QA Scenarios y Documentación

**Archivos a modificar**:
- `.planning/QA-SCENARIOS.md`: Nueva sección "Ingesta de Imágenes"
- `.planning/STATE.md`: Actualizar "Completed in Current Phase"

**Tareas**:
1. Agregar sección "12. Ingesta de Imágenes (Subfase 8.4)" en QA-SCENARIOS.md
2. Documentar ~40 validaciones:
   - Toggle de Imágenes
   - FAB con Imágenes
   - Selección de Imagen
   - Screenshot Single (alertas bancarias)
   - Screenshot List (listas de movimientos)
   - Manejo de Errores
   - Integración con Bandeja
   - Formatos de Montos
3. Actualizar STATE.md con Subfase 8.4 completada

**Commit esperado**: `docs(qa): add image OCR scenarios and update STATE`

---

## CÓMO CONTINUAR EN LA PRÓXIMA SESIÓN

### Opción A: Continuar con Incremento 3 (Recomendado)

```bash
cd /Users/jur/Yala
git status  # Verificar que estés en branch 1.1
git log --oneline -5  # Ver últimos commits (deberías ver e0bcc7b y bf9175d)
```

Luego pedirle a Claude:
> "Continúa con el Incremento 3: Pipeline OCR Base con Vision según el plan en `.claude/sessions/subfase-8.4-progress.md`"

### Opción B: Validación Manual Primero

Antes de continuar con más código, valida manualmente lo implementado:

1. **Abrir Xcode**: `open Yala.xcodeproj`
2. **Correr en simulador** (iPhone 17 Pro)
3. **Validar Toggle**:
   - Ir a Profile > Preferencias
   - Verificar que existe toggle "Entrada con Imágenes"
   - Activar toggle
4. **Validar FAB**:
   - Volver al Panel
   - Tap en FAB (+)
   - Debe mostrar 3 opciones: Voz, Imagen, Manual
   - Tap en "Imagen"
   - Debe abrir sheet con placeholder "Selección de imagen"
5. **Validar localizaciones**:
   - Cambiar idioma del simulador (Settings > General > Language & Region)
   - Verificar que textos cambian correctamente en 6 idiomas

Si todo funciona, continuar con Incremento 3.

---

## NOTAS IMPORTANTES

### Estado del Branch 1.1

El branch 1.1 tenía código de Inbox/Voice (Fases 8.1, 8.2, 8.3) pero **faltaban localizaciones**.

**En Incremento 1 se agregaron**:
- Todas las localizaciones de Voice (20+ keys)
- Todas las localizaciones de Inbox (30+ keys)
- Localizaciones de Panel (fabVoice, fabManual)
- Localizaciones de Settings (voiceInputEnabled, voiceLanguage)
- Enums L10n.Voice, L10n.Inbox, L10n.VoiceLanguage

Esto fue **necesario para que el proyecto compilara**. No son parte de Subfase 8.4 directamente, pero eran prerequisitos.

### Commits Creados

1. `bf9175d` - feat(settings): add image input toggle and missing localizations (636 líneas)
2. `e0bcc7b` - feat(panel): add image option to FAB menu (98 líneas)

**Total**: 734 líneas agregadas en 2 commits

### Próximos Pasos Críticos

**Incremento 3** es el más importante porque establece la infraestructura base para OCR. Los incrementos 4, 5, 6 dependen de que el Incremento 3 esté bien hecho.

**Vision Framework**:
- Ya está disponible en iOS (no requiere dependencias)
- API: `VNRecognizeTextRequest` con `recognitionLevel: .accurate`
- Output: Array de `VNRecognizedTextObservation` con texto y bounding boxes

**Estructura recomendada**:
```swift
// OCRResult.swift
struct OCRResult {
    let fullText: String
    let observations: [VNRecognizedTextObservation]

    struct TextBlock {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
    }

    var textBlocks: [TextBlock] { ... }
}

// ImageOCRService.swift
@Observable
final class ImageOCRService {
    enum OCRError: Error {
        case noTextDetected
        case visionRequestFailed
        case imageProcessingFailed
    }

    func extractText(from image: UIImage) async throws -> OCRResult
}
```

---

## VALIDACIÓN MANUAL COMPLETA (Para después del Incremento 8)

Una vez completados los 8 incrementos, validar:

### 1. Toggle de Imágenes
- [ ] Toggle visible en ProfileView
- [ ] Estado persiste

### 2. FAB Dinámico
- [ ] 1 opción (ninguno habilitado)
- [ ] 2 opciones (solo voz O solo imagen)
- [ ] 3 opciones (ambos habilitados)

### 3. Flujo Completo de Imagen
- [ ] Seleccionar imagen desde Photo Library
- [ ] OCR extrae texto correctamente
- [ ] Clasificador identifica tipo (screenshotSingle/List)
- [ ] Extractor crea drafts
- [ ] Drafts aparecen en InboxView
- [ ] Se pueden aprobar/editar/eliminar

### 4. Screenshot Single
- [ ] Alerta bancaria → 1 draft
- [ ] Monto extraído correctamente
- [ ] Fecha relativa ("hoy") funciona
- [ ] Merchant extraído (si existe)

### 5. Screenshot List
- [ ] Lista de movimientos → N drafts
- [ ] Clustering por fila funciona
- [ ] Herencia de fecha de headers
- [ ] Cada draft tiene monto correcto

### 6. Formatos de Montos
- [ ] $1,234.56 parseado
- [ ] -$50.00 (negativo)
- [ ] ($100.00) (paréntesis = negativo)
- [ ] €100 / £50 reconocidos

### 7. Manejo de Errores
- [ ] Imagen sin texto → mensaje de error
- [ ] Tipo desconocido → mensaje de error
- [ ] Error de carga → mensaje de error

---

## DECISIONES TÉCNICAS TOMADAS

1. **OCR on-device con Vision**: No usar cloud OCR en V1
2. **Clasificación 100% heurística**: Sin LLM en V1
3. **Solo Photo Library**: No captura de cámara en tiempo real
4. **Sin batch processing**: 1 imagen a la vez
5. **Formato de montos**: Soportar $, €, £, paréntesis, comas, puntos

---

## TIEMPO ESTIMADO RESTANTE

Basado en complejidad de incrementos pendientes:

- **Incremento 3** (OCR Base): ~20 minutos
- **Incremento 4** (Clasificador): ~15 minutos
- **Incremento 5** (ScreenshotSingle): ~30 minutos
- **Incremento 6** (ScreenshotList): ~25 minutos
- **Incremento 7** (UI Completa): ~25 minutos
- **Incremento 8** (QA/Docs): ~10 minutos

**Total estimado**: ~2 horas de implementación + validación manual

---

## CONTACTO/SOPORTE

Si necesitas ayuda para continuar:
1. Lee este documento completo
2. Verifica que estés en branch 1.1
3. Verifica los últimos 2 commits (bf9175d, e0bcc7b)
4. Pide a Claude que continúe desde el Incremento 3

**Última actualización**: 2026-01-24 22:45 EST
