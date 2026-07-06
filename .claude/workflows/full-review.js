export const meta = {
  name: 'full-review',
  description: 'Revisión profunda pre-release de toda la app: build+tests, calidad de código, concurrencia, performance, SwiftData/CloudKit, l10n, privacy/Apple compliance, dead code, coverage QA e higiene de release. Escribe un reporte de gaps priorizado con veredicto.',
  whenToUse: 'Antes de un release (TestFlight importante o App Store) para identificar gaps. Args opcionales: { date, reportPath, chunk, skipBuild, skipTests, skipSweep, onlySpecialists: ["l10n","privacy",...] } para re-runs acotados. NO cubre DS/UI-tokens ni a11y visual (eso es /ui-audit, épico ya cerrado en AUDIT-UI-patterns.md).',
  phases: [
    { title: 'Fundamentos', detail: 'build limpio + suite de tests (corre en paralelo con el resto)' },
    { title: 'Inventario', detail: 'lista completa de .swift bajo Yala/' },
    { title: 'Barrido', detail: 'un agente por chunk de archivos — calidad, concurrencia, perf, gotchas' },
    { title: 'Especialistas', detail: 'SwiftData, l10n, privacy, dead-code, coverage QA, higiene de release' },
    { title: 'Verificar', detail: 'verificación adversarial — refuta falsos positivos' },
    { title: 'Sintetizar', detail: 'reporte Markdown priorizado con veredicto de release' },
  ],
}

// ---------------------------------------------------------------------------
// Parámetros (args opcional)
// ---------------------------------------------------------------------------
const DATE = (args && args.date) || ''
const REPORT_PATH = (args && args.reportPath) || 'AUDIT-release-readiness.md'
const CHUNK = (args && args.chunk) || 12
const SKIP_BUILD = !!(args && args.skipBuild)
const SKIP_TESTS = !!(args && args.skipTests)
const SKIP_SWEEP = !!(args && args.skipSweep)
const ONLY_SPECIALISTS = (args && Array.isArray(args.onlySpecialists) && args.onlySpecialists.length) ? args.onlySpecialists : null
const CODE_ROOT = 'Yala'

// ---------------------------------------------------------------------------
// Rulebook del barrido — Reglas Inviolables del proyecto destiladas (CLAUDE.md)
// ---------------------------------------------------------------------------
const RULEBOOK =
  'REGLAS DEL PROYECTO YALA (iOS 26+, SwiftUI, SwiftData+CloudKit). Cada finding lleva dimension y severity (bloqueante|alta|media|baja).\n' +
  '\n' +
  '[errores] Manejo de errores y unwraps\n' +
  '  VIOLA: try? que silencia un error recuperable (la regla es do/catch con print en #if DEBUG); force unwrap (!) sin guard/validacion previa en paths alcanzables; fatalError/preconditionFailure alcanzable con datos de usuario; as! forzado sobre tipos no garantizados.\n' +
  '  BLOQUEANTE: force unwrap/fatalError en path de datos de usuario que puede crashear en produccion. ALTA: try? que traga errores de save()/fetch de SwiftData o de servicios. MEDIA: try? en operacion best-effort sin log.\n' +
  '  OK: URL(string:)! sobre literal constante valido; force unwrap tras guard explicito en lineas previas; codigo de #Preview o DEBUG-only.\n' +
  '\n' +
  '[logs] Privacidad de logs\n' +
  '  VIOLA: print/Logger/os_log FUERA de #if DEBUG (revisa si el bloque envolvente ya es DEBUG); peor si interpola montos, nombres, emails, IDs de usuario o contenido de transacciones.\n' +
  '  BLOQUEANTE: log con datos sensibles del usuario en build de produccion. MEDIA: print() generico fuera de DEBUG.\n' +
  '  OK: print dentro de #if DEBUG; assertionFailure (no-op en release).\n' +
  '\n' +
  '[state] State management SwiftUI\n' +
  '  VIOLA: @Observable class sin @MainActor; @AppStorage DENTRO de un @Observable (no triggerea updates — bug real); Binding(get:set:) construido en body; @State no private; @AppStorage directo en Views (las preferencias van por AppPreferences via @Environment); ObservableObject/@Published/@StateObject en codigo nuevo.\n' +
  '  ALTA: @AppStorage en @Observable; @Observable que toca ModelContext sin @MainActor. MEDIA: Binding(get:set:) en body; @AppStorage directo en View. BAJA: @State sin private; ObservableObject legacy.\n' +
  '\n' +
  '[swiftdata-uso] Uso de SwiftData fuera de modelos\n' +
  '  VIOLA: servicio/clase que manipula ModelContext sin @MainActor; context.save() con try? silencioso; mutacion de @Model desde Task.detached u off-main; FetchDescriptor con predicate que usa enum directo (CloudKit-backed: usar rawValue) o sin nil-guard en campos opcionales.\n' +
  '  ALTA: ModelContext off-main; try? context.save(). MEDIA: predicate fragil.\n' +
  '\n' +
  '[concurrencia] Concurrencia\n' +
  '  VIOLA: Task.detached sin justificacion (pierde contexto del actor); Task con loop/sleep no cancelado en .onDisappear; Task.sleep para "esperar" estado en logica de produccion (deben ser señales deterministicas); DispatchQueue.main.asyncAfter para secuenciar UI donde existe API estructurada; captura fuerte de self en closure escapante de objeto con ciclo de vida largo (servicios singleton con observers).\n' +
  '  ALTA: race obvia (estado compartido mutado desde varios contextos sin proteccion). MEDIA: el resto.\n' +
  '\n' +
  '[performance] Performance\n' +
  '  VIOLA: DateFormatter/NumberFormatter/ISO8601DateFormatter creado dentro de loop, body o funcion llamada por fila (deben ser static/cached); FetchDescriptor sin fetchLimit cuando solo se usa .first o count; trabajo O(n²) sobre colecciones potencialmente grandes (miles de TX) en hot path; ForEach sobre coleccion grande sin identidad estable; calculo costoso repetido en body sin cache.\n' +
  '  MEDIA por defecto; ALTA si esta en hot path de arranque o por-fila de listas de transacciones.\n' +
  '\n' +
  '[fechas] Inyectabilidad de fechas\n' +
  '  VIOLA: Date() / Calendar.current usado directo DENTRO de calculators/services con logica de negocio testeable (el patron canonico del proyecto es param opcional now: Date = .now, ej. FinancialScoreCalculator).\n' +
  '  MEDIA. OK: en Views para display, en telemetria, en codigo no testeable.\n' +
  '\n' +
  '[l10n-hardcoded] Strings de UI sin localizar\n' +
  '  VIOLA: Text("literal en español o ingles") user-facing en Views que no pasa por L10n.* / ls() / NSLocalizedString / String(localized:).\n' +
  '  ALTA si es UI visible (titulos, botones, mensajes). OK: identificadores tecnicos, accessibilityIdentifier, SF Symbol names, strings de DEBUG, interpolaciones de valores.\n' +
  '\n' +
  '[gotchas] Gotchas conocidos del proyecto (criticos)\n' +
  '  VIOLA: containerRelativeFrame(.horizontal) dentro de ScrollView(.vertical) con .contentMargins (deadlock de layout conocido — splash nunca dismissa); contenido de Swift Charts .annotation { } que contiene una sub-View que lee @Environment (AppPreferences/theme) — SIGTRAP conocido, dentro de annotations solo Text con valor ya resuelto (en .chartOverlay SI se propaga); vista que usa YalaFormatter con decimalPlaces/currencyDisplayFormat sin leer appPreferences en body para registrar dependencia; TextField/TextEditor/SecureField fuera de Form sin dismissKeyboardOnTap().\n' +
  '  ALTA los dos primeros (crashes/deadlocks reales ya sufridos). MEDIA los otros.\n' +
  '\n' +
  'EXCEPCIONES GLOBALES (NUNCA reportar):\n' +
  '- Bloques #if DEBUG completos y bloques #Preview { }.\n' +
  '- Lineas con marker // A11Y-DT: o // A11Y-DM: (y la linea que justifican).\n' +
  '- Codigo con comentario adyacente que explica el porque (decision consciente documentada).\n' +
  '- Archivos del propio Design System (Yala/App/Theme/DesignTokens.swift, ViewModifiers.swift) como definiciones.\n' +
  '- NO audites estilo visual/tokens DS/tipografia/a11y visual — eso lo cubre otro workflow (/ui-audit).\n'

// ---------------------------------------------------------------------------
// Especialistas — dimensiones globales que no se auditan archivo-a-archivo
// ---------------------------------------------------------------------------
const SPECIALISTS = [
  {
    key: 'swiftdata-modelo',
    verify: true,
    prompt:
      'Eres auditor de modelos SwiftData con CloudKit en Yala. Audita TODOS los archivos de Yala/Models/ (lista con: find Yala/Models -name "*.swift").\n' +
      'REGLAS (CloudKit compat es innegociable):\n' +
      '- @Attribute(.unique) esta PROHIBIDO con CloudKit → BLOQUEANTE.\n' +
      '- Toda propiedad almacenada debe tener default (o init que lo garantice) → ALTA si falta.\n' +
      '- Relaciones DEBEN ser opcionales con CloudKit → ALTA si non-optional.\n' +
      '- Toda relacion bidireccional DEBE declarar @Relationship(inverse:) en un lado → ALTA si falta.\n' +
      '- deleteRule revisado: cascade donde deberia ser nullify (o viceversa) segun semantica → MEDIA con justificacion.\n' +
      '- Patron CSV-mirror del proyecto: si una @Relationship M2M [Type]? se usa para calculos/filtros criticos y NO tiene espejo CSV (como Budget.subcategoryIDs o TransactionItem.tagIDs), señalalo → MEDIA (riesgo lazy hydration CloudKit).\n' +
      'Para cada violacion: file, line real, dimension "swiftdata-modelo", severity, rule corta, snippet ≤120 chars, fix 1 frase. Se conservador: lee el modelo completo antes de afirmar que falta un inverse (puede estar declarado en el otro lado).',
  },
  {
    key: 'l10n',
    verify: true,
    prompt:
      'Eres auditor de localizacion de Yala (16 locales). Localiza los .lproj con: find Yala -name "*.lproj" -type d.\n' +
      'AUDITA:\n' +
      '1. PARIDAD DE VARIANTES (regla critica del proyecto): es-ES, es-AR, en-GB y pt-PT deben tener TODAS las keys de su padre (es-419, en, pt-BR respectivamente). iOS NO hace fallback per-key con idioma de sistema — una key faltante en la variante renderiza la key cruda. Compara conteos y keys con grep/sort/comm sobre los Localizable.strings.\n' +
      '2. Keys con string VACIO ("").\n' +
      '3. PLACEHOLDERS inconsistentes entre locales para la misma key (%@ vs %d, falta de notacion posicional %1$@ donde otros locales la usan).\n' +
      '4. Keys huerfanas: muestrea ~30 keys sospechosas (las que parezcan legacy) y verifica con Grep si tienen uso en codigo (L10n.*, ls(", NSLocalizedString). Reporta solo las confirmadas sin uso.\n' +
      'Severities: paridad rota=ALTA (UX rota en ese locale), vacio=ALTA, placeholder inconsistente=ALTA (crash potencial de format), huerfana=BAJA.\n' +
      'file=path del .strings, line=0 si no aplica, dimension "l10n". En rule indica la key y el locale afectado.',
  },
  {
    key: 'privacy',
    verify: true,
    prompt:
      'Eres auditor de privacy y Apple compliance de Yala (app de finanzas — sensibilidad alta).\n' +
      'AUDITA:\n' +
      '1. API KEYS / SECRETS hardcodeados: grep por patrones (sk-, AIza, ghp_, xox, Bearer , api_key =, apiKey = ") en Yala/ — la regla del proyecto es Secrets.xcconfig + Info.plist. BLOQUEANTE si hay una clave real.\n' +
      '2. PrivacyInfo.xcprivacy (Yala/Resources/): lee el archivo y verifica que declara Required Reason APIs por las APIs realmente usadas — UserDefaults (CA92.1), file timestamp, systemUptime, diskSpace. Cruza con greps rapidos en codigo. ALTA si falta una categoria usada.\n' +
      '3. Info.plist usage descriptions: la app usa microfono (entrada por voz), camara/fotos (entrada por imagen), notificaciones, Face ID (lock). Verifica NSMicrophoneUsageDescription, NSCameraUsageDescription, NSPhotoLibraryUsageDescription, NSFaceIDUsageDescription presentes y con texto util (no placeholder). ALTA si falta una usada.\n' +
      '4. Paywall legal (App Store 3.1): en SubscriptionView/ProTrialOfferSheet verifica que hay links a Privacy Policy Y Terms, precio visible y mencion de auto-renovacion, y boton de Restaurar compras. ALTA si falta.\n' +
      '5. Logs con datos sensibles fuera de #if DEBUG (montos, nombres, emails): grep print( y Logger en Services/ y verifica el contexto DEBUG. BLOQUEANTE si confirmas uno en produccion.\n' +
      'file, line real (0 para hallazgos de plist/manifest sin linea util), dimension "privacy", severity, rule, snippet, fix.',
  },
  {
    key: 'dead-code',
    verify: true,
    prompt:
      'Eres auditor de codigo muerto en Yala. Busca simbolos sin referencias REALES. Estrategia: \n' +
      '1. Candidatos: funcs/structs/classes/enums internos con nombres que sugieren legacy (legacy, old, deprecated, unused, V1/V2 superseded), helpers en Utils/ y extensiones grandes. Usa Grep para listar declaraciones y luego busca referencias en TODO el repo (incluye YalaTests/ y YalaUITests/).\n' +
      '2. Un simbolo es candidato SOLO si: 0 referencias fuera de su declaracion, no es @main/@Model/App Intent/Widget/entry point, no se invoca via string (selector, NotificationCenter name, UserDefaults key), no es conformance de protocolo requerida, y no es API publica de un componente DS reusable.\n' +
      '3. ATENCION falsos positivos tipicos: AppIntents (los instancia el sistema), structs de #Preview, inits de Codable, computed usados via KeyPath, vistas referenciadas solo desde navegacion por tipo.\n' +
      'Reporta maximo los 25 candidatos MAS seguros. dimension "dead-code", severity BAJA (MEDIA si es un archivo entero muerto), line=linea de la declaracion, fix="eliminar" o "confirmar y eliminar".',
  },
  {
    key: 'qa-coverage',
    verify: false,
    prompt:
      'Eres auditor del contrato QA anti-drift de Yala. La SSOT es qa/coverage-index.json.\n' +
      'EJECUTA Y REPORTA:\n' +
      '1. bash qa/validate-coverage.sh — captura exit code y output. Si falla el ratchet o validacion → BLOQUEANTE (el contrato del repo lo exige verde).\n' +
      '2. Lee qa/coverage-index.json: para cada area, extrae classification, coverage y lastVerified. Lista areas "deterministic" SIN coverage xcuitest (backlog determinista) y compara con _meta.backlogBaseline.\n' +
      '3. DRIFT: identifica las 10 areas con lastVerified mas antiguo y cruza con git log -- <paths del area> (si el area declara paths) para ver si hubo commits posteriores a lastVerified. Area tocada despues de su lastVerified = stale → MEDIA cada una, ALTA si es area critica (sync, grupos, calculos financieros, migraciones).\n' +
      '4. Resume el estado en findings: file="qa/coverage-index.json", line=0, dimension "qa-coverage", rule indica el area y el problema.',
  },
  {
    key: 'release-hygiene',
    verify: false,
    prompt:
      'Eres auditor de higiene de release de Yala 2.0. AUDITA:\n' +
      '1. VERSION: grep MARKETING_VERSION y CURRENT_PROJECT_VERSION en Yala.xcodeproj/project.pbxproj — TODAS las occurrences deben ser identicas entre si (targets sincronizados). ALTA si hay mezcla.\n' +
      '2. WHATS NEW: verifica que el What\'s New de la 2.0 existe y esta localizado (busca las keys whatsnew/whatsNew en los Localizable.strings de los locales de referencia es-419/en/pt-BR y de las 4 variantes es-ES/es-AR/en-GB/pt-PT). ALTA si falta en alguna variante (renderiza key cruda).\n' +
      '3. TODO/FIXME/HACK/WORKAROUND en Yala/ (excluye tests): cuenta total con grep -rn y lista los 15 mas criticos por contexto (los que digan crash, race, antes de release, temporal). MEDIA los criticos, BAJA el resto (solo count).\n' +
      '4. TESTS DESHABILITADOS: grep ".disabled(" en YalaTests/ y YalaUITests/ — cada uno debe tener entrada en la Lista Negra de TESTING-STRATEGY.md (si tienes acceso al vault no lo leas; reporta los .disabled encontrados para cruce manual). MEDIA cada uno.\n' +
      '5. PENDIENTES DE QA ACUMULADOS: grep "Pendiente" CLAUDE.md — consolida la lista de device-QA pendientes documentados en Decisiones Recientes (ej: Apple Pay pantalla bloqueada, PIN-01..10 CKShare, SUB-DEDUP-01..12, MIG-V2-FLASH-01..12, escenarios de grupos). Cada bloque pendiente = un finding MEDIA con rule="device QA pendiente: <tema>" — esto alimenta la seccion de gaps del reporte.\n' +
      '6. DEBUG RESIDUAL: grep por flags DEV_BUILD/toggles de debug expuestos fuera de #if DEBUG en UI de produccion. ALTA si un toggle DEBUG es alcanzable en release.\n' +
      'file/line donde aplique (0 si es global), dimension "release-hygiene".',
  },
]

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------
const INVENTORY_SCHEMA = {
  type: 'object',
  properties: { files: { type: 'array', items: { type: 'string' }, description: 'paths relativos de TODOS los .swift bajo Yala/, ordenados' } },
  required: ['files'],
}

const FINDING_PROPS = {
  file: { type: 'string', description: 'path relativo desde la raiz del repo' },
  line: { type: 'integer', description: 'linea real (0 si no aplica)' },
  dimension: { type: 'string' },
  severity: { type: 'string', enum: ['bloqueante', 'alta', 'media', 'baja'] },
  rule: { type: 'string', description: 'regla violada, corta' },
  snippet: { type: 'string', description: 'linea/evidencia recortada a ~120 chars' },
  fix: { type: 'string', description: 'arreglo concreto, 1 frase' },
}
const FINDING_ITEM = { type: 'object', properties: FINDING_PROPS, required: ['file', 'dimension', 'severity', 'rule', 'fix'] }
const SCAN_SCHEMA = { type: 'object', properties: { findings: { type: 'array', items: FINDING_ITEM } }, required: ['findings'] }
const VERIFY_SCHEMA = { type: 'object', properties: { confirmed: { type: 'array', items: FINDING_ITEM } }, required: ['confirmed'] }

const FUNDAMENTALS_SCHEMA = {
  type: 'object',
  properties: {
    buildOK: { type: 'boolean' },
    buildErrors: { type: 'array', items: { type: 'string' } },
    warningsCount: { type: 'integer' },
    warningsSample: { type: 'array', items: { type: 'string' }, description: 'hasta 10 warnings representativos' },
    testsRan: { type: 'boolean' },
    testsPassed: { type: 'integer' },
    testsFailed: { type: 'integer' },
    failedTests: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
  required: ['buildOK', 'testsRan'],
}

const SUMMARY_SCHEMA = {
  type: 'object',
  properties: {
    reportPath: { type: 'string' },
    verdict: { type: 'string', enum: ['LISTO', 'BLOQUEADO'] },
    blockers: { type: 'integer' },
    total: { type: 'integer' },
    highlights: { type: 'array', items: { type: 'string' }, description: '6-10 frases con los gaps mas importantes' },
  },
  required: ['reportPath', 'verdict', 'blockers', 'total'],
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function tally(arr, key) {
  const m = {}
  for (const x of arr) { const k = x[key] || '?'; m[k] = (m[k] || 0) + 1 }
  return Object.entries(m).sort((a, b) => b[1] - a[1]).map(([k, v]) => ({ key: k, count: v }))
}

const verifyPrompt = (candidates) =>
  'Eres un verificador ADVERSARIAL de auditoria de codigo. Te doy findings candidatos; tu trabajo es REFUTAR los falsos positivos abriendo el codigo real con Read/Grep.\n\n' +
  'Para cada candidato: abre el archivo en la linea indicada y lee contexto suficiente (funcion completa, bloque #if DEBUG envolvente, guards previos). Descarta el finding si: esta dentro de #if DEBUG o #Preview; hay guard/validacion previa que lo hace seguro; hay comentario o marker (A11Y-DT/A11Y-DM) que documenta la decision; es codigo de test; o la "violacion" es en realidad el patron canonico del proyecto. Para dead-code: busca referencias en TODO el repo incluyendo strings, selectors, tests y navegacion por tipo antes de confirmar.\n' +
  'Se esceptico: ante la duda, DESCARTA. Puedes ajustar severity si el candidato la exagero (o subirla si confirmas que es peor, ej. crash real alcanzable → bloqueante).\n\n' +
  'CONTEXTO DE REGLAS DEL PROYECTO:\n' + RULEBOOK + '\n\n' +
  'FINDINGS CANDIDATOS (JSON):\n' + JSON.stringify(candidates) + '\n\n' +
  'Devuelve { confirmed: [...] } SOLO con violaciones reales, campos finales completos (file, line, dimension, severity, rule, snippet, fix).'

// ---------------------------------------------------------------------------
// Fase 1 — Fundamentos (build + tests) — arranca YA, se awaitea al final
// ---------------------------------------------------------------------------
phase('Fundamentos')
let fundamentalsP = null
if (!SKIP_BUILD || !SKIP_TESTS) {
  fundamentalsP = agent(
    'Eres el agente de build y tests de Yala. Trabaja secuencialmente (xcodebuild no tolera invocaciones concurrentes sobre el mismo proyecto). USA timeout: 600000 en CADA llamada Bash.\n\n' +
    (SKIP_BUILD ? '' :
      'PASO 1 — BUILD LIMPIO:\n' +
      'xcodebuild clean build -scheme Yala -destination "platform=iOS Simulator,name=iPhone 17 Pro" 2>&1 | grep -E "(error:|warning:|BUILD)" | head -60\n' +
      'Captura: buildOK (BUILD SUCCEEDED), buildErrors (lineas error:), warningsCount (cuenta con grep -c "warning:" sobre el log completo si hace falta re-ejecutar SOLO el grep del log; si no, cuenta las visibles) y warningsSample (hasta 10, deduplicados por tipo).\n\n') +
    (SKIP_TESTS ? 'NO ejecutes tests (testsRan=false).\n' :
      'PASO 2 — TESTS (solo si el build paso; si fallo, testsRan=false):\n' +
      'xcodebuild test -scheme Yala -destination "platform=iOS Simulator,name=iPhone 17 Pro" -parallel-testing-enabled YES 2>&1 | tail -200\n' +
      'Del output extrae: testsPassed, testsFailed y failedTests (nombres exactos suite/test de los fallidos, con 1 linea de motivo si es visible). Si el comando supera el timeout, reintenta una vez con -only-testing:YalaTests. Flakes conocidos: si un test falla, anotalo igual — la sintesis decide.\n') +
    '\nDevuelve el objeto estructurado. En notes resume en 2 frases el estado general.',
    { label: 'build+tests', phase: 'Fundamentos', schema: FUNDAMENTALS_SCHEMA }
  )
} else {
  log('Fundamentos saltados por args (skipBuild + skipTests)')
}

// ---------------------------------------------------------------------------
// Fase 2 — Inventario
// ---------------------------------------------------------------------------
phase('Inventario')
let sweepResults = []
if (!SKIP_SWEEP) {
  const inventory = await agent(
    'Ejecuta exactamente: find ' + CODE_ROOT + ' -name "*.swift" -type f | sort\n' +
    'Devuelve { files: [...] } con TODOS los paths tal cual (relativos al repo, ordenados). No filtres nada.',
    { label: 'inventario', phase: 'Inventario', model: 'haiku', schema: INVENTORY_SCHEMA }
  )
  const files = (inventory && inventory.files) || []
  const chunks = []
  for (let i = 0; i < files.length; i += CHUNK) chunks.push({ idx: chunks.length + 1, files: files.slice(i, i + CHUNK) })
  log('Inventario: ' + files.length + ' archivos → ' + chunks.length + ' chunks de ≤' + CHUNK)

  if (!chunks.length) return { error: 'Inventario vacio — revisa CODE_ROOT', inventory }

  // -------------------------------------------------------------------------
  // Fase 3+5 — Barrido (fan-out) → Verificar (adversarial), pipeline sin barrera
  // -------------------------------------------------------------------------
  sweepResults = (await pipeline(
    chunks,
    (c) => agent(
      'Eres auditor de calidad de codigo de Yala (pre-release 2.0). Audita EXACTAMENTE estos archivos (Read cada uno; Grep para localizar patrones rapido y luego confirma contexto y linea REAL):\n' +
      c.files.map(f => '- ' + f).join('\n') + '\n\n' +
      'REGLAS:\n' + RULEBOOK + '\n\n' +
      'Reporta cada violacion: file, line real, dimension (errores|logs|state|swiftdata-uso|concurrencia|performance|fechas|l10n-hardcoded|gotchas), severity, rule corta, snippet ≤120 chars, fix 1 frase.\n' +
      'Se CONSERVADOR: respeta TODAS las excepciones; ante la duda severity baja o no reportes. NO reportes archivos fuera de tu lista. Devuelve { findings: [] } si esta limpio.',
      { label: 'scan:' + c.idx + ' (' + c.files[0].split('/').slice(-2).join('/') + '…)', phase: 'Barrido', model: 'sonnet', schema: SCAN_SCHEMA }
    ),
    (scan, c) => {
      const findings = (scan && scan.findings) || []
      const toVerify = findings.filter(f => f.severity === 'bloqueante' || f.severity === 'alta' || f.severity === 'media')
      const lows = findings.filter(f => f.severity === 'baja')
      if (!toVerify.length) return { findings: lows }
      return agent(verifyPrompt(toVerify), { label: 'verify:' + c.idx, phase: 'Verificar', model: 'sonnet', schema: VERIFY_SCHEMA })
        .then(v => ({ findings: [...((v && v.confirmed) || []), ...lows] }))
    }
  )).filter(Boolean)
} else {
  log('Barrido por archivos saltado por args (skipSweep)')
}

// ---------------------------------------------------------------------------
// Fase 4(+5) — Especialistas → verificacion adversarial donde aplica
// ---------------------------------------------------------------------------
const specialistTasks = SPECIALISTS.filter(s => !ONLY_SPECIALISTS || ONLY_SPECIALISTS.includes(s.key))
const specialistResults = (await pipeline(
  specialistTasks,
  (s) => agent(
    s.prompt + '\n\nDevuelve { findings: [...] } con el schema indicado (vacio si todo esta correcto). Usa dimension "' + s.key + '" en todos.',
    { label: 'spec:' + s.key, phase: 'Especialistas', schema: SCAN_SCHEMA }
  ),
  (scan, s) => {
    const findings = (scan && scan.findings) || []
    if (!s.verify || !findings.length) return { findings }
    const toVerify = findings.filter(f => f.severity === 'bloqueante' || f.severity === 'alta')
    const rest = findings.filter(f => f.severity !== 'bloqueante' && f.severity !== 'alta')
    if (!toVerify.length) return { findings }
    return agent(verifyPrompt(toVerify), { label: 'verify:' + s.key, phase: 'Verificar', model: 'sonnet', schema: VERIFY_SCHEMA })
      .then(v => ({ findings: [...((v && v.confirmed) || []), ...rest] }))
  }
)).filter(Boolean)

// ---------------------------------------------------------------------------
// Consolidar
// ---------------------------------------------------------------------------
const all = [...sweepResults, ...specialistResults].flatMap(r => r.findings || [])
const fundamentals = fundamentalsP ? await fundamentalsP : { buildOK: true, testsRan: false, notes: 'saltado por args' }

const bySeverity = tally(all, 'severity')
const byDimension = tally(all, 'dimension')
log('Hallazgos confirmados: ' + all.length + ' | build OK: ' + (fundamentals && fundamentals.buildOK) + ' | tests fallidos: ' + ((fundamentals && fundamentals.testsFailed) || 0))

// ---------------------------------------------------------------------------
// Fase 6 — Sintetizar reporte
// ---------------------------------------------------------------------------
phase('Sintetizar')
const summary = await agent(
  'Eres el redactor del informe de release-readiness de Yala 2.0. Te doy los fundamentos (build+tests) y TODOS los hallazgos confirmados de la auditoria. Escribe un informe Markdown accionable EN ESPAÑOL con la herramienta Write en: ' + REPORT_PATH + '\n' +
  (DATE ? 'Fecha del informe: ' + DATE + '\n' : 'Obten la fecha con: date +%Y-%m-%d\n') +
  'Obten la version con: grep -m1 MARKETING_VERSION Yala.xcodeproj/project.pbxproj y grep -m1 CURRENT_PROJECT_VERSION.\n\n' +
  'CRITERIO DE VEREDICTO: BLOQUEADO si build falla, si hay tests fallidos no justificados, o si existe cualquier finding severity "bloqueante". Si no, LISTO (con gaps listados).\n\n' +
  'ESTRUCTURA OBLIGATORIA:\n' +
  '1. "# Release readiness — Yala <version> (build <n>)" + fecha + veredicto destacado en la primera linea del cuerpo: "## Veredicto: LISTO PARA RELEASE" o "## Veredicto: BLOQUEADO por N items".\n' +
  '2. "## Dashboard": tabla | Area | Estado | Bloqueantes | Altos | Medios | Bajos | — una fila por area: Build, Tests, y cada dimension presente en los findings. Estado ✓/✗/⚠.\n' +
  '3. "## Bloqueantes" — lista COMPLETA, cada uno con file:line, regla y fix.\n' +
  '4. "## Criticos (alta)" — lista completa con file:line, agrupada por dimension.\n' +
  '5. "## Medios" — tabla compacta agrupada por dimension (file:line | regla | fix), completa pero sin prosa.\n' +
  '6. "## Bajos" — solo counts por dimension + los 10 mas utiles.\n' +
  '7. "## Pendientes de QA pre-release" — consolida los findings de dimension "release-hygiene" con rule "device QA pendiente" y los de "qa-coverage": una checklist de los device-QA y escenarios que el owner deberia pasar antes de publicar.\n' +
  '8. "## Quick wins" — 5-10 arreglos de maximo impacto / minimo riesgo.\n' +
  '9. "## Fuera de alcance" — nota que DS/UI-tokens y a11y visual se auditan con /ui-audit (ver AUDIT-UI-patterns.md, epico cerrado) y que este informe cubre el resto.\n' +
  'Datos en tablas, prosa minima. Rutas relativas tal cual (clicables). NO omitas hallazgos bloqueantes/altos.\n\n' +
  'FUNDAMENTOS (JSON):\n' + JSON.stringify(fundamentals) + '\n\n' +
  'HALLAZGOS (JSON):\n' + JSON.stringify(all) + '\n\n' +
  'Tras escribir el archivo devuelve { reportPath, verdict (LISTO|BLOQUEADO), blockers, total, highlights: [6-10 frases con los gaps mas importantes] }.',
  { label: 'reporte', phase: 'Sintetizar', schema: SUMMARY_SCHEMA }
)

return {
  reportPath: REPORT_PATH,
  verdict: (summary && summary.verdict) || 'desconocido',
  blockers: (summary && summary.blockers) || 0,
  total: all.length,
  buildOK: fundamentals && fundamentals.buildOK,
  testsFailed: (fundamentals && fundamentals.testsFailed) || 0,
  bySeverity,
  byDimension,
  highlights: (summary && summary.highlights) || [],
}
