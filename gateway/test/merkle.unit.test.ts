/**
 * Unit OFFLINE del ensamblado Merkle (I8f-3, regla A-4) contra `merkle_fixtures.json` (raíz del repo
 * Yala) — el mini-golden cross-lenguaje compartido con `SyncMerkleTests` (Swift): si el ENSAMBLADO
 * (leaf/entityHash/root/leaf2) diverge un byte, ambos lados lo ven. + unit del pipeline fila-PostgREST
 * → payload canónico (`merkleColumns`/`canonRowC1`): exclusión de `local_day` (A-2b), NULL≡'{}' de
 * uuid[] agrupada, NUMERIC::text re-cuantizado.
 */
import { describe, expect, it } from "vitest";
import fixtureJson from "../../merkle_fixtures.json";
import { canonRowC1, merkleColumns } from "../src/sync/canon";
import { entityHash, hex, leafChannel1, leafChannel2, merkleRoot } from "../src/sync/merkle";

interface Fixture {
  empty_entity_hash_hex: string;
  leaves: Array<{ sync_id: string; payload: string; leaf_hex: string }>;
  entity_case: { entity_hash_hex: string };
  root_case: { entity_hashes_hex: Record<string, string>; root_hex: string };
  channel2_case: { sync_id: string; hlc: string; payload: string; leaf2_hex: string };
}

const fixture = fixtureJson as unknown as Fixture;

function fromHex(h: string): Uint8Array {
  const out = new Uint8Array(h.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = Number.parseInt(h.slice(i * 2, i * 2 + 2), 16);
  return out;
}

describe("merkle · ensamblado A-4 (fixtures cross-lenguaje)", () => {
  it("leaf = sha256(utf8(sync_id) ‖ sha256(utf8(payload)))", async () => {
    for (const l of fixture.leaves) {
      expect(hex(await leafChannel1(l.sync_id, l.payload))).toBe(l.leaf_hex);
    }
  });

  it("entityHash ordena los leaves por sync_id bytes UTF-8 asc (input desordenado)", async () => {
    const leaves = [];
    for (const l of fixture.leaves) {
      leaves.push({ syncId: l.sync_id, leaf: await leafChannel1(l.sync_id, l.payload) });
    }
    expect(hex(await entityHash(leaves))).toBe(fixture.entity_case.entity_hash_hex);
  });

  it("entidad vacía → sha256('')", async () => {
    expect(hex(await entityHash([]))).toBe(fixture.empty_entity_hash_hex);
  });

  it("root = sha256(concat(entityHash en orden UTF-8 asc de tabla))", async () => {
    const map = new Map<string, Uint8Array>();
    for (const [table, h] of Object.entries(fixture.root_case.entity_hashes_hex)) {
      map.set(table, fromHex(h));
    }
    expect(hex(await merkleRoot(map))).toBe(fixture.root_case.root_hex);
  });

  it("leaf2 = sha256(utf8(sync_id) ‖ utf8(hlc) ‖ sha256(utf8(payload)))", async () => {
    const c = fixture.channel2_case;
    expect(hex(await leafChannel2(c.sync_id, c.hlc, c.payload))).toBe(c.leaf2_hex);
  });
});

describe("merkle · fila PostgREST → payload canónico", () => {
  it("merkleColumns excluye local_day (A-2b) y conserva el resto del set", () => {
    const cols = merkleColumns("tx_items", {});
    expect(cols).not.toContain("local_day");
    expect(cols).toContain("date");
    expect(cols).toContain("amount");
  });

  it("canonRowC1: NUMERIC::text re-cuantizado, timestamptz normalizado, uuid[] NULL≡'{}' singleton omitida", () => {
    const columns = merkleColumns("tx_items", {});
    const row: Record<string, unknown> = {
      sync_id: "AAAAAAAA-0000-0000-0000-000000000001",
      date: "2023-11-14 22:13:20.123456+00:00", // texto PostgREST con µs + offset
      amount: "-37.250000", // ::text con padding raro
      currency_code: "PEN",
      note: "café",
      category_ref: null,
      subcategory_ref: null,
      account_ref: null,
      tag_refs: null, // NULL ≡ '{}' → singleton → key OMITIDA
      amount_in_preferred_currency: "-37.2500",
      preferred_currency_code: "PEN",
      exchange_rate: "1.00000000",
      is_exchange_rate_provisional: false,
      need_override: null,
      scheduled_payment_ref: null,
      balance_adjustment_type: null,
      transfer_pair_id: null,
      split_expense_id: null,
      split_group_zone_id: null,
      split_settlement_id: null,
      split_total_amount: null,
      split_type: null,
      split_my_value: null,
      split_divisor: null,
      created_at: "2023-11-14T22:13:20+00:00",
    };
    const payload = canonRowC1("tx_items", row, columns);
    expect(payload).toContain('"amount":"-37.2500"');
    expect(payload).toContain('"date":"2023-11-14T22:13:20.123Z"'); // µs FLOOR + Z literal
    expect(payload).toContain('"created_at":"2023-11-14T22:13:20.000Z"');
    expect(payload).not.toContain("tag_refs"); // NULL singleton → omitida
    expect(payload).not.toContain("local_day");
    expect(payload).toContain('"note":"café"');
    expect(payload).toContain('"category_ref":null'); // NULL en-set → key:null
    // Determinismo: mismo row → mismos bytes.
    expect(canonRowC1("tx_items", row, columns)).toBe(payload);
  });

  it("canonRowC1: uuid[] AGRUPADA con NULL≡'{}' → [] explícito (budgets, DIFERIDOS #25)", () => {
    const columns = merkleColumns("budgets", {});
    const row: Record<string, unknown> = {
      name: "B",
      currency_code: "PEN",
      limit_amount: "250.5000",
      category_id: null,
      period_type: "monthly",
      start_date: null,
      end_date: null,
      natures: ["gasto"],
      subcategory_ids: null, // agrupada + NULL → []
      account_ids: [],       // agrupada + '{}' → []
      tag_refs: null,        // agrupada + NULL → []
      is_active: true,
      created_at: "2026-07-08T00:00:00+00:00",
      is_favorite: false,
      favorite_order: 0,
      alert_enabled: false,
      alert_thresholds: [],
      include_shared_expenses: false,
    };
    const payload = canonRowC1("budgets", row, columns);
    expect(payload).toContain('"subcategory_ids":[]');
    expect(payload).toContain('"account_ids":[]');
    expect(payload).toContain('"tag_refs":[]');
    expect(payload).toContain('"limit_amount":"250.5000"');
    expect(payload).toContain('"natures":["gasto"]');
  });
});
