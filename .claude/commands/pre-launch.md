---
description: Checklist completo pre-App Store — Apple compliance, privacy, performance, UX
allowed-tools: Bash(xcodebuild:*), Bash(git:*), Grep, Glob, Read, Task
---

Checklist exhaustivo antes de enviar a App Store Review. Verifica cumplimiento con Apple Guidelines, privacidad, rendimiento y experiencia de usuario.

## SECCIÓN 1: BUILD Y COMPILACIÓN

### A. Build limpio
```bash
xcodebuild clean build -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error:|warning:|BUILD)" | head -30
```
- 0 errores
- 0 warnings (objetivo)
- BUILD SUCCEEDED

### B. Xcode SDK
- Verificar que usa iOS 26 SDK (requerido por Apple desde abril 2026)

## SECCIÓN 2: PRIVACIDAD Y SEGURIDAD

### A. Privacy Manifest
```
Glob: **/PrivacyInfo.xcprivacy
Read: verificar contenido
```
- Existe PrivacyInfo.xcprivacy
- Declara Required Reason APIs usadas (UserDefaults, file timestamps)
- Declara datos recopilados correctamente

### B. API Keys
```
Grep: (api.?key|secret|password|token).*=.*" en archivos .swift
```
- 0 keys hardcodeadas
- Todas vienen de Secrets.xcconfig → Info.plist

### C. Logs de producción
```
Grep: print\( en archivos .swift FUERA de #if DEBUG
```
- 0 prints sin #if DEBUG

### D. Datos sensibles
- No se logean datos financieros del usuario
- No se envían datos a servidores no declarados

## SECCIÓN 3: APP STORE METADATA

### A. Privacy Policy
- Verificar que existe y es accesible: `.planning/PRIVACY-POLICY.md`
- URL funcional en Settings de la app

### B. Terms & Conditions
- Verificar que existe: `.planning/TERMS-CONDITIONS.md`
- URL funcional

### C. Suscripciones
- Precio claro ANTES de compra
- Botón de restaurar compras visible
- Texto de auto-renovación presente
- Link a términos de suscripción

### D. Localizaciones
```
Grep: ".*" = ""; en archivos Localizable.strings (strings vacíos)
```
- 0 strings vacíos en 6 idiomas

## SECCIÓN 4: ESTABILIDAD

### A. Force unwraps
```
Grep: \! en .swift (excluyendo !=, //, strings)
```
- Listar todos y verificar que tienen guard/if previo

### B. Error handling
```
Grep: try\? en .swift
```
- Todos justificados o convertidos a do/catch

### C. Edge cases
- ¿Qué pasa con 0 transacciones? (empty states)
- ¿Qué pasa con 10,000 transacciones? (performance)
- ¿Qué pasa sin internet? (graceful offline)
- ¿Qué pasa al cambiar idioma del sistema?

## SECCIÓN 5: ACCESIBILIDAD (APPLE HIG)

### A. VoiceOver básico
```
Grep: .accessibilityLabel en Views/
```
- Botones icon-only tienen labels
- Gráficas tienen descripción alternativa

### B. Dynamic Type
```
Grep: .font\(.system\(size: en Views/
```
- Fonts hardcodeados identificados (no bloquean pero anotar para fix)

### C. Touch Targets
- Elementos interactivos >= 44x44 puntos

## SECCIÓN 6: UX CRÍTICA

### A. Primer uso
- Onboarding funcional
- Empty states claros en todas las vistas
- Datos de ejemplo si aplica

### B. Flujos críticos
- Crear transacción → éxito
- Importar CSV → éxito
- Crear presupuesto → éxito
- Pago planificado → notificación
- Backup iCloud → restaurar

### C. Dark Mode
- Verificar que todas las vistas son legibles en dark mode
- No hay texto invisible o fondos incorrectos

## SECCIÓN 7: PERFORMANCE

### A. Launch time
- Objetivo: < 2 segundos en cold launch
- Verificar que onAppear no hace trabajo pesado

### B. Memory
- No hay retain cycles obvios (closures con [weak self])
- Listas largas usan LazyVStack

### C. Widgets
- Widgets se actualizan correctamente
- Deep links funcionan

## REPORTE

```
╔══════════════════════════════════════════════════╗
║              PRE-LAUNCH CHECKLIST                ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  1. Build & Compilación                          ║
║     [✓/✗] Build limpio (0 errors, 0 warnings)   ║
║     [✓/✗] iOS 26 SDK                            ║
║                                                  ║
║  2. Privacidad & Seguridad                       ║
║     [✓/✗] PrivacyInfo.xcprivacy completo         ║
║     [✓/✗] 0 API keys hardcodeadas               ║
║     [✓/✗] 0 prints en producción                ║
║                                                  ║
║  3. App Store Metadata                           ║
║     [✓/✗] Privacy Policy accesible              ║
║     [✓/✗] Terms & Conditions accesible          ║
║     [✓/✗] Suscripciones claras                  ║
║     [✓/✗] Localizaciones completas              ║
║                                                  ║
║  4. Estabilidad                                  ║
║     [✓/✗] Force unwraps protegidos              ║
║     [✓/✗] Error handling completo               ║
║                                                  ║
║  5. Accesibilidad                                ║
║     [✓/✗] VoiceOver básico                      ║
║     [  ] Dynamic Type (anotar deuda)             ║
║     [✓/✗] Touch targets >= 44pt                 ║
║                                                  ║
║  6. UX                                           ║
║     [✓/✗] Onboarding funcional                  ║
║     [✓/✗] Empty states presentes                ║
║     [✓/✗] Dark mode legible                     ║
║                                                  ║
║  7. Performance                                  ║
║     [✓/✗] Launch < 2s                           ║
║     [✓/✗] No retain cycles                      ║
║     [✓/✗] Widgets funcionales                   ║
║                                                  ║
╠══════════════════════════════════════════════════╣
║  VEREDICTO: [LISTO | BLOQUEADO | N WARNINGS]     ║
╚══════════════════════════════════════════════════╝
```

## NOTAS
- Este skill es para revisión PRE-RELEASE, no para uso diario
- Ejecutar 1-2 semanas antes del envío a App Store
- Issues de accesibilidad pueden causar rechazo
- Privacy manifest incompleto SIEMPRE causa rechazo
- Suscripciones sin texto claro SIEMPRE causan rechazo
