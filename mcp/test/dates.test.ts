import { describe, expect, it } from "vitest";
import {
  addDays,
  assertDay,
  dayInZone,
  daysInclusive,
  InvalidInputError,
  monthEnd,
  resolvePeriod,
  txDay,
  weekStart,
  zonedDayStartUtc,
} from "../src/logic/dates";

describe("días en la zona del usuario", () => {
  it("un instante UTC de madrugada es el día anterior en Lima", () => {
    expect(dayInZone("2026-10-01T03:00:00Z", "America/Lima")).toBe("2026-09-30");
    expect(dayInZone("2026-10-01T05:00:00Z", "America/Lima")).toBe("2026-10-01");
  });

  it("el día empieza a las 05:00 UTC en Lima y respeta el cambio de hora en Madrid", () => {
    expect(zonedDayStartUtc("2026-09-01", "America/Lima").toISOString()).toBe("2026-09-01T05:00:00.000Z");
    // Madrid: verano UTC+2, invierno UTC+1 (cambio el 25-oct-2026).
    expect(zonedDayStartUtc("2026-10-25", "Europe/Madrid").toISOString()).toBe("2026-10-24T22:00:00.000Z");
    expect(zonedDayStartUtc("2026-10-26", "Europe/Madrid").toISOString()).toBe("2026-10-25T23:00:00.000Z");
    // Santiago adelanta la hora a medianoche el 6-sep-2026: ese día empieza a la 01:00 local (04:00Z).
    expect(zonedDayStartUtc("2026-09-06", "America/Santiago").toISOString()).toBe("2026-09-06T04:00:00.000Z");
    expect(dayInZone(zonedDayStartUtc("2026-09-06", "America/Santiago"), "America/Santiago")).toBe("2026-09-06");
  });

  it("local_day manda sobre date: es el día que vio el usuario", () => {
    expect(txDay({ local_day: "2026-09-01", date: "2026-09-02T04:00:00Z" }, "UTC")).toBe("2026-09-01");
    expect(txDay({ local_day: null, date: "2026-09-02T04:00:00Z" }, "America/Lima")).toBe("2026-09-01");
    expect(txDay({ local_day: null, date: null }, "America/Lima")).toBeNull();
  });

  it("aritmética de días y meses", () => {
    expect(addDays("2026-02-28", 1)).toBe("2026-03-01");
    expect(monthEnd("2028-02-10")).toBe("2028-02-29");
    expect(daysInclusive("2026-09-01", "2026-09-30")).toBe(30);
    // 2026-09-26 es sábado.
    expect(weekStart("2026-09-26", 2)).toBe("2026-09-21");
    expect(weekStart("2026-09-26", 1)).toBe("2026-09-20");
    expect(weekStart("2026-09-21", 2)).toBe("2026-09-21");
  });

  it("valida fechas de entrada", () => {
    expect(() => assertDay("2026-02-30", "desde")).toThrow(InvalidInputError);
    expect(() => assertDay("26-09-2026", "desde")).toThrow(InvalidInputError);
    expect(assertDay("2026-02-28", "desde")).toBe("2026-02-28");
  });
});

describe("periodos", () => {
  const today = "2026-09-26";

  it("mes en curso llega hasta hoy; mes pasado cierra el último día, sin tocar el 1 del actual", () => {
    expect(resolvePeriod("mes_actual", today)).toMatchObject({ desde: "2026-09-01", hasta: "2026-09-26" });
    expect(resolvePeriod("mes_pasado", today)).toMatchObject({ desde: "2026-08-01", hasta: "2026-08-31" });
    expect(resolvePeriod("mes_pasado", "2026-01-15")).toMatchObject({ desde: "2025-12-01", hasta: "2025-12-31" });
  });

  it("rango exige desde y hasta ordenados y acotados", () => {
    expect(() => resolvePeriod("rango", today, { desde: "2026-09-10" })).toThrow(InvalidInputError);
    expect(() => resolvePeriod("rango", today, { desde: "2026-09-10", hasta: "2026-09-01" })).toThrow(InvalidInputError);
    expect(() => resolvePeriod("rango", today, { desde: "2020-01-01", hasta: "2026-01-01" })).toThrow(InvalidInputError);
    expect(resolvePeriod("rango", today, { desde: "2026-09-01", hasta: "2026-09-10" })).toMatchObject({ desde: "2026-09-01" });
  });
});
