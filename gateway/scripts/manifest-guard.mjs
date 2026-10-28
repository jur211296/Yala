// manifest-guard.mjs — la decisión de `check-manifest-not-older.mjs`, sin red ni ficheros, para poder probarla
// (`gateway/test/manifestGuard.test.ts`).
//
// Dos manifests, cada uno con su versión: el del canal personal (`capability_manifest.json`) y, desde la card u8cl
// (2026-10-28), el de Grupos (`group_capability_manifest.json`). Un Worker con cualquiera de los dos más viejo que el
// desplegado rechaza filas de los teléfonos que ya hablan la versión nueva, así que el guard para con cualquiera.
//
// Lo desplegado AUSENTE vale lo que vale un Worker anterior a la publicación de esa versión en `/config`:
//   - personal: 1 (un Worker anterior a `manifest_version` no anunciaba nada);
//   - Grupos: 2, `GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER` del gateway: todo Worker desplegado antes de que `/config`
//     publicara la versión de Grupos ya conocía `split_groups.budget_limit_amount` (g14_01, v2).

export const DEPLOYED_PERSONAL_WHEN_ABSENT = 1;
export const DEPLOYED_GROUPS_WHEN_ABSENT = 2;

/**
 * @param {{ localPersonal: number, localGroups: number, config: any }} input  `config` = cuerpo de `GET /config`.
 * @returns {{ ok: boolean, downgrades: { channel: string, deployed: number, local: number }[],
 *             deployed: { personal: number, groups: number } }}
 */
export function decideManifestGuard({ localPersonal, localGroups, config }) {
  const deployed = {
    personal: config?.sync?.manifestVersion ?? DEPLOYED_PERSONAL_WHEN_ABSENT,
    groups: config?.sync?.groupsManifestVersion ?? DEPLOYED_GROUPS_WHEN_ABSENT,
  };
  const downgrades = [];
  if (localPersonal < deployed.personal) {
    downgrades.push({ channel: "personal", deployed: deployed.personal, local: localPersonal });
  }
  if (localGroups < deployed.groups) {
    downgrades.push({ channel: "grupos", deployed: deployed.groups, local: localGroups });
  }
  return { ok: downgrades.length === 0, downgrades, deployed };
}
