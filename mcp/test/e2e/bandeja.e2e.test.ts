/**
 * E2E contra staging del lote 5 de «Bandeja sin duplicados»: `ver_bandeja`, la `referencia` y el aviso de posible
 * duplicado, con el conector y el gateway de staging de verdad (service binding, D1 y Supabase).
 *
 *   set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
 *   npx vitest run -c vitest.e2e.config.ts test/e2e/bandeja.e2e.test.ts
 *
 * Con `E2E_DUMP=<fichero>` guarda las respuestas tal cual, para enseñarlas.
 *
 * Escenarios, con el usuario de prueba A:
 *   E5. la IA apunta un gasto con la referencia de un correo y lo vuelve a apuntar: la segunda vez, «ya_apuntado»;
 *   E6. la IA apunta algo que A ya tiene guardado: «posible_duplicado» con el movimiento; con forzar, se crea;
 *   y ver_bandeja enseña lo apuntado esperando a la app.
 * Al final recoge de la cola lo que apuntó (como haría la app, con el ack) y revoca el permiso del cliente del Worker.
 */
import { writeFileSync } from "node:fs";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { A, authorize, discover, GATEWAY_URL, logout, mcp, passwordSession, register, revokeWorkerGrant, tool } from "./baile";

const RUN = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
const dump: Record<string, unknown> = { corrida: RUN };

describe.skipIf(!A.pass)("ver_bandeja, referencia y posible duplicado contra staging", () => {
  let token: string;

  beforeAll(async () => {
    const meta = await discover();
    const clientId = await register(meta);
    token = (await authorize(meta, clientId, A)).tokens.access_token;
  });

  afterAll(async () => {
    // Recoger lo que apuntó esta corrida, como la app: si no, se queda 30 días en la cola de A y cuenta para su techo.
    const s = await passwordSession(A);
    const headers = { Authorization: `Bearer ${s}`, "Content-Type": "application/json" };
    const list = (await (await fetch(`${GATEWAY_URL}/mail/drafts`, { headers })).json()) as { drafts?: { id: string; merchant?: string; source?: string }[] };
    const mine = (list.drafts ?? []).filter((d) => d.source === "ai" && (d.merchant ?? "").includes(RUN));
    if (mine.length > 0) {
      const ack = await fetch(`${GATEWAY_URL}/mail/drafts/ack`, { method: "POST", headers, body: JSON.stringify({ ids: mine.map((d) => d.id) }) });
      dump.limpieza = { recogidos: mine.length, status: ack.status };
    }
    await logout(s);
    await revokeWorkerGrant(A);
    if (process.env.E2E_DUMP) writeFileSync(process.env.E2E_DUMP, JSON.stringify(dump, null, 2));
  });

  it("tools/list ofrece ver_bandeja (lectura) junto a apuntar_movimiento, con referencia y forzar", async () => {
    const { tools } = (await mcp(token, "tools/list")) as { tools: { name: string; annotations?: Record<string, unknown>; inputSchema: { properties: Record<string, unknown> } }[] };
    const ver = tools.find((t) => t.name === "ver_bandeja");
    const apuntar = tools.find((t) => t.name === "apuntar_movimiento");
    expect(ver?.annotations).toMatchObject({ readOnlyHint: true });
    expect(Object.keys(apuntar!.inputSchema.properties)).toEqual(expect.arrayContaining(["referencia", "forzar"]));
    dump.herramientas = tools.map((t) => t.name);
  });

  it("E5: la misma referencia dos veces deja un solo borrador", async () => {
    const args = { importe: 13.37, nota: `E2E café ${RUN}`, referencia: `<e2e-${RUN}@mail.bcp.com.pe>`, forzar: true };
    const first = await tool(token, "apuntar_movimiento", args);
    expect(first.resultado).toBe("borrador_en_bandeja");
    const again = await tool(token, "apuntar_movimiento", { ...args, forzar: false });
    expect(again.resultado).toBe("ya_apuntado");
    dump.e5 = { primera: first, segunda: again };
  });

  it("E6: lo que ya está guardado vuelve como posible_duplicado, y con forzar se crea", async () => {
    // Un gasto real de A de las últimas semanas: el mismo importe, día y cuenta.
    const search = await tool(token, "buscar_movimientos", { limite: 50 });
    // Los movimientos de A en staging pueden no tener cuenta ni moneda: sin cuenta, la coincidencia sale «dudosa».
    const items = (search.movimientos ?? []) as { importe: number; divisa: string | null; fecha: string; tipo: string; cuenta: string | null; nota: string | null; gasto_de_grupo: boolean }[];
    const gasto = items.find((m) => m.tipo === "gasto" && m.importe < 0 && !m.gasto_de_grupo);
    expect(gasto, JSON.stringify(search).slice(0, 400)).toBeTruthy();
    const args: Record<string, unknown> = { importe: Math.abs(gasto!.importe), fecha: gasto!.fecha.slice(0, 10), nota: `E2E ${gasto!.nota ?? "gasto"} ${RUN}`.slice(0, 80) };
    if (gasto!.divisa) args.divisa = gasto!.divisa;
    if (gasto!.cuenta) args.cuenta = gasto!.cuenta;

    const dup = await tool(token, "apuntar_movimiento", args);
    expect(dup.resultado, JSON.stringify(dup)).toBe("posible_duplicado");
    expect(dup.coincidencias.some((c: { donde: string }) => c.donde === "ya guardado")).toBe(true);

    const forced = await tool(token, "apuntar_movimiento", { ...args, forzar: true });
    expect(forced.resultado).toBe("borrador_en_bandeja");
    dump.e6 = { guardado: gasto, aviso: dup, forzado: forced };
  });

  it("ver_bandeja enseña lo apuntado esperando a la app", async () => {
    const out = await tool(token, "ver_bandeja");
    expect(Array.isArray(out.pendientes)).toBe(true);
    const mine = (out.en_cola as { nota: string | null; fuente: string }[]).filter((d) => (d.nota ?? "").includes(RUN));
    expect(mine.length).toBe(2);
    expect(mine.every((d) => d.fuente === "Claude")).toBe(true);
    dump.ver_bandeja = { pendientes: out.pendientes.length, en_cola_de_esta_corrida: mine, avisos: out.avisos };
  });
});
