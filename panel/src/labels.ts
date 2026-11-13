/**
 * Nombres en lenguaje de persona para lo que llega como slug. Un slug sin nombre se pinta tal cual: es mejor un nombre
 * técnico que inventar qué significa.
 */

/**
 * Funciones del evento `use` (decisión 1). El slug lo manda la app (`MetricsUseFeature` en
 * `Yala/Services/Metrics/MetricsService.swift`): renombrarlo allí rompe la serie aquí. `test/labels.test.ts` exige que
 * cada slug de la app tenga su nombre aquí.
 */
export const FEATURE_LABELS: Record<string, string> = {
  registrarMovimiento: "Registrar un movimiento",
  transferencia: "Transferir entre cuentas",
  panel: "Ver el Panel",
  estadisticas: "Estadísticas",
  presupuestos: "Presupuestos",
  pagosProgramados: "Pagos programados",
  cuentas: "Cuentas",
  grupos: "Grupos",
  preguntaYalaIA: "Preguntar a Yala IA",
  leerFoto: "Leer una foto",
  notaDeVoz: "Nota de voz",
  siriAtajos: "Siri y Atajos",
  widget: "Abrir desde un widget",
  exportar: "Exportar",
  importar: "Importar",
};

/** Funciones que hablan de Pro: van a su sección y no a «Lo que más se usa». */
export const PRO_FEATURES: Record<string, string> = {
  proOfertaVista: "Vieron la oferta de Pro",
  "limiteGratis.cuentas": "Chocaron con el límite de cuentas",
  "limiteGratis.presupuestos": "Chocaron con el límite de presupuestos",
};

/**
 * Embudo del alta (opción C de Jürgen, 2026-11-06), en el orden en que se recorre. Los slugs `alta.*` son `use` de la
 * app; el panel los saca de «Lo que más se usa» y los pinta en Registro. Los caminos se cuentan aparte: cada persona
 * elige uno.
 */
export const SIGNUP_STEPS: [string, string][] = [
  ["alta.bienvenida", "Ve la bienvenida"],
  ["alta.paso.name", "Pone su nombre"],
  ["alta.paso.purpose", "Elige para qué la usa"],
  ["alta.paso.accountType", "Elige el tipo de cuenta"],
  ["alta.paso.currencyName", "Elige la moneda"],
  ["alta.paso.balance", "Pone su saldo"],
  ["alta.paso.categories", "Revisa las categorías"],
  ["alta.paso.confirmation", "Confirma"],
  ["alta.termina", "Termina el alta"],
];

export const SIGNUP_PATHS: Record<string, string> = {
  "alta.camino.privada": "Privada (sin cuenta)",
  "alta.camino.nube": "Cuenta en la nube",
  "alta.camino.restaurar": "Restaurar de iCloud",
  "alta.camino.entrar": "Entrar con su cuenta",
  "alta.camino.grupoCrear": "Crear un grupo",
  "alta.camino.grupoUnirse": "Unirse a un grupo",
};

/**
 * Después del alta (card 4b7h, 2026-11-13): el reinicio del camino privado y los primeros días. Son `use` de la app, pero
 * de UNA VEZ POR INSTALACIÓN, no uno al día; los `primeros.*` solo llegan de instalaciones que cerraron el alta con la
 * versión que los manda. No son funciones: el panel los saca de «Lo que más se usa». Qué mide cada uno:
 * `docs/telemetria/eventos-usuario-nuevo.md`.
 */
export const NEW_USER_EVENTS: Record<string, string> = {
  "alta.reabrir.pide": "Se le pide reabrir Yala",
  "alta.reabrir.vuelve": "Vuelve a abrir Yala",
  "primeros.registro": "Primer registro propio",
  "primeros.presupuesto": "Primer presupuesto",
  "primeros.pago": "Primer pago planificado",
  "primeros.cuenta2": "Segunda cuenta",
  "primeros.pasos.ve": "Ve Primeros pasos",
  "primeros.pasos.cuenta": "Primeros pasos: crea su cuenta",
  "primeros.pasos.registrar": "Primeros pasos: aprende a registrar",
  "primeros.pasos.presupuesto": "Primeros pasos: crea un presupuesto",
  "primeros.pasos.pagos": "Primeros pasos: anota sus pagos fijos",
  "primeros.pasos.grupo": "Primeros pasos: grupos",
  "primeros.pasos.dinero": "Primeros pasos: a dónde va su dinero",
  "primeros.pasos.inicio": "Primeros pasos: Yala en la pantalla de inicio",
  "primeros.pasos.completa": "Completa Primeros pasos",
};

export const TASK_LABELS: Record<string, string> = {
  "chat.answer": "Responder en el chat",
  "chat.explore": "Chat con tus datos en la nube",
  "chat.intent": "Entender la pregunta",
  "chat.rewrite": "Reescribir la pregunta",
  "chat.suggestions": "Sugerir preguntas",
  "insights.cards": "Tarjetas de análisis",
  "insights.cashflow": "Análisis del flujo de caja",
  "insights.deviation": "Gastos fuera de lo normal",
  "insights.hero": "Frase del resumen (versiones viejas)",
  "legacy.passthrough": "Versiones viejas",
  "photo.read": "Leer una foto",
  "receipt.photo": "Repartir un recibo (foto)",
  "receipt.voice": "Repartir un recibo (voz)",
  "text.parse": "Entender una frase",
  "trends.summary": "Resumen de tendencias",
  "voice.transcribe": "Transcribir una nota de voz",
  "mail.read": "Leer un correo del banco",
};

/** Los canarios que más suenan (medido el 2026-11-06). El resto sale con su slug. */
export const CANARY_LABELS: Record<string, string> = {
  cloudkitExportSucceeded: "Copia en iCloud guardada",
  cloudkitExportFailed: "Copia en iCloud que falló",
  cloudSyncIdentityGapObserved: "Cambio sin identificador al subir",
  routingReadinessBlocked: "Pantalla ocupada al abrir",
  routingIntentDeferred: "Aviso que esperó turno",
  budgetFiltersAppearEmpty: "Presupuesto sin filtros",
  groupsConsentPending: "Grupos esperan permiso",
  cloudConsentAccepted: "Aceptaron el aviso de la nube",
  cloudkitDuplicateDetected: "Duplicados en iCloud",
  appEntityShortcutIDsRegenerated: "Atajos regenerados",
  cloudMigrationStep: "Paso de la migración a la nube",
  tagCatalogRebuilt: "Etiquetas reconstruidas",
  attestRefreshAbandoned: "Verificación del teléfono colgada",
  attestKeyDiscardedAfterAssertFailure: "Llave del teléfono renovada",
  cloudSyncMerkleDivergence: "Copia personal que no cuadraba",
  groupMerkleDivergence: "Copia de grupos que no cuadraba",
  cloudSyncBlockedByExpiredSession: "Sesión caducada con cambios",
  cloudSyncMutationRejected: "Cambio rechazado por el servidor",
  fxRepairQueueStuck: "Tipos de cambio sin reparar",
  iCloudRestoreOutcome: "Restauración desde iCloud",
  groupFanoutDelivered: "Avisos de grupo entregados",
  groupApnsSendFailed: "Aviso de grupo que Apple no entregó",
};

export function label(map: Record<string, string>, slug: string): string {
  return map[slug] ?? slug;
}
