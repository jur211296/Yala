# Investigación: ProfileToolbarButton en Toolbars

## Contexto
El `ProfileToolbarButton` no se comporta igual que `YalaToolbarButton` en los toolbars de iOS 26.

**Referencia visual:** `Yala/toolbar.png` y https://developer.apple.com/design/human-interface-guidelines/toolbars

---

## Problema 1: Toolbar Único (PanelView) ✅ RESUELTO

### Solución Final
1. Usar `.sharedBackgroundVisibility(.hidden)` en el ToolbarItem para ocultar el glass del toolbar
2. Aplicar `.glassEffect(.regular.interactive())` directamente al botón para el efecto de tap
3. Tamaño: 40pt con ring de 2pt

### Implementación
- `ProfileToolbarButton`: Componente con avatar (foto o icono), ring gradiente y spark badge (Pro)
- `ProfileToolbarItem`: Wrapper de ToolbarContent que aplica `.sharedBackgroundVisibility(.hidden)`

### Objetivo Original
El ProfileToolbarButton debe abarcar todo el espacio del toolbar igual que YalaToolbarButton, viéndose como un círculo completo que "llena" el botón.

### Estado anterior
El avatar se veía pequeño/encapsulado, no llenaba el espacio como lo hace un YalaToolbarButton con un SF Symbol.

### Referencia: YalaToolbarButton
```swift
struct YalaToolbarButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
    }
}
```

### Intentos Fallidos

#### Intento 1: Frame de 32x32 con spark badge interno
- **Cambio:** Reducir frame de 36x36 a 32x32, mantener spark badge dentro del ZStack
- **Resultado:** No mejoró - avatar sigue sin llenar el espacio
- **Hipótesis descartada:** El problema no era solo el tamaño del frame

#### Intento 2: Contenido llena 32x32, ring como strokeBorder overlay
- **Cambio:** El avatarContent llena los 32x32 completos, el ring es un overlay strokeBorder que no reduce el área
- **Resultado:** No mejoró
- **Hipótesis descartada:** El problema no era que el ring reducía el área del contenido

#### Intento 3: Estructura similar a YalaToolbarButton
- **Cambio:**
  - Reestructurar body para que sea: `Button { avatar.frame().contentShape() }`
  - Mover spark badge FUERA del Button como overlay del Button completo
  - Usar `contentShape(Rectangle())` igual que YalaToolbarButton
- **Resultado:** No mejoró
- **Hipótesis descartada:** El problema no era la estructura del Button ni el spark badge afectando el tamaño

### Hipótesis Pendientes
- [ ] iOS trata diferente el contenido custom vs SF Symbols en toolbars
- [ ] Hay un modificador específico que YalaToolbarButton hereda del sistema
- [ ] El Image(uiImage:) se comporta diferente a Image(systemName:)
- [ ] Falta algún modificador de escala o rendering mode

### Próximo Intento
(Por definir)

---

## Problema 2: Toolbar Múltiple (RecordsStandaloneView, DetailContainerView, PlanningView) ✅ RESUELTO

### Solución Final
Añadir `placement: .topBarTrailing` al ToolbarSpacer:
```swift
ToolbarSpacer(.fixed, placement: .topBarTrailing)
```

### Objetivo Original
Usar `ToolbarSpacer(.fixed)` para que los botones de acción y el ProfileToolbarButton se vean como dos grupos glass separados (como en la imagen de Apple HIG).

### Estado anterior
El ToolbarSpacer no estaba creando la separación visual esperada. Los botones se veían juntos en lugar de en grupos separados.

### Estructura actual
```swift
@ToolbarContentBuilder
private var normalModeToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
        HStack(spacing: DS.Spacing.md) {
            // Action buttons...
        }
    }

    ToolbarSpacer(.fixed)

    ToolbarItem(placement: .topBarTrailing) {
        ProfileToolbarButton { ... }
    }
}
```

### Intentos Fallidos

#### Intento 1: ToolbarSpacer(.fixed) entre ToolbarItems
- **Cambio:** Separar los botones en dos ToolbarItems con ToolbarSpacer(.fixed) entre ellos
- **Resultado:** No hay separación visual, los botones no se ven como grupos glass separados
- **Hipótesis descartada:** (pendiente verificar si realmente no funciona o hay otro problema)

### Hipótesis Pendientes
- [x] ToolbarSpacer requiere configuración adicional para activar el efecto glass → **CONFIRMADO: necesita `placement`**
- [ ] Los ToolbarItems necesitan un orden específico
- [ ] Hay que usar un placement diferente
- [ ] El efecto glass separado solo funciona con ciertos tipos de contenido
- [ ] Puede que iOS 26 tenga un API diferente

---

## Investigación Completada (2026-02-05)

### Fuentes Consultadas
- [Apple Developer Documentation - ToolbarSpacer](https://developer.apple.com/documentation/SwiftUI/ToolbarSpacer)
- [ExploreSwiftUI - ToolbarSpacer](https://exploreswiftui.com/library/toolbars/toolbarspacer)
- [Swift with Majid - Glassifying toolbars](https://swiftwithmajid.com/2025/07/01/glassifying-toolbars-in-swiftui/)
- [WWDC25 - Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [ExploreSwiftUI - sharedBackgroundVisibility](https://exploreswiftui.com/library/toolbars/toolbaritem-shared-background-visibility)

### Hallazgos Clave

1. **`ToolbarSpacer` necesita `placement` explícito**
   - Documentación oficial muestra: `ToolbarSpacer(.fixed, placement: .primaryAction)`
   - El código actual usa: `ToolbarSpacer(.fixed)` sin placement
   - Sin placement, el spacer no sabe a qué grupo de items aplicar la separación

2. **`sharedBackgroundVisibility` modifier**
   - Controla si un item comparte el fondo glass con otros items del mismo grupo
   - `.sharedBackgroundVisibility(.hidden)` separa un item en su propio grupo SIN fondo glass
   - `.sharedBackgroundVisibility(.visible)` mantiene el fondo glass (default)

3. **Agrupación automática por placement**
   - Items con el mismo `placement` comparten automáticamente el fondo glass
   - `ToolbarSpacer` con placement correcto debe crear separación visual

### Hipótesis a Probar

#### Hipótesis A: Agregar `placement` a ToolbarSpacer
```swift
// Antes (no funciona)
ToolbarSpacer(.fixed)

// Después
ToolbarSpacer(.fixed, placement: .topBarTrailing)
```

#### Hipótesis B: Usar `sharedBackgroundVisibility`
```swift
ToolbarItem(placement: .topBarTrailing) {
    ProfileToolbarButton { }
}
.sharedBackgroundVisibility(.hidden)
```

#### Hipótesis C: Combinar ambas
```swift
ToolbarSpacer(.fixed, placement: .topBarTrailing)

ToolbarItem(placement: .topBarTrailing) {
    ProfileToolbarButton { }
}
.sharedBackgroundVisibility(.visible)  // Explícito para tener su propio glass
```

### Próximo Intento
**Implementar Hipótesis A** - Agregar `placement: .topBarTrailing` a todos los ToolbarSpacer

---

## Archivos Involucrados

| Archivo | Problema |
|---------|----------|
| `Yala/App/Views/Shared/ProfileToolbarButton.swift` | Problema 1 |
| `Yala/App/Views/Panel/PanelView.swift` | Problema 1 (toolbar único) |
| `Yala/App/Views/Records/RecordsStandaloneView.swift` | Problema 2 |
| `Yala/App/Views/Statistics/DetailContainerView.swift` | Problema 2 |
| `Yala/App/Views/Planning/PlanningView.swift` | Problema 2 |
| `Yala/App/Views/Shared/StandardButtons.swift` | Referencia (YalaToolbarButton) |

---

## Notas de Sesión

### 2026-02-05
- Iniciada investigación
- Documentados 3 intentos fallidos para Problema 1
- Documentado 1 intento para Problema 2
- Pendiente: definir próximos intentos
