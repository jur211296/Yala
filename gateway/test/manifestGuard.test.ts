import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
// @ts-expect-error — módulo .mjs sin tipos: es el script del `predeploy`.
import { decideManifestGuard } from "../scripts/manifest-guard.mjs";
import { GROUP_MANIFEST_VERSION } from "../src/groups/manifest";
import { MANIFEST_VERSION } from "../src/sync/manifest";

/**
 * Guard de despliegue (card u8cl, pieza 3): no deja desplegar un Worker con el manifest PERSONAL o el de GRUPOS más viejo
 * que el desplegado. Hasta el 2026-10-28 solo miraba el personal.
 */
describe("check-manifest-not-older — los dos manifests", () => {
  const config = (personal?: number, groups?: number) => ({
    sync: { ...(personal !== undefined && { manifestVersion: personal }), ...(groups !== undefined && { groupsManifestVersion: groups }) },
  });

  it("el manifest de Grupos más viejo que el desplegado para el despliegue", () => {
    const d = decideManifestGuard({ localPersonal: 4, localGroups: 2, config: config(4, 3) });
    expect(d.ok).toBe(false);
    expect(d.downgrades).toEqual([{ channel: "grupos", deployed: 3, local: 2 }]);
  });

  it("el personal más viejo sigue parando, como antes", () => {
    const d = decideManifestGuard({ localPersonal: 3, localGroups: 2, config: config(4, 2) });
    expect(d.ok).toBe(false);
    expect(d.downgrades.map((x: { channel: string }) => x.channel)).toEqual(["personal"]);
  });

  it("iguales o más nuevos: se despliega", () => {
    expect(decideManifestGuard({ localPersonal: 4, localGroups: 2, config: config(4, 2) }).ok).toBe(true);
    expect(decideManifestGuard({ localPersonal: 5, localGroups: 3, config: config(4, 2) }).ok).toBe(true);
  });

  it("un Worker que aún no publica la versión de Grupos vale 2 (todos conocían el presupuesto)", () => {
    const d = decideManifestGuard({ localPersonal: 4, localGroups: 2, config: config(4) });
    expect(d.ok).toBe(true);
    expect(d.deployed.groups).toBe(2);
    // Un árbol con Grupos en v1 contra un Worker sin publicar sí para: el desplegado ya hablaba v2.
    expect(decideManifestGuard({ localPersonal: 4, localGroups: 1, config: config(4) }).ok).toBe(false);
  });

  it("un Worker que no publica nada vale personal 1 (comportamiento de antes)", () => {
    expect(decideManifestGuard({ localPersonal: 1, localGroups: 2, config: {} }).deployed.personal).toBe(1);
  });

  it("/config publica las dos versiones de ESTE Worker", async () => {
    const { default: app } = await import("../src/index");
    const res = await app.request("/config", { method: "GET" }, {});
    const body = (await res.json()) as { sync: { manifestVersion: number; groupsManifestVersion: number } };
    expect(body.sync.manifestVersion).toBe(MANIFEST_VERSION);
    expect(body.sync.groupsManifestVersion).toBe(GROUP_MANIFEST_VERSION);
  });

  it("el script lee el manifest de Grupos y decide con la función probada", () => {
    const script = readFileSync(new URL("../scripts/check-manifest-not-older.mjs", import.meta.url), "utf8");
    expect(script).toContain('readVersion("group_capability_manifest.json")');
    expect(script).toContain("decideManifestGuard({ localPersonal, localGroups, config })");
  });
});
