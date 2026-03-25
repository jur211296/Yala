# Plan: Correcciones Visual Audit (5 hallazgos)

## Context

La auditoría visual de 36 pantallas encontró 5 hallazgos: 2 errores de texto (ALTO), 2 problemas de UI (MEDIO), y 1 de capitalización (MEDIO). Son cambios pequeños y localizados.

---

## Cambios

### V-1: "Sin datos aun" → "Sin datos aún" (tilde faltante)
**Archivo:** `Yala/Resources/es.lproj/Localizable.strings:876`
```
"insights.emptyTitle" = "Sin datos aun";
→ "insights.emptyTitle" = "Sin datos aún";
```
Solo afecta español (otros idiomas no tienen este problema).

---

### V-2: "tu gastos" — template gramatical incorrecto
**Archivos:** 6 Localizable.strings (es, en, de, fr, it, pt)

**Problema:** `"Cada %2$@ recibirás tu %1$@ de la semana"` con %1$@ = "gastos"/"ingresos" produce "tu gastos". El posesivo "tu" no concuerda con sustantivos plurales.

**Keys afectadas:** `notifications.weeklyReport.hint` y `notifications.monthlyReport.hint`

**Fix español:**
```
weekly: "Cada %2$@ recibirás tu %1$@ de la semana"
→      "Cada %2$@ recibirás un resumen de %1$@ de la semana"

monthly: "El %2$@ verás tu %1$@ del mes"
→        "El %2$@ recibirás un resumen de %1$@ del mes"
```

**Fix otros idiomas (verificar concordancia):**
- **en:** `"Every %2$@ you'll get your %1$@ for the week"` → OK con "your expenses/balance" — no necesita cambio
- **de:** `"Jeden %2$@ erhältst du dein %1$@ der Woche"` → "dein Ausgaben" incorrecto → `"Jeden %2$@ erhältst du eine Übersicht über %1$@ der Woche"`
- **fr:** `"Chaque %2$@ tu recevras ton %1$@ de la semaine"` → "ton dépenses" incorrecto → `"Chaque %2$@ tu recevras un résumé de %1$@ de la semaine"`
- **it:** `"Ogni %2$@ riceverai il tuo %1$@ della settimana"` → "il tuo spese" incorrecto → `"Ogni %2$@ riceverai un riepilogo di %1$@ della settimana"`
- **pt:** `"Toda %2$@ você receberá seu %1$@ da semana"` → "seu gastos" incorrecto → `"Toda %2$@ você receberá um resumo de %1$@ da semana"`

Aplicar el mismo patrón a `monthlyReport.hint` en cada idioma.

---

### V-3: Títulos de notificación truncados
**Archivo:** `Yala/App/Views/Settings/NotificationsSettingsView.swift:281`

**Problema:** `.lineLimit(1)` en el título de la NotificationCard trunca nombres largos como "Resumen semanal", "Pagos planificados".

**Fix:** Cambiar `.lineLimit(1)` → `.lineLimit(2)` en el título (línea 281). Esto permite que títulos largos fluyan a 2 líneas sin romper el layout del HStack.

---

### V-4: Banderas de divisa muestran "?"
**Archivos:** `Yala/Utils/CurrencyUtils.swift` (flag property, líneas 133-197)

**Análisis:** Las banderas usan emojis Unicode estándar (🇵🇪, 🇺🇸, etc.) renderizados con `Text(info.flag).font(DS.Typography.title)`. Este es el enfoque correcto y estándar en iOS.

**Decisión:** **No requiere cambio de código.** Los "?" son un artefacto del simulador (la captura de pantalla del MCP no renderiza emojis correctamente). En dispositivo real los emojis se ven bien. Documentar como "solo simulador" en el reporte.

---

### V-5: "Categoría Con Más Gasto" — capitalización incorrecta
**Archivo:** `Yala/App/Views/Settings/NotificationEditorSheet.swift:361`

**Problema:** `Text(dataType.displayName.capitalized)` aplica `.capitalized` que capitaliza TODAS las palabras → "categoría con más gasto" → "Categoría Con Más Gasto". En español, solo la primera palabra se capitaliza.

**Fix:** Cambiar `.capitalized` por una extensión que solo capitalice la primera letra:
```swift
// Reemplazar:
Text(dataType.displayName.capitalized)
// Con:
Text(dataType.displayName.localizedCapitalized)
```

Espera — `.localizedCapitalized` hace lo mismo (capitaliza cada palabra según locale). Necesito capitalizar solo la primera letra:

```swift
Text(dataType.displayName.prefix(1).uppercased() + dataType.displayName.dropFirst())
```

O más limpio, verificar si ya existe un helper. Si no, inline:
```swift
Text(dataType.displayName.sentenceCased)
```

Donde `sentenceCased` sería:
```swift
extension String {
    var sentenceCased: String {
        prefix(1).uppercased() + dropFirst()
    }
}
```

Verificar si ya existe esta extensión en el codebase. Si no, agregar inline sin crear extensión nueva (para no over-engineer):
```swift
Text(dataType.displayName.prefix(1).uppercased() + dataType.displayName.dropFirst())
```

---

## Archivos a modificar

| Archivo | Cambio | Riesgo |
|---------|--------|--------|
| `Yala/Resources/es.lproj/Localizable.strings` | V-1 (1 línea) + V-2 (2 líneas) | Bajo |
| `Yala/Resources/en.lproj/Localizable.strings` | V-2 (revisar, posiblemente sin cambio) | Bajo |
| `Yala/Resources/de.lproj/Localizable.strings` | V-2 (2 líneas) | Bajo |
| `Yala/Resources/fr.lproj/Localizable.strings` | V-2 (2 líneas) | Bajo |
| `Yala/Resources/it.lproj/Localizable.strings` | V-2 (2 líneas) | Bajo |
| `Yala/Resources/pt.lproj/Localizable.strings` | V-2 (2 líneas) | Bajo |
| `NotificationsSettingsView.swift:281` | V-3 (1 línea) | Bajo |
| `NotificationEditorSheet.swift:361` | V-5 (1 línea) | Bajo |

**Total:** ~15 edits en 8 archivos. Sin cambios de lógica ni modelo.

---

## Verificación

1. `/verify-ios` — build limpio
2. `/test-smart` — tests de notificaciones pasan
3. Verificación visual en simulador:
   - Estadísticas → Resumen: "Sin datos aún" (con tilde)
   - Perfil → Notificaciones → editar Resumen semanal: hint sin "tu gastos"
   - Perfil → Notificaciones: títulos no truncados
   - Notificaciones → editor → selector datos: "Categoría con más gasto" (no "Con Más Gasto")
4. Actualizar `VISUAL-AUDIT-REPORT.md` marcando hallazgos como resueltos
