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
