/**
 * Cómo nombra la app a un miembro dentro de los gastos, las cuotas y los pagos de un grupo.
 *
 * En `group_members` cada persona tiene su `member_key` (el `sub` de su cuenta, o el `recordName` de iCloud en un grupo
 * que vino de la era CloudKit). Pero en las filas que la app escribe (`paid_by_member_key`, `split_shares.member_key`,
 * `from_member_key`, `to_member_key`, `last_edited_by_member_key`, `recorded_by_member_key`) NO va esa clave: va el id
 * LOCAL del `SplitMember` en el iPhone (`member.id.uuidString`), que la app deriva de la clave al bajarla
 * (`GroupsSyncClient.applyMember`):
 *
 *   - clave que parsea como UUID → `GroupBackendIdentityLogic.deterministicMemberID`: SHA-256 de
 *     `"SplitMemberBackend:<group_id>:<member_key>"`, sus 16 primeros bytes como UUID;
 *   - clave que no (`GroupBackendIdentityLogic.isLegacyMemberKey`) → el mismo cálculo con el namespace `"SplitMember"`.
 *
 * Y lo escribe con `uuidString`, en MAYÚSCULAS, y lo compara byte a byte. Medido en staging el 2026-11-15: las 57
 * referencias vivas de los grupos creados por la app resuelven así, y ninguna por la clave cruda.
 *
 * Yala web leía y escribía la clave cruda (barrido final de 2.3): la lista decía «Todo saldado» con una deuda, los
 * miembros salían «Sin nombre», un gasto hecho en la web dejaba cuatro personas en un grupo de dos y la app lo pintaba
 * «? pagó». Por eso la web traduce al leer (`memberRefResolver`) y escribe la forma de la app (`appMemberRef`).
 *
 * Paridad: `mcp/test/golden/groups-parity.json` (`memberRefs`), que `YalaTests/MCP/WebGroupsParityGoldenTests.swift`
 * verifica con las funciones de la app y `mcp/test/groups-parity.test.ts` con estas. La base aplica la misma regla en
 * `public.web_member_ref` (`webapp/supabase/web3_02_grupos_escritura.sql`).
 */

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** El nombre de quien borró su cuenta: nunca llega como clave, pero la app lo excluye igual de «legacy». */
const DELETED_USER = "__deleted_user__";

/** `GroupBackendIdentityLogic.isLegacyMemberKey`: ni vacía, ni el centinela, ni un UUID. */
export function isLegacyMemberKey(key: string): boolean {
  return key !== "" && key !== DELETED_USER && !UUID_RE.test(key);
}

function toUuidUpper(bytes: Uint8Array): string {
  const h = [...bytes.slice(0, 16)].map((x) => x.toString(16).padStart(2, "0")).join("").toUpperCase();
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}

/** El id con el que la app nombra a ese miembro en las filas del grupo (`SplitMember.id.uuidString`). */
export async function appMemberRef(groupId: string, memberKey: string): Promise<string> {
  const namespace = isLegacyMemberKey(memberKey) ? "SplitMember" : "SplitMemberBackend";
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${namespace}:${groupId}:${memberKey}`));
  return toUuidUpper(new Uint8Array(digest));
}

/**
 * De cualquier referencia de una fila a la `member_key` del miembro. Acepta la forma de la app y la clave cruda (la
 * escribían la web hasta el 2026-11-15 y los grupos de prueba de staging), sin distinguir mayúsculas. Una referencia que
 * no es de ningún miembro se devuelve tal cual: la página la enseña sin nombre, como antes.
 */
export async function memberRefResolver(groupId: string, memberKeys: readonly string[]): Promise<(ref: string) => string> {
  const byRef = new Map<string, string>();
  for (const key of memberKeys) {
    if (!key) continue;
    byRef.set((await appMemberRef(groupId, key)).toLowerCase(), key);
  }
  // La clave cruda va después: si coincidiera con una derivada (no puede: UUID v4 frente a un hash truncado), gana ella.
  for (const key of memberKeys) if (key) byRef.set(key.toLowerCase(), key);
  return (ref: string) => byRef.get(ref.toLowerCase()) ?? ref;
}
