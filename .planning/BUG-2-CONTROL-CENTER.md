# BUG-2: Control Center Widgets No Funcionan

**Estado:** 🔴 BLOQUEADO - Pendiente investigación
**Última actualización:** 2026-02-02
**Prioridad:** Media (hay alternativas funcionando)

---

## Resumen del Problema

Los Control Center widgets de iOS 18+ aparecen correctamente en el Control Center pero **no ejecutan ninguna acción** al presionarlos. La app no se abre y los intents no se ejecutan.

---

## Lo Que Funciona

- ✅ Los 3 controles aparecen en Control Center bajo "Yala Dev"
- ✅ Nombres correctos en español: "Nuevo gasto", "Gasto por voz", "Gasto por foto"
- ✅ Iconos correctos (plus.circle.fill, mic.fill, camera.fill)
- ✅ El App Group `group.com.jurgenschmidt.yala.dev` está registrado en Developer Portal
- ✅ Los Atajos de Siri (Shortcuts) funcionan correctamente como alternativa

## Lo Que NO Funciona

- ❌ Al presionar cualquier control, no pasa nada
- ❌ La app no se abre
- ❌ El `perform()` del intent nunca se ejecuta (no hay logs)
- ❌ Error persistente de CFPrefs al acceder al App Group

---

## Error Principal

```
Couldn't read values in CFPrefsPlistSource (Domain: group.com.jurgenschmidt.yala.dev,
User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null), Contents Need Refresh: Yes):
Using kCFPreferencesAnyUser with a container is only allowed for System Containers,
detaching from cfprefsd
```

Este error aparece incluso después de:
1. Registrar el App Group en Developer Portal
2. Habilitar el App Group en Signing & Capabilities para ambos targets
3. Regenerar provisioning profiles

---

## Archivos Modificados

### YalaWidgets/ControlWidgets.swift
```swift
// Versión actual (simplificada para diagnóstico)
@available(iOS 18.0, *)
struct ManualEntryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yala.control.manualEntry") {
            ControlWidgetButton(action: OpenManualEntryIntent()) {
                Label("Nuevo gasto", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Nuevo gasto")
        .description("Abre Yala para registrar un gasto")
    }
}

@available(iOS 18.0, *)
struct OpenManualEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Nuevo gasto"
    static var description = IntentDescription("Abre Yala para registrar un gasto")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()  // Simplificado - nunca se ejecuta
    }
}
```

### YalaWidgets/YalaWidgetsBundle.swift
```swift
@main
struct YalaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        LatestRecordsWidget()
        ScheduledPaymentsWidget()
        BudgetsWidget()

        if #available(iOS 18.0, *) {
            ManualEntryControl()
            VoiceEntryControl()
            ImageEntryControl()
        }
    }
}
```

### YalaWidgets/Info.plist
- Agregado `APP_GROUP_IDENTIFIER = $(APP_GROUP_IDENTIFIER)`
- Agregado `URL_SCHEME = $(URL_SCHEME)`

### Yala/App/AppBootstrapper.swift
- Agregado `checkForPendingControlAction()` para leer acciones del App Group
- El método se ejecuta pero nunca encuentra acciones pendientes

### Archivos Eliminados
- `YalaWidgets/YalaWidgetsControl.swift` (template de Timer de Xcode)

---

## Configuración de Build Settings

### YalaWidgetsExtension (Debug-Dev / Release-Dev)
```
APP_GROUP_IDENTIFIER = group.com.jurgenschmidt.yala.dev
URL_SCHEME = yaladev
```

### Entitlements (YalaWidgets.entitlements)
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>$(APP_GROUP_IDENTIFIER)</string>
</array>
```

---

## Intentos de Solución (Todos Fallidos)

1. **OpenURLIntent con OpensIntent protocol**
   - No funcionó - el intent nunca se ejecuta

2. **App Group + UserDefaults**
   - El widget guardaría la acción, la app la leería
   - No funcionó - error de CFPrefs

3. **openAppWhenRun = true sin lógica adicional**
   - Intent mínimo que solo retorna .result()
   - No funcionó - el botón no hace nada

4. **Habilitar App Group en Signing & Capabilities**
   - Ya estaba registrado en Developer Portal
   - Estaba desmarcado en Xcode - se habilitó
   - El error de CFPrefs persiste

---

## Entorno de Prueba

- **Dispositivo:** iPhone físico
- **iOS:** 26 (iOS 18+)
- **Xcode:** Última versión
- **Bundle:** Yala Dev (com.jurgenschmidt.yala.dev)
- **App Group:** group.com.jurgenschmidt.yala.dev

---

## Hipótesis Pendientes de Investigar

1. **Bug de iOS 18 beta/nueva versión**
   - Probar en iOS 18 estable (no beta)
   - Buscar en Apple Developer Forums

2. **Problema de sandbox/permisos**
   - El error "System Containers only" sugiere un problema de permisos
   - Posiblemente un bug de Apple

3. **Configuración adicional requerida**
   - Revisar documentación de Apple para ControlWidgets
   - Buscar ejemplos de código que funcionen

4. **Reinicio completo del dispositivo**
   - Eliminar app completamente
   - Reiniciar dispositivo
   - Reinstalar

5. **Probar con App Group de producción**
   - Usar `group.com.jurgenschmidt.yala` en lugar del de dev
   - Ver si el problema es específico del grupo .dev

---

## Alternativas Funcionando

Mientras se resuelve BUG-2, el usuario puede:

1. **Atajos de Siri** - Ya configurados y funcionando
   - "Gasto por voz" → VoiceEntryIntent
   - "Gasto por foto" → ImageEntryIntent

2. **Widgets de Home Screen** - Funcionando
   - BalanceWidget, LatestRecordsWidget, etc.

---

## Próximos Pasos al Retomar

1. Buscar en Apple Developer Forums problemas similares
2. Probar en dispositivo con iOS estable (no beta)
3. Crear un proyecto mínimo de prueba con solo ControlWidgets
4. Considerar reportar bug a Apple si persiste
5. Revisar WWDC sessions sobre ControlWidgets

---

## Referencias

- [Apple ControlWidget Documentation](https://developer.apple.com/documentation/widgetkit/controlwidget)
- [AppIntent Documentation](https://developer.apple.com/documentation/appintents)
- WWDC 2024 sessions sobre Control Center widgets
