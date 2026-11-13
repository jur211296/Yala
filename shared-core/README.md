# shared-core — el núcleo de lectura de Yala en TypeScript

Lo que leen y calculan los servidores de Yala a partir de las filas de la nube: saldos, divisas, presupuestos, resumen
de un periodo, Grupos, comercios y recurrentes, más el lector de PostgREST (`data.ts`) y la lista cerrada de salidas a
Supabase (`egress.ts`). Salió de `mcp/src/` el 2026-11-13 (lote 0 de Yala web) y lo usan tres Workers:

| Quién | Cómo lo importa |
|---|---|
| Conector de Claude (`mcp/`) | por los reexports de `mcp/src/` (mismas rutas de siempre) |
| Gateway (`gateway/src/ai/explore/`) | por esas mismas rutas de `mcp/src/` |
| Yala web (`webapp/`) | directo, `../../shared-core/src/…` |

**Sin dependencias, a propósito.** Se importa por ruta relativa y cada CI solo instala las dependencias de su propio
Worker. Ningún fichero de aquí puede importar un paquete: lo vigilan `mcp/test/shared-core-parity.test.ts` y
`gateway/test/ai.explore.test.ts`.

**Paridad.** `mcp/test/golden/shared-core-parity.json` es la foto de lo que pedían y devolvían las seis herramientas
ANTES del movimiento; el test exige lo mismo byte a byte. La paridad con la app (cifras que calcula Swift) sigue en
`mcp/test/golden.test.ts`. Cada cálculo nuevo se escribe dos veces —Swift y aquí— y se prueba contra los casos que
exportan los tests de Swift (decisión R1 de `docs/web-app/index.html`).

No tiene `package.json` ni suite propia: sus pruebas corren en el job `mcp` del CI.
