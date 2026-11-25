/**
 * `conReintentoD1` y `esD1Saturada` (2026-11-25, YALA-GATEWAY-2/3/4): qué se reintenta, cuántas veces y cuánto espera.
 *
 * Lo que fija, por gravedad si se rompiera:
 *  - **Hay tope**: con D1 saturada siempre, se rinde tras `intentos` llamadas y relanza el error de D1 (el que
 *    `app.onError` convierte en 503). Sin tope, una saturación larga colgaría cada petición.
 *  - **Solo se reintenta la cola saturada**: un error de SQL o cualquier otro sube a la primera. Reintentar «Network
 *    connection lost» podría repetir una escritura que sí se ejecutó.
 *  - **Backoff con jitter acotado**: la espera n-ésima cae en [0, min(maxMs, baseMs·2^(n-1))).
 */
import { describe, expect, it, vi } from "vitest";
import { conReintentoD1, esD1Saturada, INTENTOS_D1_POR_DEFECTO } from "../../src/d1-reintento";
import { errorSaturada } from "./fakeD1Saturable";

describe("esD1Saturada", () => {
  it("reconoce el error tal como lo dio producción (mensaje y causa encadenada)", () => {
    expect(esD1Saturada(errorSaturada())).toBe(true);
  });

  it("reconoce la marca aunque solo venga en la causa", () => {
    const err = new Error("D1_ERROR", { cause: new Error("Requests queued for too long.") });
    expect(esD1Saturada(err)).toBe(true);
  });

  it("reconoce «Too many requests queued», de la misma familia", () => {
    expect(esD1Saturada(new Error("D1_ERROR: Too many requests queued."))).toBe(true);
  });

  it("NO reconoce otros errores de D1 ni valores que no son Error", () => {
    expect(esD1Saturada(new Error("D1_ERROR: no such table: account_entitlements"))).toBe(false);
    expect(esD1Saturada(new Error("D1_ERROR: Network connection lost."))).toBe(false);
    expect(esD1Saturada(new Error("UNIQUE constraint failed"))).toBe(false);
    expect(esD1Saturada(null)).toBe(false);
    expect(esD1Saturada("algo")).toBe(false);
  });
});

describe("conReintentoD1", () => {
  const sinEspera = { dormir: async () => {}, aleatorio: () => 0.5 };

  it("reintenta la saturación y devuelve el resultado del intento bueno", async () => {
    const fn = vi.fn().mockRejectedValueOnce(errorSaturada()).mockResolvedValueOnce("ok");
    await expect(conReintentoD1(fn, sinEspera)).resolves.toBe("ok");
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it("tiene tope: con D1 saturada siempre, se rinde tras los intentos y relanza el error de D1", async () => {
    const fn = vi.fn().mockRejectedValue(errorSaturada());
    const err = await conReintentoD1(fn, sinEspera).catch((e: unknown) => e);
    expect(esD1Saturada(err)).toBe(true);
    expect(fn).toHaveBeenCalledTimes(INTENTOS_D1_POR_DEFECTO);
    expect(INTENTOS_D1_POR_DEFECTO).toBe(3);
  });

  it("no reintenta un error que no es de saturación", async () => {
    const fn = vi.fn().mockRejectedValue(new Error("D1_ERROR: no such table: account_entitlements"));
    await expect(conReintentoD1(fn, sinEspera)).rejects.toThrow("no such table");
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it("no reintenta lo que sale bien a la primera", async () => {
    const fn = vi.fn().mockResolvedValue(42);
    await expect(conReintentoD1(fn, sinEspera)).resolves.toBe(42);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it("la espera crece en exponencial con jitter completo y respeta el tope por espera", async () => {
    const esperas: number[] = [];
    const fn = vi.fn().mockRejectedValue(errorSaturada());
    await conReintentoD1(fn, {
      intentos: 5,
      baseMs: 100,
      maxMs: 300,
      aleatorio: () => 0.999,
      dormir: async (ms) => {
        esperas.push(ms);
      },
    }).catch(() => {});
    // Techos 100, 200, 400→300, 800→300; con aleatorio≈1 la espera roza cada techo sin pasarlo.
    expect(esperas).toEqual([99, 199, 299, 299]);
  });

  it("con aleatorio 0 no espera nada (el jitter completo incluye el cero)", async () => {
    const esperas: number[] = [];
    const fn = vi.fn().mockRejectedValueOnce(errorSaturada()).mockResolvedValueOnce("ok");
    await conReintentoD1(fn, { aleatorio: () => 0, dormir: async (ms) => void esperas.push(ms) });
    expect(esperas).toEqual([0]);
  });

  it("el peor caso por defecto añade como mucho ~300 ms", async () => {
    const esperas: number[] = [];
    const fn = vi.fn().mockRejectedValue(errorSaturada());
    await conReintentoD1(fn, { aleatorio: () => 0.999, dormir: async (ms) => void esperas.push(ms) }).catch(() => {});
    expect(esperas.reduce((a, b) => a + b, 0)).toBeLessThan(300);
  });
});
