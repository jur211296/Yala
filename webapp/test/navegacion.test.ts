/**
 * Lote 3 de «Yala web como la app»: la navegación. Qué abre cada dirección y qué se marca en la barra lateral y en las
 * pestañas del celular. El recorrido en navegador (teclado, ⌘K, 390 px) es
 * `docs/web-app/parecida-a-la-app/herramientas/recorrido-navegacion.mjs`.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { FULL_CLOUD, SECTIONS, pathOf, secFromPath, segmentOf, shortcutLabel, sideOf, tabOf, type Sec } from "../src/client/app/navegacion";

describe("las direcciones de antes siguen funcionando", () => {
  it.each([
    ["/", "panel"],
    ["/registros", "registros"],
    ["/registros/", "registros"],
    ["/bandeja", "bandeja"],
    ["/presupuestos", "presupuestos"],
    ["/pagos", "pagos"],
    ["/estadisticas", "estadisticas"],
    ["/grupos", "grupos"],
    ["/configurar", "configurar"],
    ["/mas", "mas"],
    ["/planificacion", "planificacion"],
    ["/no-existe", "panel"],
  ] as const)("%s abre %s", (url, sec) => {
    expect(secFromPath(url, "panel")).toBe(sec);
  });

  it("una cuenta «solo Grupos» abre en Grupos", () => {
    expect(secFromPath("/", "grupos")).toBe("grupos");
    expect(pathOf("grupos", "grupos")).toBe("/");
  });

  it("cada sección vuelve a su propia dirección", () => {
    for (const s of SECTIONS) expect(secFromPath(pathOf(s, "panel"), "panel")).toBe(s);
  });
});

describe("Planificación reúne Presupuestos y Pagos planificados", () => {
  it("/presupuestos y /planificacion abren Presupuestos; /pagos, Pagos", () => {
    expect(segmentOf("presupuestos")).toBe("presupuestos");
    expect(segmentOf("planificacion")).toBe("presupuestos");
    expect(segmentOf("pagos")).toBe("pagos");
  });

  it("las tres marcan Planificación en la barra lateral", () => {
    for (const s of ["planificacion", "presupuestos", "pagos"] as Sec[]) expect(sideOf(s)).toBe("planificacion");
    expect(sideOf("registros")).toBe("registros");
  });

  it("es de la nube completa: una cuenta «solo Grupos» no la ve", () => {
    for (const s of ["planificacion", "presupuestos", "pagos"] as Sec[]) expect(FULL_CLOUD).toContain(s);
  });
});

describe("las pestañas del celular, como la app", () => {
  it("Panel, Registros y Grupos marcan la suya; la Bandeja ninguna; el resto, Más", () => {
    expect(tabOf("panel", false)).toBe("panel");
    expect(tabOf("registros", false)).toBe("registros");
    expect(tabOf("grupos", false)).toBe("grupos");
    expect(tabOf("bandeja", false)).toBeNull();
    for (const s of ["planificacion", "presupuestos", "pagos", "estadisticas", "configurar", "mas"] as Sec[]) expect(tabOf(s, false)).toBe("mas");
  });

  it("una cuenta «solo Grupos» tiene Grupos y Configurar", () => {
    expect(tabOf("grupos", true)).toBe("grupos");
    expect(tabOf("configurar", true)).toBe("configurar");
    expect(tabOf("panel", true)).toBeNull();
  });
});

describe("el atajo de la búsqueda", () => {
  it("se escribe ⌘K en Apple y Ctrl K en el resto", () => {
    expect(shortcutLabel("MacIntel")).toBe("⌘K");
    expect(shortcutLabel("iPhone")).toBe("⌘K");
    expect(shortcutLabel("Win32")).toBe("Ctrl K");
    expect(shortcutLabel("Linux x86_64")).toBe("Ctrl K");
  });
});

describe("/planificacion la sirve el Worker sin configuración nueva", () => {
  it("staging y producción devuelven la página para cualquier dirección que no es /api ni /auth", () => {
    const toml = readFileSync(new URL("../wrangler.toml", import.meta.url), "utf8");
    const blocks = [...toml.matchAll(/\[(?:env\.production\.)?assets\]([\s\S]*?)(?=\n\[)/g)].map((m) => m[1]!);
    expect(blocks).toHaveLength(2);
    for (const b of blocks) expect(b).toMatch(/not_found_handling\s*=\s*"single-page-application"/);
  });
});
