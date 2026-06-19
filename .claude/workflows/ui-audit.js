export const meta = {
  name: 'ui-audit',
  description: 'Audita las vistas SwiftUI de Yala contra el Design System (tokens, botones, tipografía, backgrounds, glass, color, componentes, a11y) y escribe un reporte priorizado',
  whenToUse: 'Para validar consistencia de patrones UI a lo largo de toda la app contra el DS. Acepta args opcional { date, reportPath, onlyAreas } — onlyAreas es un array de nombres de carpeta (ej. ["Settings","Panel"]) para acotar el barrido.',
  phases: [
    { title: 'Descubrir', detail: 'inventario de carpetas de Views con conteo' },
    { title: 'Escanear', detail: 'un agente por chunk de ~8 vistas detecta violaciones del DS' },
    { title: 'Verificar', detail: 'verificación adversarial — refuta falsos positivos' },
    { title: 'Sintetizar', detail: 'redacta el reporte Markdown priorizado' },
  ],
}

// ---------------------------------------------------------------------------
// Parámetros (args opcional)
// ---------------------------------------------------------------------------
const DATE = (args && args.date) || ''
const REPORT_PATH = (args && args.reportPath) || 'AUDIT-UI-patterns.md'
const ONLY_AREAS = (args && Array.isArray(args.onlyAreas) && args.onlyAreas.length) ? args.onlyAreas : null
const CHUNK = 8
const VIEWS_ROOT = 'Yala/App/Views'

// ---------------------------------------------------------------------------
// Rulebook destilado — fuente de verdad para los agentes (código REAL, no docs)
// ---------------------------------------------------------------------------
const RULEBOOK = `
SISTEMA DE DISEÑO DE YALA — reglas canónicas. Validar contra el CÓDIGO REAL (no contra docs desactualizadas).

TOKENS (enum DS en Yala/App/Theme/DesignTokens.swift):
- DS.Spacing: xxs=2 xs=4 sm=8 md=12 lg=16 xl=20 xxl=24 xxxl=32 xxxxl=48 none=0 safeBottom=100 sheetTop=64 formIndent=52
- DS.Radius: xs=4 sm=8 md=12 card=14 lg=16 xl=24 full=9999
- DS.Typography: largeTitle, title, title2, headline, bodyBold, body, subheadline, subheadlineEmphasized, label, labelSmall, labelTiny, caption, captionSmall, badgeLabel, indicator, captionMono(Bold), chevron, chipIcon/chipClose/chipIconOnly, iconMedium, amountLarge, amount, amountSmall, heroAmount, heroAmountSecondary
- Dimensiones específicas: DS.Icon (badgeSmall24/Medium32/Large40, size12/16/20), DS.Button (fabSize56, actionSize44), DS.Chip, DS.FormRow, DS.ListRow (iconSize40), DS.Panel, DS.Card (radius24, padding20)
- DS.Semantic.*: success/warning/error/info/neutral {Background,Foreground}, favoriteIcon, disabledForeground, splitMethod{Background,Foreground}
- DS.Gradients.*: proBadge, subscription, success, warning, heroCalm/Neutral/Intense, heroIndigoBlack, spendingHeat, themeHero(for:)
- COLORES TEMÁTICOS REALES: theme.accent, theme.background, theme.cardBorder, .thCard, .thBackground, .thPrimaryText, .thSecondaryText
- COLORES DE MARCA: Color.electricIndigo (acción/ingresos), Color.hotPink (gastos), Color.transferColor (transferencias)
- MODIFIERS CANÓNICOS: .yalaScreenBackground(_:), .solidCard(padding:radius:), .panelCard(small:), .selectableCard(...), .yalaFormRow(...), .yalaSection(...), .yalaIconBadge{Small,Medium,Large}, .dismissKeyboardOnTap(), .scrollViewGlassEdges()
- COMPONENTES: YalaPrimaryButton, YalaSecondaryButton, YalaToolbarButton, YalaSaveButton, YalaEmptyState, YalaSectionHeader, PanelBackgroundView, ProcessingProgressView

DIMENSIONES A AUDITAR (cada finding lleva una 'dimension' y una 'severity' alta|media|baja):

[tokens] Spacing/Radius hardcodeado
  VIOLA: .padding(16), .padding(.horizontal, 12), .cornerRadius(8), RoundedRectangle(cornerRadius: 24), spacing: 8 en VStack/HStack, .frame(width: 40) cuando el valor mapea a un token (2→xxs,4→xs,8→sm,12→md,14→card,16→lg,20→xl,24→xxl/xl,32→xxxl,40→ListRow.iconSize/Icon.badgeLarge,44→Button.actionSize,56→Button.fabSize).
  ALTA: literal que mapea EXACTO a un token. MEDIA: valor mágico sin token equivalente. OK (no reportar): 0 trivial, proporciones de GeometryReader, offsets de animación, valores con comentario que explica por qué.

[tipografia] Fuente hardcodeada / jerarquía de títulos
  VIOLA: .font(.system(size: N)) en texto SIN marker // A11Y-DT adyacente; usar .font(.largeTitle)/.title/.title2/.headline/.subheadline/.caption NATIVO de SwiftUI en vez de DS.Typography.X; .fontWeight(...) manual sobre Text; montos sin amountLarge/amount/amountSmall/heroAmount.
  ALTA: .system(size:) en texto sin A11Y-DT; monto con fuente genérica. MEDIA: .font(.title) nativo (debe ser DS.Typography.title).
  OK: .font(.system(size:)) CON // A11Y-DT: adyacente; SF Symbol/Image con .font(.system(size:)) (preferir DS.Icon/DS.Chip → severidad baja); las definiciones dentro de DesignTokens.swift.
  ESPECIAL — jerarquía: títulos de pantalla = largeTitle; headers de sección = title/title2/headline. Reporta si una pantalla rompe la jerarquía tipográfica del resto de la app.

[botones] Homogeneidad de botones + áreas de toque
  VIOLA: Button full-width con .background(...)+.clipShape(Capsule()/RoundedRectangle) replicando a mano YalaPrimaryButton; CTA principal que NO usa YalaPrimaryButton; .onTapGesture en HStack/fila (debe ser Button + .buttonStyle(.plain) + .contentShape(Rectangle())); Button de solo-icono sin .accessibilityLabel; tap target < 44pt; height de botón distinta de 50 en un primario/secundario sin razón.
  ALTA: CTA primario reimplementado a mano; .onTapGesture en fila clicable. MEDIA: divergencia de tamaño/estilo entre botones equivalentes. OK: FAB (56pt), chips glass, botones via ToolbarItem.

[backgrounds] Fondo de vista raíz
  VIOLA: View raíz / .sheet / .fullScreenCover con .background(theme.background) / .background(.thBackground) / sin background / default iOS, en vez de .yalaScreenBackground(_:).
  ALTA: .background(.thBackground) directo en raíz nueva, o sin background. BAJA (informativo): Pattern B = ZStack { PanelBackgroundView(); content } — deuda incremental ACEPTADA, migrar al tocar; repórtalo como baja.
  OK (NO reportar): Pattern Subtle en success screens (TransactionSuccessView/SubscriptionSuccessView/InboxApproveSuccessView/InboxBulkApproveSuccessView con ZStack theme.background + overlays); WelcomeFlow (heroIndigoBlack); InboxAlertModal (backdrop Color.black); popovers; Form/List que ya tienen .scrollContentBackground(.hidden).

[glass-cards] iOS 26 Liquid Glass
  VIOLA: ToolbarSpacer SIN placement (ej. ToolbarSpacer(.fixed) sin placement: .topBarTrailing); chip/barra flotante con .background(Color.gray.opacity(...)) en vez de .glassEffect(); card con .background(.thCard)+.overlay(stroke)+.shadow manual en vez de .solidCard(); uso de .glassSheet() o .presentationBackground(.ultraThinMaterial) (DEPRECADO); .glassCard()/.yalaCard() legacy.
  ALTA: ToolbarSpacer sin placement; .glassSheet() usado; card manual reimplementando solidCard. MEDIA: chip sin glassEffect. OK: .solidCard()/.glassEffect()/.panelCard() correctos; definiciones internas del DS; .yalaCard en #Preview.

[color] Color hardcodeado / Dark Mode
  VIOLA: Color(red:green:blue:), Color(hex: "...") literal, o Color.gray/.black/.white/.blue para texto o fondo SIN marker // A11Y-DM.
  ALTA: Color(hex hardcoded para UI sin marker; Color.black/.white como fondo. MEDIA: Color.gray para texto (usar .thSecondaryText/.secondary).
  OK (NO reportar): líneas con // A11Y-DM:; Color(hex:) derivado de DATOS dinámicos del usuario (color de categoría/tag/cuenta); DS.Semantic/DS.Gradients que usan Color.green/.red/.orange internamente; Color.white como foreground sobre fondo de marca (theme.accent / gradiente); .opacity decorativo sobre un color válido.

[componentes] Reúso de componentes estándar
  VIOLA: empty state reimplementado a mano (VStack con icono ~48pt + título + mensaje + botón) en vez de YalaEmptyState; loading custom en vez de los componentes Yala de loading; header de sección a mano en vez de YalaSectionHeader; icon badge a mano en vez de .yalaIconBadge*.
  ALTA: empty state a mano. MEDIA: section header / icon badge a mano.

[a11y] Accesibilidad
  VIOLA: Button/Image interactivo sin .accessibilityLabel; tap target < 44pt; falta de .accessibilityElement / .accessibilityAddTraits(.isHeader) donde corresponde.
  MEDIA por defecto; ALTA si es un control primario sin label.

EXCEPCIONES GLOBALES (NUNCA reportar como violación):
- Cualquier línea con // A11Y-DT: (font fija justificada) o // A11Y-DM: (color fijo justificado), incluyendo la línea inmediatamente anterior/posterior que el marker justifica.
- Definiciones del propio DS: archivos Yala/App/Theme/DesignTokens.swift y ViewModifiers.swift son la FUENTE, no callsites.
- Bloques #Preview { } (código de preview, no de producción) — si acaso, severidad baja.
- Color(hex:) / colores derivados de datos del usuario (categorías, tags, cuentas tienen color propio).
- Gradientes/colores de marca intencionales documentados (heroIndigoBlack en Welcome, etc.).
`

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------
const INVENTORY_SCHEMA = {
  type: 'object',
  properties: {
    dirs: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          dir: { type: 'string', description: 'ruta de carpeta relativa al repo' },
          count: { type: 'integer', description: 'nº de .swift DIRECTOS en esa carpeta (no recursivo)' },
        },
        required: ['dir', 'count'],
      },
    },
  },
  required: ['dirs'],
}

const FINDING_PROPS = {
  file: { type: 'string', description: 'path relativo desde la raíz del repo' },
  line: { type: 'integer', description: 'número de línea real' },
  dimension: { type: 'string', enum: ['tokens', 'tipografia', 'botones', 'backgrounds', 'glass-cards', 'color', 'componentes', 'a11y'] },
  severity: { type: 'string', enum: ['alta', 'media', 'baja'] },
  rule: { type: 'string', description: 'regla violada, corta' },
  snippet: { type: 'string', description: 'la línea ofensora recortada a ~120 chars' },
  fix: { type: 'string', description: 'qué token/componente usar, 1 frase' },
}
const FINDING_ITEM = { type: 'object', properties: FINDING_PROPS, required: ['file', 'line', 'dimension', 'severity', 'rule', 'snippet', 'fix'] }

const SCAN_SCHEMA = { type: 'object', properties: { findings: { type: 'array', items: FINDING_ITEM } }, required: ['findings'] }
const VERIFY_SCHEMA = { type: 'object', properties: { confirmed: { type: 'array', items: FINDING_ITEM } }, required: ['confirmed'] }
const SUMMARY_SCHEMA = {
  type: 'object',
  properties: {
    reportPath: { type: 'string' },
    total: { type: 'integer' },
    highlights: { type: 'array', items: { type: 'string' }, description: '5-8 frases con los hallazgos más importantes/recurrentes' },
  },
  required: ['reportPath', 'total'],
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function areaLabel(task) {
  const base = task.dir.replace(VIEWS_ROOT + '/', '').replace(VIEWS_ROOT, 'root') || 'root'
  return task.totalParts > 1 ? base + ' [' + task.part + '/' + task.totalParts + ']' : base
}
function tally(arr, key) {
  const m = {}
  for (const x of arr) { const k = x[key] || '?'; m[k] = (m[k] || 0) + 1 }
  return Object.entries(m).sort((a, b) => b[1] - a[1]).map(([k, v]) => ({ key: k, count: v }))
}

// ---------------------------------------------------------------------------
// Fase 1 — Descubrir inventario de carpetas
// ---------------------------------------------------------------------------
phase('Descubrir')
const inventory = await agent(
  'Lista las carpetas que contienen vistas SwiftUI bajo ' + VIEWS_ROOT + ' con el conteo de archivos .swift DIRECTOS en cada una.\n' +
  'Ejecuta exactamente: find ' + VIEWS_ROOT + ' -name "*.swift" -type f | sed "s|/[^/]*$||" | sort | uniq -c\n' +
  'Cada línea de salida es "<count> <dir>". Devuelve { dirs: [{ dir, count }] } con esos valores tal cual (dir relativo al repo, count entero). No incluyas carpetas sin .swift.',
  { label: 'inventario', phase: 'Descubrir', model: 'sonnet', schema: INVENTORY_SCHEMA }
)

let dirs = (inventory && inventory.dirs) || []
if (ONLY_AREAS) {
  dirs = dirs.filter(d => ONLY_AREAS.some(a => d.dir.endsWith('/' + a) || d.dir.endsWith(a)))
}

// Construir chunks (tareas) de máximo CHUNK archivos por agente
const tasks = []
for (const { dir, count } of dirs) {
  const totalParts = Math.max(1, Math.ceil(count / CHUNK))
  for (let p = 1; p <= totalParts; p++) tasks.push({ dir, part: p, totalParts, count })
}
log('Inventario: ' + dirs.length + ' carpetas, ' + dirs.reduce((s, d) => s + d.count, 0) + ' vistas → ' + tasks.length + ' chunks de ≤' + CHUNK)

if (!tasks.length) {
  return { error: 'No se descubrieron vistas. Revisa el inventario.', inventory }
}

// ---------------------------------------------------------------------------
// Fase 2+3 — Escanear (fan-out) → Verificar (adversarial) por chunk
// ---------------------------------------------------------------------------
const results = (await pipeline(
  tasks,
  // Stage 1: escanear
  (task) => {
    const start = (task.part - 1) * CHUNK
    const end = task.part * CHUNK
    return agent(
      'Eres un auditor de UI de Yala (app iOS SwiftUI). Audita un subconjunto de vistas contra el Design System.\n\n' +
      'PASO 1 — Descubre tus archivos asignados:\n' +
      'Ejecuta: find ' + task.dir + ' -maxdepth 1 -name "*.swift" -type f | sort\n' +
      'De esa lista ORDENADA, audita SOLO los archivos en las posiciones [' + start + ', ' + end + ') (0-indexed; máximo ' + CHUNK + '). Ignora el resto — los audita otro agente.\n\n' +
      'PASO 2 — Audita cada archivo asignado. Usa Grep para localizar patrones rápido (padding/spacing con literal numérico, .font(.system(size:)), Color(red: y Color(hex:, cornerRadius con literal, .onTapGesture, .background(.thBackground)/.background(theme.background), .glassSheet, ToolbarSpacer, .background(Color.gray) y similares) y luego Read para confirmar el contexto y obtener el número de línea REAL.\n\n' +
      'REGLAS DEL DESIGN SYSTEM:\n' + RULEBOOK + '\n\n' +
      'Reporta CADA violación como un finding: file (path relativo desde la raíz del repo), line (real), dimension, severity, rule (corta), snippet (línea ofensora ≤120 chars), fix (1 frase con el token/componente correcto).\n' +
      'Sé preciso y CONSERVADOR: respeta TODAS las excepciones del rulebook (markers A11Y, datos dinámicos, deuda aceptada Pattern B, #Preview, definiciones del DS). Ante la duda, usa severity "baja"; no inventes. NO reportes archivos fuera de tu rango.\n' +
      'Devuelve { findings: [...] } (vacío si el código está limpio).',
      { label: 'scan:' + areaLabel(task), phase: 'Escanear', model: 'sonnet', schema: SCAN_SCHEMA }
    )
  },
  // Stage 2: verificar adversarialmente (solo alta+media; las bajas pasan tal cual)
  (scan, task) => {
    const findings = (scan && scan.findings) || []
    const toVerify = findings.filter(f => f.severity === 'alta' || f.severity === 'media')
    const lows = findings.filter(f => f.severity === 'baja')
    if (!toVerify.length) return { area: areaLabel(task), findings: lows }
    return agent(
      'Eres un verificador ADVERSARIAL de auditoría UI. Te doy findings candidatos; tu trabajo es REFUTAR los falsos positivos abriendo el código real.\n\n' +
      'Para cada candidato: abre el archivo en la línea indicada (Read) y lee el contexto. Decide si es una violación REAL del Design System o está justificada por una excepción: marker // A11Y-DT o // A11Y-DM adyacente, color derivado de datos del usuario, deuda aceptada Pattern B (ZStack{PanelBackgroundView()}), bloque #Preview, definición del propio DS, o color/gradiente de marca intencional.\n' +
      'Sé escéptico: si está justificada, o no estás seguro de que sea violación real, DESCÁRTALA. Puedes ajustar la severity si el candidato la exageró.\n\n' +
      'REGLAS DEL DESIGN SYSTEM (para juzgar excepciones):\n' + RULEBOOK + '\n\n' +
      'FINDINGS CANDIDATOS (JSON):\n' + JSON.stringify(toVerify) + '\n\n' +
      'Devuelve { confirmed: [...] } SOLO con las violaciones reales, con sus campos finales (file, line, dimension, severity ajustada, rule, snippet, fix).',
      { label: 'verify:' + areaLabel(task), phase: 'Verificar', model: 'sonnet', schema: VERIFY_SCHEMA }
    ).then(v => ({ area: areaLabel(task), findings: [...((v && v.confirmed) || []), ...lows] }))
  }
)).filter(Boolean)

// Aplanar todos los findings (anotando el área)
const all = results.flatMap(r => (r.findings || []).map(f => ({ ...f, area: r.area })))

// Resumen computado en JS (siempre disponible, barato, independiente del sintetizador)
const bySeverity = tally(all, 'severity')
const byDimension = tally(all, 'dimension')
const byArea = tally(all, 'area')
log('Hallazgos confirmados: ' + all.length + ' (alta/media verificados, baja sin verificar)')

if (!all.length) {
  return { total: 0, message: 'Sin hallazgos: las vistas auditadas respetan el Design System.', bySeverity, byDimension, byArea, reportWritten: false }
}

// ---------------------------------------------------------------------------
// Fase 4 — Sintetizar reporte Markdown
// ---------------------------------------------------------------------------
phase('Sintetizar')
const summary = await agent(
  'Eres el redactor del informe de auditoría de patrones UI de Yala. Te doy TODOS los hallazgos confirmados. Escribe un informe Markdown claro y accionable, en ESPAÑOL.\n\n' +
  'ESCRIBE el archivo usando la herramienta Write en la ruta: ' + REPORT_PATH + '\n\n' +
  'Estructura obligatoria del informe:\n' +
  '1. "# Auditoría de patrones UI — Yala"' + (DATE ? ' (incluye la fecha: ' + DATE + ')' : '') + ' + una línea de alcance (total de hallazgos, nº de áreas).\n' +
  '2. "## Resumen ejecutivo": tabla de conteos por severidad (alta/media/baja); tabla por dimensión; top 8 áreas con más hallazgos.\n' +
  '3. "## Hallazgos por dimensión": una subsección por cada dimensión presente (tokens, tipografia, botones, backgrounds, glass-cards, color, componentes, a11y). Dentro de cada una, ORDENA por severidad (alta→media→baja) y usa una tabla: | Archivo:línea | Severidad | Regla | Snippet | Fix |. Usa rutas relativas tal cual (son clicables).\n' +
  '4. "## Deuda aceptada y notas": menciona explícitamente que (a) el Pattern B `ZStack { PanelBackgroundView(); content }` es deuda incremental ACEPTADA (migrar al tocar el archivo, no es bug); (b) hay desincronización entre UI-PATTERNS.md (menciona Color.yalaCard / YalaTextButton) y el código real (usa theme.* / .thCard y NO existe YalaTextButton) — recomienda actualizar el doc.\n' +
  '5. "## Quick wins": 5-10 arreglos de mayor impacto y menor riesgo (los literales que mapean exacto a un token, los .glassSheet(), los empty states a mano).\n' +
  'Sé conciso en prosa; los datos van en tablas. No omitas hallazgos: si una dimensión tiene muchos, agrúpalos pero inclúyelos todos.\n\n' +
  'HALLAZGOS (JSON):\n' + JSON.stringify(all) + '\n\n' +
  'Tras escribir el archivo, devuelve { reportPath, total, highlights: [5-8 frases con lo más importante/recurrente] }.',
  { label: 'reporte', phase: 'Sintetizar', schema: SUMMARY_SCHEMA }
)

return {
  reportPath: REPORT_PATH,
  reportWritten: !!summary,
  total: all.length,
  bySeverity,
  byDimension,
  byArea: byArea.slice(0, 10),
  highlights: (summary && summary.highlights) || [],
}
