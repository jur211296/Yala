// generate-groups-merkle-fixtures.mjs
//
// Genera `groups_merkle_fixtures.json` (raíz del repo) — el mini-golden cross-lenguaje de la PROYECCIÓN
// Merkle del canal de GRUPOS (endurecimiento B1, [R2]). Es EL gate load-bearing: en DARK, la única red
// contra una divergencia silenciosa entre el canon del server (TS) y la proyección del cliente (Swift).
//
// Importa las primitivas del gateway SIN MODIFICARLAS (`canonRowC1Group`/`merkleColumnsGroup` de
// src/groups/canon.ts + `leafChannel1`/`entityHash`/`merkleRoot`/`hex` de src/sync/merkle.ts). Como el
// gateway está en TypeScript ESM con imports de JSON, se bundlea al vuelo con esbuild (devDep) y se importa
// vía data-URL — plain `node scripts/…mjs`, sin tsx.
//
// Determinismo: filas de muestra FIJAS, orden de inserción FIJO, JSON con indent estable → correr dos veces
// produce bytes idénticos (verificable con diff). El Swift `GroupMerkleFixtureTests` reproyecta las MISMAS
// filas con `GroupMerkleProjection` + `Canonc1Codec` y compara payload/leaf/entityHash/root byte a byte.
//
// Decisión de fidelidad (documentada): los `amount` (numeric) se emiten al canon como su TEXTO ::text de
// escala fija (lo que PostgREST devuelve de una columna numeric(_,4)) vía `decimalFixedFromDouble` — el
// MISMO valor lógico que el @Model Swift (Double) proyecta con su `decimalFixed`. Las muestras usan montos
// exactos en escala 4 (como quedan tras el round-trip por la DB), así el path string del server y el path
// double del cliente convergen (para valores no-escala-exacta divergirían — fuera del alcance de este gate,
// cubierto por merkle.unit.test / la DB que redondea al insertar).

import { build } from "esbuild";
import { readFileSync, writeFileSync, copyFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const scriptDir = dirname(fileURLToPath(import.meta.url)); // gateway/scripts
const gatewayDir = resolve(scriptDir, "..");               // gateway
const repoRoot = resolve(gatewayDir, "..");                // repo root

// SSOT del manifest (idempotente — espeja `npm run sync:manifest`, para correr standalone).
copyFileSync(
  resolve(repoRoot, "group_capability_manifest.json"),
  resolve(gatewayDir, "group_capability_manifest.json"),
);

// --- Bundle de las primitivas del gateway (sin tocar src/) ---
const entry = `
export { canonRowC1Group, merkleColumnsGroup } from "./src/groups/canon.ts";
export { decimalFixedFromDouble, canonicalIsoFromMillis } from "./src/sync/canon.ts";
export { leafChannel1, entityHash, merkleRoot, hex } from "./src/sync/merkle.ts";
`;
const bundled = await build({
  stdin: { contents: entry, resolveDir: gatewayDir, loader: "ts", sourcefile: "entry.ts" },
  bundle: true,
  format: "esm",
  platform: "node",
  target: "es2022",
  write: false,
});
const dataURL = "data:text/javascript;base64," + Buffer.from(bundled.outputFiles[0].text).toString("base64");
const {
  canonRowC1Group, merkleColumnsGroup, decimalFixedFromDouble, canonicalIsoFromMillis,
  leafChannel1, entityHash, merkleRoot, hex,
} = await import(dataURL);

// --- Timestamps fijos (epoch ms) usados por las muestras ---
const T_MS_A = Date.UTC(2026, 6, 15, 12, 0, 0, 123); // con milisegundos
const T_MS_B = Date.UTC(2026, 5, 1, 8, 30, 15, 0);   // segundo entero
const T_MS_C = Date.UTC(2026, 0, 31, 23, 59, 59, 999);

// --- Muestras LÓGICAS por entidad (valores representativos: unicode, NULLs, booleans, timestamps, montos) ---
// El `model` es lo que el test Swift usa para construir el @Model; el generador lo convierte a la fila
// PostgREST cruda (dbRow) que consume `canonRowC1Group`.
const SAMPLES = {
  split_expenses: [
    {
      sync_id: "c0ffee00-1111-2222-3333-444444444444",
      model: {
        amount: 19.99, currency_code: "USD", expense_description: "Café ☕ del día",
        note: "propina 15% 🎉", date_ms: T_MS_A, created_at_ms: T_MS_A,
        paid_by_member_key: "member-abc", split_type: "equal",
        is_settled: false, is_opening_balance: false, subcategory_name: "Comida",
      },
    },
    {
      sync_id: "1a2b3c4d-5e6f-7788-99aa-bbccddeeff00",
      model: {
        amount: 1234.5678, currency_code: "PEN", expense_description: "Groceries",
        note: null, date_ms: T_MS_B, created_at_ms: T_MS_B,
        paid_by_member_key: "member-2", split_type: "exact",
        is_settled: true, is_opening_balance: true, subcategory_name: null,
      },
    },
    {
      sync_id: "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb",
      model: {
        amount: 0.0, currency_code: "EUR", expense_description: "Ñoño 日本語 test",
        note: "", date_ms: T_MS_C, created_at_ms: T_MS_C,
        paid_by_member_key: "member-3", split_type: "shares",
        is_settled: false, is_opening_balance: false, subcategory_name: null,
      },
    },
  ],
  split_shares: [
    {
      sync_id: "aaaa0000-1111-2222-3333-444455556666",
      model: {
        expense_id: "c0ffee00-1111-2222-3333-444444444444", member_key: "member-abc",
        amount: 6.66, is_paid: false,
      },
    },
    {
      sync_id: "bbbb1111-2222-3333-4444-555566667777",
      model: {
        expense_id: "c0ffee00-1111-2222-3333-444444444444", member_key: "member-xyz",
        amount: 6.665, is_paid: true,
      },
    },
  ],
  split_settlements: [
    {
      sync_id: "5e771e00-0000-1111-2222-333344445555",
      model: {
        from_member_key: "member-abc", to_member_key: "member-xyz", amount: 25.0,
        currency_code: "USD", note: "saldado ✅", date_ms: T_MS_A, is_confirmed: true,
      },
    },
    {
      sync_id: "5e771e11-1111-2222-3333-444455556666",
      model: {
        from_member_key: "member-3", to_member_key: "member-abc", amount: 0.5,
        currency_code: "PEN", note: null, date_ms: T_MS_B, is_confirmed: false,
      },
    },
  ],
  split_groups: [
    {
      group_id: "SplitGroup-A1B2C3D4",
      model: {
        name: "Casa 🏠", icon_name: "house.fill", color_hex: "#8B5CF6", currency_code: "PEN",
        simplify_debts: true, show_debts_in_single_currency: false, members_can_invite: true,
        default_split_type: "equal", is_archived: false, is_hidden_for_all: false, created_at_ms: T_MS_A,
      },
    },
    {
      group_id: "SplitGroup-Zebra9",
      model: {
        name: "Viaje ✈️ 2026", icon_name: "airplane", color_hex: "#112233", currency_code: "USD",
        simplify_debts: false, show_debts_in_single_currency: true, members_can_invite: false,
        default_split_type: "percentage", is_archived: true, is_hidden_for_all: false, created_at_ms: T_MS_C,
      },
    },
  ],
  group_members: [
    {
      member_key: "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
      model: {
        user_id: "3f2504e0-4f89-41d3-9a0c-0305e82c3301", display_name: "Alicia ✨",
        role: "admin", status: "active", joined_at_ms: T_MS_A,
      },
    },
    {
      member_key: "member-legacy-recordname",
      model: {
        user_id: null, display_name: "Bob", role: "member", status: "left", joined_at_ms: T_MS_B,
      },
    },
  ],
};

// --- Conversión model → fila PostgREST cruda (dbRow) por entidad ---
function isoOrNull(ms) {
  return ms === null || ms === undefined ? null : canonicalIsoFromMillis(ms);
}
function moneyText(x) {
  return decimalFixedFromDouble(x, 4); // ::text de numeric(_,4)
}
function toDbRow(entity, m) {
  switch (entity) {
    case "split_expenses":
      return {
        amount: moneyText(m.amount), currency_code: m.currency_code,
        expense_description: m.expense_description, note: m.note,
        date: isoOrNull(m.date_ms), created_at: isoOrNull(m.created_at_ms),
        paid_by_member_key: m.paid_by_member_key, split_type: m.split_type,
        is_settled: m.is_settled, is_opening_balance: m.is_opening_balance,
        subcategory_name: m.subcategory_name,
      };
    case "split_shares":
      return { expense_id: m.expense_id, member_key: m.member_key, amount: moneyText(m.amount), is_paid: m.is_paid };
    case "split_settlements":
      return {
        from_member_key: m.from_member_key, to_member_key: m.to_member_key, amount: moneyText(m.amount),
        currency_code: m.currency_code, note: m.note, date: isoOrNull(m.date_ms), is_confirmed: m.is_confirmed,
      };
    case "split_groups":
      return {
        name: m.name, icon_name: m.icon_name, color_hex: m.color_hex, currency_code: m.currency_code,
        simplify_debts: m.simplify_debts, show_debts_in_single_currency: m.show_debts_in_single_currency,
        members_can_invite: m.members_can_invite, default_split_type: m.default_split_type,
        is_archived: m.is_archived, is_hidden_for_all: m.is_hidden_for_all, created_at: isoOrNull(m.created_at_ms),
      };
    case "group_members":
      return {
        user_id: m.user_id, display_name: m.display_name, role: m.role, status: m.status,
        joined_at: isoOrNull(m.joined_at_ms),
      };
    default:
      throw new Error(`entidad desconocida: ${entity}`);
  }
}
function identityOf(entity, sample) {
  if (entity === "split_groups") return sample.group_id.toLowerCase();
  if (entity === "group_members") return sample.member_key.toLowerCase();
  return sample.sync_id.toLowerCase();
}

// Orden CANÓNICO de las 5 tablas (keys del manifest = orden del endpoint).
const ENTITIES = ["split_groups", "group_members", "split_expenses", "split_shares", "split_settlements"];

const entitiesOut = {};
const entityHashMap = new Map();

for (const entity of ENTITIES) {
  const columns = merkleColumnsGroup(entity);
  const samplesOut = [];
  const leaves = [];
  for (const sample of SAMPLES[entity]) {
    const dbRow = toDbRow(entity, sample.model);
    const payload = canonRowC1Group(entity, dbRow, columns);
    const id = identityOf(entity, sample);
    const leaf = await leafChannel1(id, payload);
    leaves.push({ syncId: id, leaf });
    samplesOut.push({
      identity: id,
      ...(entity === "split_groups"
        ? { group_id: sample.group_id }
        : entity === "group_members"
          ? { member_key: sample.member_key }
          : { sync_id: sample.sync_id }),
      model: sample.model,
      payload_c1: payload,
      leaf_hex: hex(leaf),
    });
  }
  const eh = await entityHash(leaves);
  entityHashMap.set(entity, eh);
  entitiesOut[entity] = { entity_hash_hex: hex(eh), samples: samplesOut };
}

const root = await merkleRoot(entityHashMap);

// Corpus VACÍO (las 5 tablas con hash-vacío) — referencia del test de store vacío y del guard remoto-vacío.
const emptyEH = await entityHash([]);
const emptyMap = new Map();
for (const entity of ENTITIES) emptyMap.set(entity, emptyEH);
const emptyRoot = await merkleRoot(emptyMap);

const out = {
  description:
    "Golden cross-lenguaje de la PROYECCIÓN Merkle del canal de GRUPOS (B1, regla A-4 canal 1). Generado por " +
    "gateway/scripts/generate-groups-merkle-fixtures.mjs importando canonRowC1Group/merkleColumnsGroup/" +
    "leafChannel1/entityHash/merkleRoot de gateway/src SIN modificarlos. Consumido por GroupMerkleFixtureTests " +
    "(Swift): reproyecta cada `model` con GroupMerkleProjection+Canonc1Codec y compara payload_c1/leaf_hex/" +
    "entity_hash_hex/root byte a byte. Montos: ::text de numeric(_,4) (escala exacta). Timestamps: epoch ms.",
  empty_entity_hash_hex: hex(emptyEH),
  empty_root_hex: hex(emptyRoot),
  root_hex: hex(root),
  entities: entitiesOut,
};

const outPath = resolve(repoRoot, "groups_merkle_fixtures.json");
writeFileSync(outPath, JSON.stringify(out, null, 2) + "\n", "utf8");
console.log(`groups_merkle_fixtures.json escrito (${SAMPLES ? Object.keys(SAMPLES).length : 0} entidades) → ${outPath}`);
