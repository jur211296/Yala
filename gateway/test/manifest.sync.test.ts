/**
 * La copia del manifest que usa el gateway coincide con la SSOT de la raíz del repo. OFFLINE.
 *
 * Por qué existe. Los dos `*_capability_manifest.json` de `gateway/` son COPIAS generadas
 * (`npm run sync:manifest`) y están en `.gitignore`; la SSOT vive en la raíz del repo. La copia se
 * refresca en `pretest` / `pretypecheck` / `predeploy:*`, así que `npm test` siempre mide con la copia
 * fresca — pero `npx vitest`, que es como se lanzan los goldens de red cuando se quiere filtrar por
 * nombre, NO dispara `pretest`. Con la copia vieja el gateway calcula el Merkle con el contrato de
 * columnas anterior y los goldens miden algo que no existe en ningún entorno real.
 *
 * No es hipotético: el 2026-09-07 el manifest de Grupos subió a `c2` (`bb90564a`, la columna
 * `budget_limit_amount` del tope de gasto) y la copia del gateway se quedó en `c1` durante un día,
 * porque nadie corrió `npm test`. Quien investigó los goldens en rojo gastó una hipótesis entera en
 * eso antes de dar con el desajuste. Este test lo convierte en un fallo con nombre, en la primera
 * línea del reporte y sin red.
 *
 * Falla ⇒ `npm run sync:manifest`.
 */
import { describe, expect, it } from "vitest";
// Import de JSON (resolveJsonModule), igual que `src/groups/manifest.ts` — NO `node:fs` + `import.meta.url`:
// el tsconfig del Worker no trae `@types/node` y ese par ya deja 2 errores de typecheck en
// `wrangler.forceupdate.test.ts`. Ver `gateway-typecheck-en-rojo-desde-hace-tiempo`.
// `../<name>` = la copia que compila el gateway; `../../<name>` = la SSOT en la raíz del repo.
import copiaPersonal from "../capability_manifest.json";
import ssotPersonal from "../../capability_manifest.json";
import copiaGrupos from "../group_capability_manifest.json";
import ssotGrupos from "../../group_capability_manifest.json";

const PARES = [
  { name: "capability_manifest.json", copia: copiaPersonal, ssot: ssotPersonal },
  { name: "group_capability_manifest.json", copia: copiaGrupos, ssot: ssotGrupos },
] as const;

describe("manifest: la copia del gateway está sincronizada con la SSOT de la raíz", () => {
  for (const { name, copia, ssot } of PARES) {
    it(`${name} coincide con el de la raíz del repo`, () => {
      // El canon va aparte para que el reporte diga QUÉ divergió: un diff de 40 KB no le sirve a nadie,
      // y el canon es el campo cuyo desajuste envenena el Merkle en silencio.
      const canon = (m: unknown) => (m as { canon_version?: string }).canon_version;
      expect(canon(copia), `canon_version distinto — corre 'npm run sync:manifest'`).toBe(canon(ssot));
      expect(copia, `${name} difiere de la raíz — corre 'npm run sync:manifest'`).toEqual(ssot);
    });
  }
});
