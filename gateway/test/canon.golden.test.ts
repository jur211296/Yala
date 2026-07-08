/**
 * Golden vectors del canon c1 — OFFLINE, gate CI (I8f-3, cierra el hallazgo "el gate cross-lenguaje
 * era solo-Swift"). Corre el re-serializador `canon.ts` contra `golden_vectors.json` ENTERO (los 41
 * vectores + 7 de error, incl. `groupedColumns`), alimentando el ENCODER desde su forma tagged
 * (`t`/`double`/`values`…) — el mismo harness que `Canonc1GoldenVectorTests` (Swift). Si un vector
 * diverge un byte, este lado del Merkle lo ve.
 *
 * Además: casos DEDICADOS de la normalización PostgREST (la parte que los goldens tagged no ejercitan):
 * `NUMERIC::text` con padding raro re-cuantizado por la ruta string/BigInt, y timestamptz con
 * `+00:00`/microsegundos → T-CANON ms-FLOOR.
 */
import { describe, expect, it } from "vitest";
import goldenJson from "../../golden_vectors.json";
import {
  CanonError,
  canonicalIsoFromMillis,
  decimalFixedFromString,
  encodeCanonC1,
  millisFromPostgresText,
  type CanonValue,
} from "../src/sync/canon";

interface FieldVal {
  t: string;
  double?: string;
  unixMs?: number;
  unixSeconds?: number;
  value?: string;
  values?: string[];
  bool?: boolean;
  isNull?: boolean;
  int?: number;
  json?: string;
}
interface Vector {
  id: string;
  description: string;
  fields: Record<string, FieldVal>;
  groupedColumns?: string[];
  expected: string;
}
interface ErrorVector {
  id: string;
  description: string;
  fields: Record<string, FieldVal>;
  expectedError: string;
}
interface Golden {
  canon_version: string;
  vectors: Vector[];
  errorVectors: ErrorVector[];
}

const golden = goldenJson as unknown as Golden;

/** Tagged → CanonValue (espejo del harness Swift `canonValue(_:_:)`). */
function toCanonValue(f: FieldVal): CanonValue {
  switch (f.t) {
    case "money":
    case "rate": {
      const raw = f.double!;
      const x = raw === "nan" ? Number.NaN : raw === "inf" ? Number.POSITIVE_INFINITY
        : raw === "-inf" ? Number.NEGATIVE_INFINITY : Number(raw);
      return { t: f.t, double: x };
    }
    case "timestamp":
    case "localDay": {
      const ms = f.unixMs ?? Math.floor(f.unixSeconds! * 1000);
      return { t: f.t === "timestamp" ? "timestampMs" : "localDay", ms };
    }
    case "uuid":
      return { t: "uuid", value: f.value! };
    case "uuidArray":
      return { t: "uuidArray", values: f.values! };
    case "string":
      return { t: "string", value: f.value! };
    case "bool":
      return { t: "bool", value: f.isNull === true ? null : f.bool! };
    case "int":
      return { t: "int", value: f.int! };
    case "dataJSON":
      return { t: "jsonValue", value: JSON.parse(f.json!) };
    case "null":
      return { t: "null" };
    default:
      throw new Error(`tag desconocido: ${f.t}`);
  }
}

describe(`canon c1 golden vectors (${golden.canon_version}) — ${golden.vectors.length} + ${golden.errorVectors.length} error`, () => {
  it("canon_version es c1", () => {
    expect(golden.canon_version).toBe("c1");
  });

  for (const v of golden.vectors) {
    it(`${v.id}: ${v.description}`, () => {
      const fields: Record<string, CanonValue> = {};
      for (const [k, f] of Object.entries(v.fields)) fields[k] = toCanonValue(f);
      const grouped = new Set(v.groupedColumns ?? []);
      expect(encodeCanonC1(fields, grouped)).toBe(v.expected);
    });
  }

  for (const v of golden.errorVectors) {
    it(`error ${v.id}: ${v.description}`, () => {
      const fields: Record<string, CanonValue> = {};
      for (const [k, f] of Object.entries(v.fields)) fields[k] = toCanonValue(f);
      try {
        encodeCanonC1(fields, new Set());
        expect.unreachable(`debió lanzar ${v.expectedError}`);
      } catch (e) {
        expect(e).toBeInstanceOf(CanonError);
        expect((e as CanonError).code).toBe(v.expectedError);
      }
    });
  }
});

describe("normalización PostgREST (ruta string/BigInt + timestamptz)", () => {
  it("NUMERIC::text con padding distinto re-cuantiza al canon (nunca passthrough)", () => {
    expect(decimalFixedFromString("19.990000", 4)).toBe("19.9900"); // sobre-padded
    expect(decimalFixedFromString("2.5", 4)).toBe("2.5000"); // sub-padded
    expect(decimalFixedFromString("-37.25", 4)).toBe("-37.2500");
    expect(decimalFixedFromString("0", 4)).toBe("0.0000");
    expect(decimalFixedFromString("-0.0000", 4)).toBe("0.0000"); // -0 → sin signo
    expect(decimalFixedFromString("3.62000000", 8)).toBe("3.62000000"); // tasa ya canónica
    expect(decimalFixedFromString("+1.5", 4)).toBe("1.5000");
  });

  it("re-cuantización HALF_EVEN desde texto: mitad exacta al PAR, resto>½ arriba", () => {
    expect(decimalFixedFromString("0.00005", 4)).toBe("0.0000"); // mitad DECIMAL exacta → par (≠ ruta double)
    expect(decimalFixedFromString("0.00015", 4)).toBe("0.0002"); // mitad exacta → par
    expect(decimalFixedFromString("0.000051", 4)).toBe("0.0001"); // > ½ → arriba
    expect(decimalFixedFromString("0.000049", 4)).toBe("0.0000"); // < ½ → abajo
  });

  it("NUMERIC::text fuera de rango / malformado → CanonError", () => {
    expect(() => decimalFixedFromString("100000000000000", 4)).toThrowError(/numericOutOfRange/);
    expect(() => decimalFixedFromString("10000000000", 8)).toThrowError(/numericOutOfRange/);
    expect(() => decimalFixedFromString("1e5", 4)).toThrowError(/malformedNumericText/);
    expect(() => decimalFixedFromString("", 4)).toThrowError(/malformedNumericText/);
  });

  it("timestamptz de PostgREST: offset +00:00 / µs / espacio → T-CANON ms-FLOOR", () => {
    const zulu = millisFromPostgresText("2023-11-14T22:13:20.000Z");
    expect(millisFromPostgresText("2023-11-14T22:13:20+00:00")).toBe(zulu);
    expect(millisFromPostgresText("2023-11-14T22:13:20.123456+00:00")).toBe(zulu + 123); // FLOOR sub-ms
    expect(millisFromPostgresText("2023-11-14 22:13:20+00:00")).toBe(zulu); // espacio como separador
    expect(millisFromPostgresText("2023-11-14T17:13:20-05:00")).toBe(zulu); // offset con signo
    expect(millisFromPostgresText("2023-11-14T17:13:20-0500")).toBe(zulu); // ±HHMM sin ':'
    // Round-trip ms → T-CANON → ms.
    expect(canonicalIsoFromMillis(zulu)).toBe("2023-11-14T22:13:20.000Z");
    expect(millisFromPostgresText(canonicalIsoFromMillis(1_700_000_000_123))).toBe(1_700_000_000_123);
  });

  it("timestamptz malformado → CanonError", () => {
    expect(() => millisFromPostgresText("2023-11-14")).toThrowError(/malformedTimestampText/);
    expect(() => millisFromPostgresText("2023-13-14T22:13:20Z")).toThrowError(/malformedTimestampText/);
  });
});
