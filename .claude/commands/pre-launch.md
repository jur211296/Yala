---
description: Checklist completo pre-App Store — Apple Guidelines 1.x a 5.x, privacy, subscriptions, UX
allowed-tools: Bash(xcodebuild:*), Bash(git:*), Grep, Glob, Read, Agent
---

Checklist exhaustivo antes de enviar a App Store Review. Cubre TODOS los Apple App Store Review Guidelines relevantes para Yala.

## LECCIONES DE RECHAZOS PREVIOS

**Rechazo #1 (Guideline 3.1.2):** Links de Terms/Privacy no separados ni localizados.
→ Verificar que cada link legal tenga URL propia y localizada.

**Rechazo #2 (Guideline 5.1.1(i) + 5.1.2(i)):** App comparte datos con OpenAI sin disclosure, sin identificar al tercero, sin consentimiento explícito.
→ Verificar: consent alert in-app para funciones AI, privacy policy nombra a OpenAI, detalla qué datos se envían.

---

## SECCIÓN 1: BUILD Y COMPILACIÓN (Guideline 2.1)

### A. Build limpio
```bash
xcodebuild clean build -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error:|warning:|BUILD)" | head -30
```
- 0 errores (BLOQUEANTE)
- 0 warnings (objetivo)

### B. SDK y target
- Verificar que usa iOS 26 SDK (latest)
- Verificar deployment target en proyecto

### C. Todos los targets compilan
- Scheme Yala (app principal)
- YalaWidgets (widget extension)
- YalaShare (share extension)

---

## SECCIÓN 2: COMPLETITUD DE LA APP (Guideline 2.1)

### A. Sin contenido placeholder
```
Grep: (coming soon|lorem ipsum|placeholder|TODO.*UI|WIP) en archivos .swift de Views/ (case insensitive)
```
- 0 textos placeholder en UI

### B. Sin features rotas
Verificar que TODOS los flujos principales funcionan:
- Crear transacción (manual, voz, foto, screenshot)
- Importar CSV
- Crear/editar presupuesto
- Crear/editar pago planificado
- Configurar cuentas
- iCloud sync
- Widgets se cargan
- Share extension funciona
- Notificaciones se programan

### C. Empty states
Verificar que cada pantalla principal tiene empty state (no pantallas en blanco):
```
Grep: YalaEmptyState en archivos de Views/
```
- Panel, Records, Statistics, Budgets, Scheduled Payments, Inbox, Categories

### D. Error states
- Sin internet: la app funciona offline (SwiftData local)
- 0 transacciones: empty states visibles
- Datos corruptos: no crash (error handling)

---

## SECCIÓN 3: METADATA PRECISA (Guideline 2.3)

### A. App Store Connect (verificación manual)
- Screenshots reflejan la app ACTUAL (no versión vieja)
- Descripción coincide con funcionalidad real
- Keywords NO incluyen nombres de competidores
- Categoría correcta (Finance)
- Age rating correcto (sin restricciones de contenido)
- What's New actualizado con cambios de esta versión

### B. Versión y build
```bash
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Yala.xcodeproj/project.pbxproj | head -4
```
- Marketing version incrementada
- Build number incrementado

---

## SECCIÓN 4: PRIVACIDAD Y DATOS (Guidelines 5.1.1 / 5.1.2)

### A. Privacy Manifest (OBLIGATORIO)
```
Glob: **/PrivacyInfo.xcprivacy → Read y verificar contenido
```
Verificar que declara:
- NSPrivacyTracking: false
- Collected Data Types: Audio (transcription), Photos (vision)
- Accessed API Types: UserDefaults (CA92.1), FileTimestamp (C617.1)
- Que COINCIDE con lo que realmente hace la app

### B. Permission Purpose Strings (OBLIGATORIO)
Verificar en Info.plist que existen y son claros:
```
Grep: NSMicrophoneUsageDescription en Info.plist
Grep: NSPhotoLibraryUsageDescription en Info.plist
Grep: NSFaceIDUsageDescription en Info.plist
```
- NSMicrophoneUsageDescription → menciona que audio se envía a OpenAI
- NSPhotoLibraryUsageDescription → menciona que imágenes se envían a OpenAI
- NSFaceIDUsageDescription → menciona protección de datos financieros
- Cada string es descriptivo (no genérico como "needs access")

### C. Terceros que reciben datos (CAUSA RECHAZO)
Verificar consent flow para OpenAI:
```
Grep: (smartInsightsConsent|aiConsent|openAIConsent|consentimiento) en archivos .swift
```
- Consent alert in-app ANTES de primera función AI
- Texto explica: qué datos se envían, a quién (OpenAI), para qué
- Opción de NO aceptar (funciones AI deshabilitadas sin consent)
- Privacy policy web nombra a OpenAI y detalla datos

### D. App Privacy Nutrition Labels (App Store Connect)
Verificar que los nutrition labels en App Store Connect coinciden con:
- Audio data: collected, not linked to identity, app functionality
- Photos: collected, not linked to identity, app functionality
- Analytics: TelemetryDeck, not linked to identity, analytics
- NO se recopila: nombre, email, location, contacts, browsing history
- Financials: NOT sent to servers (local only via SwiftData + iCloud)

### E. TelemetryDeck (analytics)
```
Read: Yala/Services/TelemetryService.swift (primeras 30 líneas)
```
- No envía PII
- No tracking de IDFA
- Solo eventos agregados

### F. API Keys seguras
```
Grep: (api.?key|secret|password|token).*=.*" en archivos .swift
```
- 0 keys hardcodeadas
- Todas via Secrets.xcconfig → Info.plist → Bundle.main

### G. Logs de producción
```
Grep: print\( en archivos .swift FUERA de #if DEBUG
```
- 0 prints sin #if DEBUG
- 0 datos sensibles en logs (montos, nombres, cuentas)

### H. Keychain
```
Read: App/Services/KeychainService.swift
```
- Usa kSecAttrAccessibleWhenUnlockedThisDeviceOnly (correcto)
- No almacena datos sensibles sin encriptar

---

## SECCIÓN 5: SUSCRIPCIONES (Guideline 3.1.1 / 3.1.2)

### A. StoreKit 2 Implementation
```
Read: App/Services/StoreKitManager.swift (primeras 50 líneas)
```
- Usa StoreKit 2 (no deprecated StoreKit 1)
- Product IDs correctos: com.yala.pro.monthly, com.yala.pro.yearly

### B. Información antes de compra (CAUSA RECHAZO)
Verificar en la pantalla de suscripción:
```
Grep: (subscription|suscripción|precio|price|trial|prueba) en Views/ relacionados con paywall/subscription
```
- Precio claro y visible ANTES de botón de compra
- Duración del período (mensual/anual) explícita
- Si hay trial: duración del trial + precio después del trial
- Texto de auto-renovación: "Se renueva automáticamente. Cancela cuando quieras."
- Link a Terms of Service
- Link a Privacy Policy

### C. Restaurar compras (OBLIGATORIO)
```
Grep: (restore|restaurar) en archivos .swift de Views/
```
- Botón "Restaurar compras" visible y funcional
- Funciona para usuarios que reinstalan o cambian de dispositivo

### D. Manage Subscriptions
- Link o instrucciones para gestionar/cancelar suscripción en Settings de iOS
```
Grep: (manageSubscriptions|manage.*subscription|gestionar.*suscripción) en archivos .swift
```

### E. Feature Gating
```
Read: App/Services/FeatureGateService.swift
```
- Features Pro claramente diferenciadas de Free
- No features Free que dejen de funcionar sin aviso
- Gate consistente (mismas features bloqueadas en toda la app)

---

## SECCIÓN 6: LEGAL Y LINKS (Guideline 3.1.2 / 5.1.1)

### A. Privacy Policy
- URL accesible desde dentro de la app (Settings)
- URL accesible desde App Store Connect
- Disponible en los 6 idiomas (es, en, fr, pt-BR, de, it)
- Menciona: datos recopilados, uso de OpenAI, uso de TelemetryDeck, iCloud sync

### B. Terms of Service
- URL SEPARADA de Privacy Policy (causa rechazo si es la misma)
- Accesible desde dentro de la app
- Incluye términos de suscripción y auto-renovación

### C. Links funcionales
```
Grep: (privacyPolicy|termsOfService|privacy.*url|terms.*url) en archivos .swift
```
- Verificar que las URLs no están rotas (pueden verificarse manualmente)
- Links localizados si aplica

---

## SECCIÓN 7: EXTENSIONS (Guidelines 2.4 / 4.2)

### A. Widgets
- Widgets se cargan con datos reales
- Deep links desde widget funcionan (widgetURL)
- Widget no muestra datos stale (refresh funciona)
```
Grep: widgetURL en archivos de YalaWidgets/
```

### B. Share Extension
- Acepta tipos de contenido declarados (imágenes)
- No crashea con input inesperado
- Share extension tiene App Group correcto
```
Read: YalaShare/Info.plist
```

---

## SECCIÓN 8: BACKGROUND MODES (Guideline 2.5.4)

```
Grep: UIBackgroundModes en Info.plist
```
Verificar que CADA background mode declarado se usa realmente:
- `fetch`: exchange rate updates, widget refresh → JUSTIFICADO
- `remote-notification`: push notifications → JUSTIFICADO
- NO declarar modes que no se usan (causa rechazo)

```
Read: App/BackgroundTaskManager.swift (primeras 30 líneas)
```
- Background tasks registrados correctamente
- Timeouts manejados (expiration handler)

---

## SECCIÓN 9: NOTIFICACIONES (Guideline 4.5.4)

```
Read: Services/NotificationService.swift (primeras 30 líneas)
```
- Permiso solicitado en momento relevante (no al abrir la app por primera vez)
- Notificaciones son útiles y relevantes (recordatorios de presupuesto, reportes)
- Deep links desde notificaciones funcionan
- No spam de notificaciones

---

## SECCIÓN 10: SEGURIDAD Y ENCRIPCIÓN

### A. Export Compliance
```
Grep: ITSAppUsesNonExemptEncryption en Info.plist
```
- Si es `false`: solo HTTPS estándar, no necesita declaración de exportación
- Si es `true` o no existe: verificar compliance de encripción

### B. Network Security
```
Grep: NSAppTransportSecurity en Info.plist
```
- No excepciones ATS (todo HTTPS)
- Si hay excepciones: justificar cada una

### C. Biometric Auth
- Face ID usage description presente y clara
- Fallback a passcode si Face ID falla
- No almacena biometric data

---

## SECCIÓN 11: ACCESIBILIDAD (Apple HIG)

- VoiceOver: botones icon-only con accessibilityLabel
- Dynamic Type: sin fonts hardcodeados (.system(size:))
- Touch targets >= 44pt
- Color no es único indicador de estado
- Reduce Motion respetado en animaciones

---

## SECCIÓN 12: LOCALIZACIÓN

```
Grep: = ""; en archivos Localizable.strings (strings vacíos)
```
- 0 strings vacíos en 6 idiomas (es, en, fr, pt-BR, de, it)
- Placeholders consistentes (%@, %d, %lld) entre idiomas
- UI no se rompe con textos largos (alemán, francés)

---

## SECCIÓN 13: PERFORMANCE

- Launch < 2 segundos
- No retain cycles
- Listas largas con LazyVStack
- FetchDescriptors con fetchLimit donde aplica
- No memory leaks evidentes

---

## REPORTE

```
## Pre-Launch Checklist — V[VERSION]

### Apple Guidelines Compliance
| # | Sección | Guideline | Estado |
|---|---------|-----------|--------|
| 1 | Build limpio | 2.1 | ✓/✗ |
| 2 | App completa (sin placeholders) | 2.1 | ✓/✗ |
| 3 | Metadata precisa | 2.3 | ✓/✗ (manual) |
| 4 | Privacy Manifest | 5.1.1 | ✓/✗ |
| 5 | Permission strings claros | 5.1.1 | ✓/✗ |
| 6 | AI Consent flow (OpenAI) | 5.1.1 + 5.1.2 | ✓/✗ |
| 7 | Nutrition labels coinciden | 5.1.1 | ✓/✗ (manual) |
| 8 | API Keys seguras | 5.1.1 | ✓/✗ |
| 9 | Logs producción | 5.1.1 | ✓/✗ |
| 10 | Suscripciones (precio, trial, renovación) | 3.1.2 | ✓/✗ |
| 11 | Restaurar compras | 3.1.2 | ✓/✗ |
| 12 | Privacy Policy (URL separada, localizada) | 3.1.2 + 5.1.1 | ✓/✗ |
| 13 | Terms of Service (URL separada) | 3.1.2 | ✓/✗ |
| 14 | Widgets funcionales | 2.4 | ✓/✗ |
| 15 | Share extension funcional | 2.4 | ✓/✗ |
| 16 | Background modes justificados | 2.5.4 | ✓/✗ |
| 17 | Notificaciones relevantes | 4.5.4 | ✓/✗ |
| 18 | Export compliance | 5.0 | ✓/✗ |
| 19 | Network security (ATS) | 5.0 | ✓/✗ |
| 20 | Accesibilidad básica | HIG | ✓/✗ |
| 21 | Localización 6 idiomas | 2.1 | ✓/✗ |
| 22 | Performance | 2.1 | ✓/✗ |

### Items que requieren verificación MANUAL en App Store Connect
- [ ] Screenshots actualizadas
- [ ] Descripción refleja versión actual
- [ ] Keywords sin competidores
- [ ] Age rating correcto
- [ ] What's New actualizado
- [ ] Nutrition labels coinciden con PrivacyInfo.xcprivacy
- [ ] Privacy Policy URL funcional
- [ ] Terms of Service URL funcional

### BLOQUEANTES
[Lista de items que causan rechazo seguro]

### WARNINGS
[Lista de items que pueden causar rechazo]

### Veredicto: LISTO | BLOQUEADO por [N] items
```

## NOTAS
- Ejecutar 1-2 semanas antes del envío a App Store
- Privacy manifest incompleto → RECHAZO SEGURO
- Datos a terceros sin consent → RECHAZO SEGURO (ya nos pasó 2x)
- Suscripciones sin info clara → RECHAZO SEGURO
- Background modes sin justificar → RECHAZO SEGURO
- Permission strings genéricos → RECHAZO PROBABLE
- Screenshots que no coinciden con app → RECHAZO PROBABLE
- Los items marcados "manual" requieren verificación en App Store Connect (no automatizable)
