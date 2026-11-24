/**
 * La regla de coincidencia de lo que apunta la IA (`src/connector/match.ts`), fila a fila de su tabla. Lo que fija, por
 * gravedad si se rompiera:
 *  - la misma fuente nunca casa (dos cafés por Apple Pay son dos cafés; la misma IA, igual);
 *  - un ingreso nunca casa con un gasto, ni dos cuentas distintas, ni dos divisas distintas;
 *  - fuerte solo con importe exacto, ±1 día, la misma cuenta y comercio parecido; lo demás que casa, dudosa.
 */
import { describe, expect, it } from "vitest";
import {
  dayDistance,
  findPossibleDuplicates,
  matchLevel,
  MAX_MATCHES,
  similarMerchant,
  type IncomingDraft,
  type MatchCandidate,
} from "../src/connector/match";

const BCP = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const YAPE = "bbbbbbbb-bbbb-4ccc-8ddd-eeeeeeeeeeee";

const cafe: IncomingDraft = {
  fuente: "ai:Claude",
  kind: "expense",
  amount: 42.5,
  currency: "PEN",
  day: "2026-11-15",
  account_id: BCP,
  account_name: "BCP Visa",
  merchant: "Starbucks",
};

const applePay = (over: Partial<MatchCandidate> = {}): MatchCandidate => ({
  donde: "bandeja",
  fuente: "applePay",
  kind: "expense",
  amount: 42.5,
  currency: "PEN",
  day: "2026-11-15",
  account_id: null,
  account_name: "BCP Visa",
  merchant: "STARBUCKS MIRAFLORES",
  ...over,
});

describe("matchLevel", () => {
  it("el mismo café por Apple Pay, misma cuenta, mismo día: fuerte", () => {
    expect(matchLevel(cafe, applePay())).toBe("fuerte");
  });

  it("la misma fuente nunca casa: ni la misma IA, ni dos de Apple Pay", () => {
    expect(matchLevel(cafe, applePay({ fuente: "ai:Claude", donde: "cola" }))).toBeNull();
    expect(matchLevel({ ...cafe, fuente: "applePay" }, applePay())).toBeNull();
    // Otra IA sí es otra fuente.
    expect(matchLevel(cafe, applePay({ fuente: "ai:ChatGPT", donde: "cola" }))).toBe("fuerte");
  });

  it("un ingreso no casa con un gasto (reembolso el mismo día, E9)", () => {
    expect(matchLevel(cafe, applePay({ kind: "income" }))).toBeNull();
  });

  it("dos cuentas distintas no casan; una sin cuenta es dudosa", () => {
    expect(matchLevel(cafe, applePay({ account_name: "Yape" }))).toBeNull();
    expect(matchLevel(cafe, applePay({ account_id: YAPE, account_name: null, donde: "guardado", fuente: "guardado" }))).toBeNull();
    expect(matchLevel(cafe, applePay({ account_name: null }))).toBe("dudosa");
    expect(matchLevel({ ...cafe, account_id: null, account_name: null }, applePay())).toBe("dudosa");
  });

  it("por id cuando los dos lo traen, por nombre si no", () => {
    expect(matchLevel(cafe, applePay({ account_id: BCP.toUpperCase(), account_name: "Otro nombre" }))).toBe("fuerte");
    expect(matchLevel(cafe, applePay({ account_id: null, account_name: "bcp  VISA" }))).toBe("fuerte");
  });

  it("otra divisa no se compara (sin tipos de cambio aquí); sin divisa, sí", () => {
    expect(matchLevel(cafe, applePay({ currency: "USD", amount: 42.5 }))).toBeNull();
    expect(matchLevel(cafe, applePay({ currency: null }))).toBe("fuerte");
  });

  it("importe: ±0,01 fuerte, ±3 % dudosa, más no casa", () => {
    expect(matchLevel(cafe, applePay({ amount: 42.51 }))).toBe("fuerte");
    expect(matchLevel(cafe, applePay({ amount: 43.5 }))).toBe("dudosa"); // 2,3 %
    expect(matchLevel(cafe, applePay({ amount: 44 }))).toBeNull(); // 3,4 %
  });

  it("día: ±1 fuerte (cruce de medianoche, E2), hasta ±3 dudosa, más no casa", () => {
    expect(matchLevel(cafe, applePay({ day: "2026-11-16" }))).toBe("fuerte");
    expect(matchLevel(cafe, applePay({ day: "2026-11-14" }))).toBe("fuerte");
    expect(matchLevel(cafe, applePay({ day: "2026-11-18" }))).toBe("dudosa");
    expect(matchLevel(cafe, applePay({ day: "2026-11-19" }))).toBeNull();
    expect(matchLevel(cafe, applePay({ day: null }))).toBeNull();
  });

  it("comercio distinto baja a dudosa; vacío no resta", () => {
    expect(matchLevel(cafe, applePay({ merchant: "Tambo" }))).toBe("dudosa");
    expect(matchLevel(cafe, applePay({ merchant: null }))).toBe("fuerte");
    expect(matchLevel({ ...cafe, merchant: null }, applePay())).toBe("fuerte");
  });
});

describe("similarMerchant y dayDistance", () => {
  it.each([
    ["Starbucks", "STARBUCKS MIRAFLORES", true],
    ["Café Tostado", "cafe tostado sac", true],
    ["Luz del Sur", "LUZDELSUR", true],
    ["Uber", "Uber Eats", true],
    ["Tambo", "Starbucks", false],
    ["Almuerzo", "Mercado", false],
  ])("%s ~ %s: %s", (a, b, expected) => {
    expect(similarMerchant(a, b)).toBe(expected);
  });

  it("cuenta días de calendario, sin hora", () => {
    expect(dayDistance("2026-11-15", "2026-11-15")).toBe(0);
    expect(dayDistance("2026-11-30", "2026-12-01")).toBe(1);
    expect(dayDistance("2026-11-15", "2026-11-12")).toBe(3);
    expect(dayDistance("2026-11-15", "15/11/2026")).toBeNull();
  });
});

describe("findPossibleDuplicates", () => {
  it("los fuertes primero, luego por cercanía; como mucho cinco", () => {
    const many: MatchCandidate[] = [
      applePay({ merchant: "Tambo", day: "2026-11-15" }), // dudosa
      applePay({ day: "2026-11-16" }), // fuerte, a 1 día
      applePay({ day: "2026-11-15", fuente: "correo", donde: "cola" }), // fuerte, a 0 días
      ...Array.from({ length: 6 }, (_, i) => applePay({ fuente: `x${i}`, merchant: "Otro", day: "2026-11-17" })),
    ];
    const out = findPossibleDuplicates(cafe, many);
    expect(out).toHaveLength(MAX_MATCHES);
    expect(out.slice(0, 2).map((m) => [m.nivel, m.day, m.fuente])).toEqual([
      ["fuerte", "2026-11-15", "correo"],
      ["fuerte", "2026-11-16", "applePay"],
    ]);
    expect(out[2]).toMatchObject({ nivel: "dudosa", merchant: "Tambo" });
  });

  it("sin nada parecido, vacío", () => {
    expect(findPossibleDuplicates(cafe, [applePay({ amount: 12 }), applePay({ kind: "income" })])).toEqual([]);
  });
});
