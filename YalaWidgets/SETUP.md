# YalaWidgets Setup Guide

Esta carpeta contiene los archivos para el Widget Extension de Yala que expone controles en el Control Center de iOS 18+.

## Configuración en Xcode

### Paso 1: Crear el Widget Extension Target

1. Abre `Yala.xcodeproj` en Xcode
2. File → New → Target...
3. Selecciona "Widget Extension"
4. Configuración:
   - Product Name: `YalaWidgets`
   - Team: Tu equipo de desarrollo
   - Bundle Identifier: `$(PRODUCT_BUNDLE_IDENTIFIER).YalaWidgets` (se autocompletará)
   - **Desmarca** "Include Configuration App Intent"
   - **Desmarca** "Include Live Activity"
5. Click "Finish"
6. Cuando pregunte si activar el scheme, selecciona "Activate"

### Paso 2: Reemplazar archivos generados

1. Elimina los archivos generados automáticamente por Xcode en la carpeta YalaWidgets
2. Los archivos de esta carpeta ya están en su lugar:
   - `YalaWidgetsBundle.swift` - Entry point del widget
   - `ControlWidgets.swift` - Los 3 controles para Control Center
   - `Info.plist` - Configuración de la extensión
   - `YalaWidgets.entitlements` - Entitlements necesarios

### Paso 3: Configurar el Target

1. Selecciona el target `YalaWidgets` en el Project Navigator
2. En la pestaña "General":
   - Minimum Deployments: iOS 18.0
3. En la pestaña "Signing & Capabilities":
   - Verifica que App Groups esté configurado (debe heredar del app principal)
4. En la pestaña "Build Settings":
   - Busca "Info.plist File" y verifica que apunte a `YalaWidgets/Info.plist`

### Paso 4: Verificar dependencia del App

1. Selecciona el target principal `Yala`
2. En "Build Phases" → "Embed Foundation Extensions"
3. Verifica que `YalaWidgets.appex` esté en la lista

### Paso 5: Build y Test

1. Selecciona un simulador iOS 18+ (iPhone 17 Pro)
2. Build el proyecto (Cmd+B)
3. En el simulador:
   - Ve a Settings → Control Center
   - Busca "Yala" en la sección "Add Controls"
   - Deberías ver los 3 controles disponibles

## Controles disponibles

| Control | Icono | Acción |
|---------|-------|--------|
| Gasto rápido | plus.circle.fill | Abre la app para nuevo registro |
| Entrada por voz | mic.fill | Abre la app en modo voz |
| Escanear recibo | camera.fill | Abre la app en modo cámara |

## Notas

- Requiere iOS 18.0 o superior
- Los controles usan `openAppWhenRun: true` para abrir la app
- Las localizaciones están en los archivos `Localizable.strings` del app principal
