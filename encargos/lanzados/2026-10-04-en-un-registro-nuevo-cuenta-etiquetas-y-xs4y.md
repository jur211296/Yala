# En un registro nuevo, cuenta / etiquetas / subcategoría abren en detent medium

## Contexto
Versión 2.1. Diseño antes del QA del lunes (Jürgen 2026-10-04).

El formulario de cuenta del PR #341 (cuenta como hoja medium) YA ESTÁ HECHO y NO SE TOCA. Este ticket es otra cosa: los selectores DENTRO de un registro nuevo — cuenta, etiquetas y subcategoría — cuando el usuario los abre desde Nuevo registro.

Aplica a los tres sitios con el mismo patrón:
1. Registro nuevo normal
2. Registro nuevo en grupos
3. Registro nuevo en Yala IA (la card / hoja de detalles que acaba de salir en la propuesta A)

Al tocar cuenta, etiquetas o subcategoría, la hoja debe abrir en detent medium. Solo pasa a large si el usuario la estira. No debe saltar de golpe a pantalla completa.

## Qué hay que hacer
- Revisar dónde abren hoy esos tres selectores en Nuevo registro (normal, grupos y Yala IA).
- Hacer que abran en medium por defecto y permitan stretch a large.
- No reinventar el formulario de cuenta del PR #341; reutilizar el patrón de selectores ya usado en Nuevo registro / card de Yala IA si encaja.
- Capturas antes/después en iPhone sim.
- Si el diseño fino no está cerrado o hay ambigüedad real, deja 2–3 propuestas cortas en el PR/ticket y PARA esperando decisión. No inventes producto.

## Criterio de éxito
- Desde un registro nuevo (normal), tocar cuenta / etiquetas / subcategoría abre medium; stretch → large.
- Mismo comportamiento en grupos y en Yala IA si comparten el patrón.
- El formulario de cuenta del PR #341 sigue igual.
- Gate verde; ticket a qa con guion device-QA si hace falta iPhone.
- Puede cerrar solo: al terminar, /cerrar-total (limpia sim/worktree según normas; PR a 2.1 con auto-merge si aplica).

## Fuera de alcance
- Revisar uso de IA / modelos / coste
- Partir IA nube vs privado
- Dictado, voz, imagen, barrido QA, TestFlight (van después)

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Dónde se declara el detent.** Dentro de los tres selectores (`AccountSelectorSheet`, `TagSelectorSheet`,
   `SubcategorySelectorSheet`), con un parámetro opt-in `sizing: .mediumFirst`; el default `.large` deja a los otros
   ~12 anfitriones (edición masiva, Inbox, favoritos, pagos programados…) exactamente como están. Dentro y no en el
   anfitrión porque el fondo (transparente a media altura, `.subtle` en grande) vive dentro de la hoja.
2. **Alcance.** Nuevo registro (cuenta, origen y destino de transferencia, subcategoría, etiquetas), formulario de gasto
   de grupo (cuenta y subcategoría; no tiene etiquetas) y los selectores de la card de Yala IA (`ChatDraftFieldSheet`,
   PR #348). Fecha y «necesidad» no se tocan: no se pidieron.
3. **Patrón.** El de `AccountFormView` (#341), que no se toca: `[.medium, .large]` por `.yalaSheetDetents`, grande en
   ventana ancha y con texto de accesibilidad (AX1–AX5), fondo transparente/`.subtle`.
4. **Yala IA depende del PR #348** (en cola de auto-merge). Si mergea durante la sesión, rebaso e incluyo
   `ChatDraftFieldSheet`; si no, queda como seguimiento en el ticket.
5. **Diseño.** No hay ambigüedad de producto: el encargo fija medium→large. No hacen falta propuestas.
   → **Resuelto:** #348 mergeó a media sesión; `ChatDraftFieldSheet` entra en este PR.
