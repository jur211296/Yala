---
description: Verifica cumplimiento del Design System en vistas — tokens, componentes, APIs modernas
allowed-tools: Grep, Glob, Read
argument-hint: "[archivo o directorio — default: Yala/App/Views/]"
---

Verificación exhaustiva de cumplimiento con el Design System de Yala y APIs modernas de SwiftUI.

## ALCANCE

Si hay argumento ($ARGUMENTS): escanear ese archivo/directorio.
Si no: escanear todo `Yala/App/Views/`.

## PASO 1: TYPOGRAPHY

### A. Fonts hardcodeados
```
Grep: .font\(.system\(size: en archivos .swift
```
Cada instancia debería usar un token de DS.Typography:
- `DS.Typography.amountLarge` (montos grandes)
- `DS.Typography.amountMedium` (montos medianos)
- `DS.Typography.bodyBold` (texto destacado)
- `DS.Typography.body` (texto normal)
- `DS.Typography.caption` (texto secundario)
- `DS.Typography.captionBold` (labels)

Reportar: archivo, línea, tamaño usado, token sugerido.

### B. Weight sin token
```
Grep: .fontWeight\( en archivos .swift
```
Verificar si el contexto ya tiene un token de DS.Typography que incluya el weight.

## PASO 2: SPACING

### A. Padding hardcodeado
```
Grep: .padding\(\d en archivos .swift
Grep: .padding\(\.\w+,\s*\d en archivos .swift
```
Excluir: `.padding(.horizontal, DS.Spacing.` (correcto).
Cada número literal debería ser un DS.Spacing token.

### B. Spacing en VStack/HStack
```
Grep: (VStack|HStack|LazyVStack|LazyHStack)\(spacing:\s*\d en archivos .swift
```
Deberían usar DS.Spacing tokens.

### C. Frame con números mágicos
```
Grep: .frame\((width|height):\s*\d en archivos .swift
```
Verificar si son dimensiones que deberían ser tokens (botones, iconos, separadores).
Excluir: frames de gráficas y layouts específicos del contexto.

## PASO 3: COLORES

### A. Colores no semánticos
```
Grep: Color\.(blue|red|green|gray|yellow|orange|purple|pink|white|black|clear) en .swift
```
Deberían usar colores semánticos del tema: Color.yalaCard, Color.electricIndigo, etc.
Excepción: Color.clear es válido, Color.white/black en contextos específicos.

### B. Colores hex/RGB
```
Grep: Color\(red:|Color\(#|Color\(hex|UIColor\(red: en .swift
```
Deberían estar definidos como extensiones en el tema.

## PASO 4: COMPONENTES ESTÁNDAR

### A. Botones
```
Grep: Button\( en Views/ — count total
Grep: YalaPrimaryButton|YalaSecondaryButton|YalaDestructiveButton — count estándar
```
Reportar ratio de uso de componentes estándar vs custom.

### B. Empty states
```
Grep: YalaEmptyState en Views/ — count
```
Verificar que vistas principales tienen empty state con componente estándar.

### C. Section headers
```
Grep: YalaSectionHeader en Views/ — count
```
Verificar consistencia.

## PASO 5: APIs MODERNAS

### A. Deprecated
```
Grep: foregroundColor\( → debería ser foregroundStyle
Grep: \.cornerRadius\( → debería ser .clipShape(RoundedRectangle)
Grep: \.accentColor\( → debería ser .tint
Grep: onChange.*\{.*newValue in → firma vieja de onChange
```

### B. iOS 26 oportunidades
```
Grep: .background\(Material → puede usar .glassEffect()
Grep: \.sheet\(isPresented → evaluar si .sheet(item:) es mejor
```

## REPORTE

```
## DS Compliance — [N] archivos

### Typography
| Hardcodeados | Con token DS | Compliance |
|-------------|--------------|------------|
| N | N | X% |

Top archivos con más fonts hardcodeados:
1. [Archivo] — N instancias
2. ...

### Spacing
| Hardcodeados | Con token DS | Compliance |
|-------------|--------------|------------|
| N | N | X% |

### Colores
| No semánticos | Semánticos | Compliance |
|---------------|------------|------------|
| N | N | X% |

### Componentes
| Componente | Usos estándar | Usos custom | Compliance |
|------------|---------------|-------------|------------|
| Buttons | N | N | X% |
| Empty States | N | N | X% |

### APIs Deprecated
| API | Count | Reemplazo |
|-----|-------|-----------|
| foregroundColor | N | foregroundStyle |
| cornerRadius | N | clipShape |
| ... | ... | ... |

### Score: [A-F]
- A: >90% compliance
- B: 75-90%
- C: 50-75%
- D: 25-50%
- F: <25%
```

## NOTAS
- Este skill es para revisiones periódicas, no para uso diario
- `/swift-audit` ya cubre checks básicos de DS para archivos modificados
- Este skill escanea TODO el proyecto para baseline y progreso
- Ideal ejecutar 1x por fase para medir mejora
- Los scores ayudan a priorizar deuda técnica de UI
