/**
 * canon.ts — el RE-SERIALIZADOR canónico c1 del Worker (I8f-3, §d.7 Canal 1). Es el 4º codec
 * (Swift cliente-autor · TS web · Kotlin Android · ESTE): re-serializa lo que PostgREST entrega a los
 * MISMOS bytes que produce `Canonc1Codec` (Swift) para el mismo valor lógico — la base del leaf del
 * Merkle. Un byte de divergencia = divergencia FALSA PERMANENTE del canario (el fallo de diseño que C2
 * mató), por eso cada regla espeja el codec Swift y el gate es `golden_vectors.json` ENTERO
 * (canon.golden.test.ts, offline, CI).
 *
 * Reglas c1 (espejo de Canonc1Codec.swift — ver ahí el detalle normativo):
 *  - Objeto JSON de UN nivel; keys ordenadas por BYTES UTF-8 asc; sin espacios; UTF-8 crudo.
 *  - NUMERIC: decimal string escala-FIJA (dinero=4, tasa=8) HALF_EVEN. Dos rutas: desde el TEXTO de
 *    `::text` (aritmética string/BigInt — JAMÁS float: el padding de PostgREST no es de fiar y un
 *    float re-redondearía) y desde un double binario (exacto-desde-binario, para el golden y los
 *    valores que PostgREST entregara como número JSON). `-0` → "0.0000"; NaN/±Inf → throw;
 *    |dinero|≥10¹⁴ / |tasa|≥10¹⁰ → throw.
 *  - timestamptz: el texto de PostgREST puede traer offset (`+00:00`) y microsegundos → normalizar a
 *    ms-FLOOR UTC y formatear el T-CANON de 24 chars (`YYYY-MM-DDTHH:mm:ss.SSSZ`, 'Z' literal) —
 *    misma tolerancia que `WireValueDecoder.millisFromISO` (A-5).
 *  - uuid: 36 chars lowercase. uuid[]: sort por bytes UTF-8 + dedup + lowercase; VACÍA singleton →
 *    OMITIR key; vacía EN GRUPO → `[]` explícito; **NULL ≡ `'{}'` para uuid[] agrupada → `[]`**
 *    (DIFERIDOS #25 — ver la nota del re-serializador en manifest.ts). La membresía de grupo se deriva
 *    de `group_key` del manifest (mismo SSOT que el cliente).
 *  - text: escape mínimo RFC-8785 (C0 cortos, `\u00xx` lowercase, `/` sin escapar, ≥0x80 crudo).
 *  - boolean tri-estado: true/false/null literal. integer: número JSON plano. NULL en-set → `key:null`.
 *  - jsonb (blobs): re-canonicalización recursiva; los números de `rates` ya viajaron como STRINGS
 *    canónicos escala-8 → se PRESERVAN (strings pasan tal cual); un número JSON crudo (no debería
 *    ocurrir desde nuestro cliente) se canonicaliza con la regla de tasa (escala 8) como el codec Swift.
 *  - Columnas server-authored JAMÁS son keys (throw).
 *  - **`local_day` EXCLUIDA del leaf del Canal 1 en AMBOS lados (A-2b)**: el cliente NO la almacena
 *    (derivada de `date`; el apply la ignora) → re-derivarla con el calendario ACTUAL diverge de la
 *    ALMACENADA ante cualquier cambio de huso = divergencia falsa garantizada. Sigue siendo columna
 *    in-set del PULL y del dedup S9; solo sale de la AUDITORÍA Merkle.
 */
import { manifest, groupsOfEntity, type CapabilitySet } from "./manifest";

// ------------------------------------------------------------------------------------------ errores

/** Error tipado del codec (espejo de `Canonc1Error` + `CanonicalTimeError`). `code` es el contrato. */
export class CanonError extends Error {
  constructor(
    public readonly code:
      | "nonFiniteNumber"
      | "numericOutOfRange"
      | "serverAuthoredKey"
      | "malformedBlobJSON"
      | "yearOutOfRange"
      | "malformedNumericText"
      | "malformedTimestampText",
    detail: string,
  ) {
    super(`${code}: ${detail}`);
  }
}

// -------------------------------------------------------------------------------------- CanonValue

/** Valor tipado de una columna (espejo de `CanonValue` Swift). Entrada del encoder. */
export type CanonValue =
  | { t: "money"; double?: number; text?: string }
  | { t: "rate"; double?: number; text?: string }
  | { t: "timestampMs"; ms: number }
  | { t: "localDay"; ms: number }
  | { t: "uuid"; value: string }
  | { t: "uuidArray"; values: string[] }
  | { t: "string"; value: string }
  | { t: "bool"; value: boolean | null }
  | { t: "int"; value: number }
  | { t: "jsonValue"; value: unknown }
  | { t: "null" };

/** Columnas server-authored que NUNCA son leaves del Canal 1 (espejo de Canonc1Codec). */
const SERVER_AUTHORED_KEYS = new Set([
  "updated_at",
  "server_seq",
  "hlc",
  "deleted_hlc",
  "schema_version",
  "user_id",
]);

// ------------------------------------------------------------------------------- orden UTF-8 bytes

const utf8 = new TextEncoder();

/** Comparación por BYTES UTF-8 ascendentes (no code units UTF-16, no collation). */
export function utf8Compare(a: string, b: string): number {
  const x = utf8.encode(a);
  const y = utf8.encode(b);
  const n = Math.min(x.length, y.length);
  for (let i = 0; i < n; i++) {
    if (x[i] !== y[i]) return x[i] < y[i] ? -1 : 1;
  }
  return x.length - y.length;
}

// ------------------------------------------------------------------------- strings: escape RFC-8785

/** Literal JSON con escape MÍNIMO RFC-8785 (espejo de `Canonc1Codec.encodeJSONString`). */
export function encodeJSONStringC1(s: string): string {
  let out = '"';
  for (const ch of s) {
    const cp = ch.codePointAt(0)!;
    switch (cp) {
      case 0x22: out += '\\"'; break;
      case 0x5c: out += "\\\\"; break;
      case 0x08: out += "\\b"; break;
      case 0x09: out += "\\t"; break;
      case 0x0a: out += "\\n"; break;
      case 0x0c: out += "\\f"; break;
      case 0x0d: out += "\\r"; break;
      default:
        if (cp < 0x20) {
          out += "\\u" + cp.toString(16).padStart(4, "0"); // lowercase hex
        } else {
          out += ch; // ASCII imprimible o UTF-8 crudo (incl. no-ASCII)
        }
    }
  }
  return out + '"';
}

// --------------------------------------------------------- números: HALF_EVEN escala-fija (2 rutas)

const MONEY_SCALE = 4;
const RATE_SCALE = 8;

function limitFor(scale: number): bigint {
  // dinero |v|<10¹⁴, tasa |v|<10¹⁰ (congelado; espejo del codec Swift).
  return scale === MONEY_SCALE ? 10n ** 14n : 10n ** 10n;
}

/**
 * Ruta DOUBLE (exacto-desde-binario): descompone el binary64 en (M, E) con valor = M·2^E EXACTO y
 * redondea M·10^S / 2^-E con aritmética BigInt (espejo bit a bit de `Canonc1Codec.decimalFixed`).
 */
export function decimalFixedFromDouble(x: number, scale: number): string {
  if (!Number.isFinite(x)) throw new CanonError("nonFiniteNumber", String(x));
  const limit = scale === MONEY_SCALE ? 1e14 : 1e10;
  if (Math.abs(x) >= limit) throw new CanonError("numericOutOfRange", String(x));

  const negative = x < 0 || Object.is(x, -0);
  const magnitude = Math.abs(x);

  const view = new DataView(new ArrayBuffer(8));
  view.setFloat64(0, magnitude);
  const bits = view.getBigUint64(0);
  const exponentBits = Number((bits >> 52n) & 0x7ffn);
  const fractionBits = bits & 0x000f_ffff_ffff_ffffn;
  let mantissa: bigint;
  let exponent: number;
  if (exponentBits === 0) {
    mantissa = fractionBits; // subnormal o cero
    exponent = -1074;
  } else {
    mantissa = fractionBits | (1n << 52n);
    exponent = exponentBits - 1075;
  }

  const pow10 = scale === MONEY_SCALE ? 10_000n : 100_000_000n;
  const scaled = mantissa * pow10;

  let q: bigint;
  if (exponent >= 0) {
    q = scaled << BigInt(exponent); // defensivo: inalcanzable en rango
  } else {
    const k = BigInt(-exponent);
    let quotient = scaled >> k;
    const halfBit = k >= 1n && ((scaled >> (k - 1n)) & 1n) === 1n;
    const anyBelow = k >= 1n && (scaled & ((1n << (k - 1n)) - 1n)) !== 0n;
    if (halfBit) {
      if (anyBelow) quotient += 1n; // resto > mitad → arriba
      else if (quotient % 2n === 1n) quotient += 1n; // mitad exacta → al PAR
    }
    q = quotient;
  }
  return formatFixed(q, negative, pow10, scale);
}

/**
 * Ruta TEXTO (`NUMERIC::text` de Postgres): re-cuantiza el decimal EXACTO del texto a escala fija con
 * HALF_EVEN — aritmética BigInt pura, JAMÁS float (el padding de PostgREST no es contrato y un float
 * re-redondearía dos veces). Acepta `[+-]?d+[.d+]?` (NUMERIC::text nunca usa exponente).
 */
export function decimalFixedFromString(text: string, scale: number): string {
  const m = /^([+-]?)(\d+)(?:\.(\d+))?$/.exec(text.trim());
  if (!m) throw new CanonError("malformedNumericText", text);
  const negative = m[1] === "-";
  const intPart = m[2];
  const fracPart = m[3] ?? "";

  const digits = BigInt(intPart + fracPart); // valor = digits / 10^f
  const f = fracPart.length;

  // Rango: |v| < limit ⇔ digits < limit·10^f (espejo del guard del codec Swift, ANTES de redondear).
  if (digits >= limitFor(scale) * 10n ** BigInt(f)) {
    throw new CanonError("numericOutOfRange", text);
  }

  const pow10 = scale === MONEY_SCALE ? 10_000n : 100_000_000n;
  let q: bigint;
  if (f <= scale) {
    q = digits * 10n ** BigInt(scale - f);
  } else {
    const div = 10n ** BigInt(f - scale);
    let quotient = digits / div;
    const rem = digits % div;
    const half = div / 2n; // div es potencia de 10 → half exacto
    if (rem > half) quotient += 1n;
    else if (rem === half && quotient % 2n === 1n) quotient += 1n; // mitad exacta → al PAR
    q = quotient;
  }
  return formatFixed(q, negative, pow10, scale);
}

function formatFixed(q: bigint, negative: boolean, pow10: bigint, scale: number): string {
  const integerPart = q / pow10;
  const fractionPart = q % pow10;
  const fraction = fractionPart.toString().padStart(scale, "0");
  const sign = negative && q !== 0n ? "-" : ""; // -0.0 → sin signo
  return `${sign}${integerPart.toString()}.${fraction}`;
}

// ------------------------------------------------------- tiempo: civil Hinnant + parse de PostgREST

function floorDiv(a: number, b: number): number {
  return Math.floor(a / b);
}
function floorMod(a: number, b: number): number {
  return a - Math.floor(a / b) * b;
}

/** Días desde 1970-01-01 (Hinnant days_from_civil — espejo de `CanonicalTime.daysFromCivil`). */
export function daysFromCivil(year: number, month: number, day: number): number {
  const y = year - (month <= 2 ? 1 : 0);
  const era = Math.floor((y >= 0 ? y : y - 399) / 400);
  const yoe = y - era * 400;
  const mp = month > 2 ? month - 3 : month + 9;
  const doy = Math.floor((153 * mp + 2) / 5) + day - 1;
  const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe - 719468;
}

/** Fecha civil desde días Unix (Hinnant civil_from_days — espejo de `CanonicalTime.civilFromDays`). */
function civilFromDays(days: number): { year: number; month: number; day: number } {
  const z = days + 719468;
  const era = Math.floor((z >= 0 ? z : z - 146096) / 146097);
  const doe = z - era * 146097;
  const yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
  const y = yoe + era * 400;
  const doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  const mp = Math.floor((5 * doy + 2) / 153);
  const day = doy - Math.floor((153 * mp + 2) / 5) + 1;
  const month = mp < 10 ? mp + 3 : mp - 9;
  return { year: y + (month <= 2 ? 1 : 0), month, day };
}

function pad(n: number, width: number): string {
  return String(n).padStart(width, "0");
}

/** T-CANON de 24 chars desde ms Unix (`YYYY-MM-DDTHH:mm:ss.SSSZ`). Año fuera de 0001..9999 → throw. */
export function canonicalIsoFromMillis(ms: number): string {
  const totalSeconds = floorDiv(ms, 1000);
  const millis = floorMod(ms, 1000);
  const days = floorDiv(totalSeconds, 86_400);
  const secondOfDay = floorMod(totalSeconds, 86_400);
  const { year, month, day } = civilFromDays(days);
  if (year < 1 || year > 9999) throw new CanonError("yearOutOfRange", String(year));
  const hour = Math.floor(secondOfDay / 3600);
  const minute = Math.floor((secondOfDay % 3600) / 60);
  const second = secondOfDay % 60;
  return `${pad(year, 4)}-${pad(month, 2)}-${pad(day, 2)}T${pad(hour, 2)}:${pad(minute, 2)}:${pad(second, 2)}.${pad(millis, 3)}Z`;
}

/**
 * ms Unix desde el TEXTO timestamptz de PostgREST. Tolerante (espejo de `WireValueDecoder.millisFromISO`):
 * `YYYY-MM-DD[T| ]HH:mm:ss[.f+][Z|±HH[:MM]|±HHMM]`; sub-ms se TRUNCAN (FLOOR); sin zona → UTC.
 */
export function millisFromPostgresText(text: string): number {
  const m = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?(Z|z|[+-]\d{2}(?::?\d{2})?)?$/.exec(text.trim());
  if (!m) throw new CanonError("malformedTimestampText", text);
  const [, ys, mos, ds, hs, mins, ss, frac, zone] = m;
  const year = Number(ys), month = Number(mos), day = Number(ds);
  const hour = Number(hs), minute = Number(mins), second = Number(ss);
  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    throw new CanonError("malformedTimestampText", text);
  }
  let millis = 0;
  if (frac !== undefined) {
    millis = Number((frac + "000").slice(0, 3)); // FLOOR sub-ms: 3 primeros dígitos, pad con ceros
  }
  let offsetMinutes = 0;
  if (zone && zone !== "Z" && zone !== "z") {
    const zm = /^([+-])(\d{2}):?(\d{2})?$/.exec(zone)!;
    const sign = zm[1] === "-" ? -1 : 1;
    offsetMinutes = sign * (Number(zm[2]) * 60 + Number(zm[3] ?? "0"));
  }
  const days = daysFromCivil(year, month, day);
  return (days * 86_400 + hour * 3600 + minute * 60 + second) * 1000 + millis - offsetMinutes * 60_000;
}

// ------------------------------------------------------------------------------- blobs (recursivo)

function canonicalizeBlobValue(value: unknown): string {
  if (value === null) return "null";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") {
    // Un número JSON crudo dentro de un blob se canonicaliza con la regla de TASA (escala 8) como
    // STRING — espejo del codec Swift. Los números de `rates` ya viajaron como STRINGS canónicos
    // desde el cliente → entran por la rama string y se PRESERVAN; esta rama es para blobs ajenos.
    return encodeJSONStringC1(decimalFixedFromDouble(value, RATE_SCALE));
  }
  if (typeof value === "string") return encodeJSONStringC1(value);
  if (Array.isArray(value)) {
    // Arrays: ORDEN preservado (dato ordenado; el sort/dedup es SOLO de uuid[] de columnas).
    return "[" + value.map(canonicalizeBlobValue).join(",") + "]";
  }
  if (typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const keys = Object.keys(obj).sort(utf8Compare);
    return "{" + keys.map((k) => `${encodeJSONStringC1(k)}:${canonicalizeBlobValue(obj[k])}`).join(",") + "}";
  }
  throw new CanonError("malformedBlobJSON", `tipo no soportado: ${typeof value}`);
}

// --------------------------------------------------------------------------------- encoder por valor

/** Fragmento JSON canónico de un `CanonValue`, o `null` si la key debe OMITIRSE (uuid[] vacía singleton). */
export function encodeCanonValue(value: CanonValue, inCoherenceGroup: boolean): string | null {
  switch (value.t) {
    case "money":
    case "rate": {
      const scale = value.t === "money" ? MONEY_SCALE : RATE_SCALE;
      const s = value.text !== undefined
        ? decimalFixedFromString(value.text, scale)
        : decimalFixedFromDouble(value.double!, scale);
      return encodeJSONStringC1(s);
    }
    case "timestampMs":
      return encodeJSONStringC1(canonicalIsoFromMillis(value.ms));
    case "localDay":
      return encodeJSONStringC1(canonicalIsoFromMillis(value.ms).slice(0, 10));
    case "uuid":
      return encodeJSONStringC1(value.value.toLowerCase());
    case "uuidArray": {
      if (value.values.length === 0) return inCoherenceGroup ? "[]" : null;
      const sorted = value.values.map((v) => v.toLowerCase()).sort(utf8Compare);
      const deduped: string[] = [];
      for (const s of sorted) if (deduped[deduped.length - 1] !== s) deduped.push(s);
      return "[" + deduped.map(encodeJSONStringC1).join(",") + "]";
    }
    case "string":
      return encodeJSONStringC1(value.value);
    case "bool":
      return value.value === null ? "null" : value.value ? "true" : "false";
    case "int":
      return String(value.value);
    case "jsonValue":
      return canonicalizeBlobValue(value.value);
    case "null":
      return "null";
  }
}

/** Serializa un mapa columna→CanonValue al string canónico c1 (espejo de `Canonc1Codec.encode`). */
export function encodeCanonC1(fields: Record<string, CanonValue>, groupedColumns: Set<string> = new Set()): string {
  for (const key of Object.keys(fields)) {
    if (SERVER_AUTHORED_KEYS.has(key)) throw new CanonError("serverAuthoredKey", key);
  }
  const keys = Object.keys(fields).sort(utf8Compare);
  const entries: string[] = [];
  for (const key of keys) {
    const fragment = encodeCanonValue(fields[key], groupedColumns.has(key));
    if (fragment === null) continue; // uuid[] vacía singleton → key omitida
    entries.push(`${encodeJSONStringC1(key)}:${fragment}`);
  }
  return "{" + entries.join(",") + "}";
}

// ---------------------------------------------------- proyección fila PostgREST → payload canónico

/**
 * Columnas del capability-set a incluir para `entity` (grupo-entero-o-nada, misma poda que
 * `projectRowToDelta`) EXCLUYENDO `local_day` (A-2b) — el set del leaf del Canal 1.
 */
export function merkleColumns(entity: string, cap: CapabilitySet): string[] {
  const spec = manifest.entities[entity];
  if (!spec) return [];
  const known = cap.columns?.[entity]; // undefined = conoce todo
  const groups = groupsOfEntity(entity);
  const droppedGroups = new Set<string>();
  if (known) {
    for (const [g, cols] of Object.entries(groups)) {
      if (!cols.every((c) => known.has(c))) droppedGroups.add(g);
    }
  }
  const out: string[] = [];
  for (const [col, spc] of Object.entries(spec.columns)) {
    if (spc.format === "yyyy_mm_dd") continue; // A-2b: local_day fuera de la auditoría Merkle
    if (known && !known.has(col)) continue;
    if (spc.group_key && droppedGroups.has(spc.group_key)) continue;
    out.push(col);
  }
  return out;
}

/**
 * Re-serializa UNA fila (valores tal cual los entrega PostgREST — NUMERIC casteado a `::text` en el
 * select del Merkle, o número JSON si vinieran de un `select=*`) al payload canónico c1 del leaf.
 * `columns` = el set proyectado (`merkleColumns`); las `uuid[]` NULL≡'{}' se resuelven aquí.
 */
export function canonRowC1(entity: string, row: Record<string, unknown>, columns: string[]): string {
  const spec = manifest.entities[entity];
  const grouped = new Set<string>();
  const fields: Record<string, CanonValue> = {};
  for (const col of columns) {
    const spc = spec.columns[col];
    if (!spc) continue;
    if (spc.group_key) grouped.add(col);
    const raw = row[col];
    fields[col] = canonValueFor(spc.format, spc.scale, raw);
  }
  return encodeCanonC1(fields, grouped);
}

/** Mapea un valor crudo de PostgREST a su `CanonValue` según el `format` del manifest. */
function canonValueFor(format: string, scale: number | undefined, raw: unknown): CanonValue {
  if (raw === null || raw === undefined) {
    // NULL en-set → key:null… EXCEPTO uuid[] (NULL ≡ '{}' = "sin filtro"): vacía → la regla de grupo
    // del encoder decide ([] en grupo / omitir singleton). DIFERIDOS #25 en manifest.ts.
    if (format === "uuid_lower_array") return { t: "uuidArray", values: [] };
    return { t: "null" };
  }
  switch (format) {
    case "decimal_fixed": {
      const t = scale === RATE_SCALE ? "rate" : "money";
      if (typeof raw === "string") return { t, text: raw };
      return { t, double: raw as number };
    }
    case "iso8601_ms_utc":
      return { t: "timestampMs", ms: millisFromPostgresText(String(raw)) };
    case "yyyy_mm_dd":
      // Inalcanzable vía merkleColumns (A-2b); defensivo para un caller futuro.
      return { t: "string", value: String(raw) };
    case "uuid_lower":
      return { t: "uuid", value: String(raw) };
    case "uuid_lower_array":
      return { t: "uuidArray", values: (raw as string[]).map(String) };
    case "utf8":
      return { t: "string", value: String(raw) };
    case "bool_tristate":
      return { t: "bool", value: raw as boolean };
    case "int":
      return { t: "int", value: raw as number };
    case "text_array":
    case "jcs":
      return { t: "jsonValue", value: raw };
    default:
      // Formato desconocido (manifest futuro): tratar como blob determinista.
      return { t: "jsonValue", value: raw };
  }
}
