/**
 * Lote 6 de «Yala web como la app»: la entrada (Apple, Google, el código QR, la página de la cámara y los avisos) sobre
 * el fondo de la bienvenida de la app.
 *
 * Las medidas no se copian a mano: se leen del Swift de la app (`WelcomeF2Background` y `WelcomeAccessButton` en
 * `WelcomeShowcaseView.swift`), así que si la bienvenida cambia, esta prueba lo dice.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const leer = (ruta: string) => readFileSync(new URL(ruta, import.meta.url), "utf8");
const styles = leer("../src/client/styles.css");
const app = leer("../src/client/App.tsx");
const qr = leer("../src/client/QrLogin.tsx");
const swift = leer("../../Yala/App/Views/Onboarding/WelcomeShowcaseView.swift");
const form = leer("../../Yala/App/Views/Onboarding/WelcomeForm.swift");
const tokens = leer("../../Yala/App/Theme/DesignTokens.swift");

/** El bloque de la entrada en styles.css: desde su cabecera hasta el final. */
const entrada = styles.slice(styles.indexOf("La entrada (lote 6)"));

/** Un número con sus ceros de sobra quitados (0.10 → «0.1»), como lo escribe el CSS. */
const n = (s: string) => String(Number(s));

describe("el fondo es el de la bienvenida de la app", () => {
  const f2 = swift.slice(swift.indexOf("struct WelcomeF2Background"));

  it("la base", () => {
    const m = f2.match(/Color\(red: (\d+) \/ 255, green: (\d+) \/ 255, blue: (\d+) \/ 255\)/);
    expect(m).not.toBeNull();
    const hex = "#" + [m![1], m![2], m![3]].map((v) => Number(v).toString(16).padStart(2, "0")).join("");
    expect(entrada).toContain(`${hex};\n}`); // el último color del `background` de `.entrada`
    expect(entrada).toMatch(new RegExp(`html\\.en-entrada body \\{\\s*background: ${hex};`));
  });

  it("el brillo índigo: opacidad, centro y radio", () => {
    const m = f2.match(/electricIndigo\.opacity\(([\d.]+)\)[\s\S]*?center: UnitPoint\(x: ([\d.]+), y: ([\d.]+)\)[\s\S]*?height\) \* ([\d.]+)/);
    expect(m).not.toBeNull();
    const [, op, x, y, r] = m!;
    expect(entrada).toContain(
      `radial-gradient(circle ${Math.round(Number(r) * 100)}vmax at ${Math.round(Number(x) * 100)}% ${Math.round(Number(y) * 100)}%, rgba(96, 99, 241, ${n(op!)}), rgba(96, 99, 241, 0) 100%)`,
    );
  });

  it("el toque turquesa: opacidad, centro y radio", () => {
    const m = f2.match(/neonCyan\.opacity\(([\d.]+)\)[\s\S]*?center: UnitPoint\(x: ([\d.]+), y: ([\d.]+)\)[\s\S]*?width \* ([\d.]+)/);
    expect(m).not.toBeNull();
    const [, op, x, y, r] = m!;
    expect(entrada).toContain(
      `radial-gradient(circle ${Math.round(Number(r) * 100)}vw at ${Math.round(Number(x) * 100)}% ${Math.round(Number(y) * 100)}%, rgba(0, 243, 255, ${n(op!)}), rgba(0, 243, 255, 0) 100%)`,
    );
  });

  it("es siempre oscura: no lee las variables del tema ni mira al sistema", () => {
    for (const v of entrada.matchAll(/var\((--[a-z0-9-]+)\)/g)) {
      expect(v[1] === "--letra" || v[1]!.startsWith("--e-"), v[1]).toBe(true);
    }
    expect(entrada).not.toMatch(/prefers-color-scheme|data-tema/);
    expect(entrada).toMatch(/\.entrada \{[^}]*color-scheme: dark;/);
  });
});

describe("los botones son los de la bienvenida", () => {
  const boton = swift.slice(swift.indexOf("struct WelcomeAccessButton"));
  const css = entrada.slice(entrada.indexOf(".e-btn {"), entrada.indexOf("}", entrada.indexOf(".e-btn {")));

  it("cristal y borde", () => {
    const fill = boton.match(/static let fill = Color\.white\.opacity\(([\d.]+)\)/)![1]!;
    const stroke = boton.match(/static let stroke = Color\.white\.opacity\(([\d.]+)\)/)![1]!;
    expect(entrada).toContain(`--e-cristal: rgba(255, 255, 255, ${n(fill)});`);
    expect(entrada).toContain(`--e-borde: rgba(255, 255, 255, ${n(stroke)});`);
    expect(css).toContain("background: var(--e-cristal);");
    expect(css).toContain("border: 1px solid var(--e-borde);");
  });

  it("alto, radio, letra e ícono", () => {
    const alto = form.match(/static let buttonHeight: CGFloat = (\d+)/)![1]!;
    expect(boton).toContain("cornerRadius: DS.Radius.lg");
    const radios = tokens.slice(tokens.indexOf("enum Radius"));
    const lg = radios.match(/static let lg: CGFloat = (\d+)/)![1]!;
    const letra = boton.match(/static let font = Font\.system\(size: (\d+), weight: \.semibold\)/)![1]!;
    const icono = boton.match(/static let iconSlot: CGFloat = (\d+)/)![1]!;
    expect(css).toContain(`min-height: ${alto}px;`);
    expect(css).toContain(`border-radius: ${lg}px;`);
    expect(css).toContain(`font: 600 ${letra}px/1.2`);
    expect(entrada).toMatch(new RegExp(`\\.e-ico \\{\\s*width: ${icono}px;\\s*height: ${icono}px;`));
  });

  it("los tres accesos llevan su ícono y el mismo diseño", () => {
    const form = app.slice(app.indexOf('<form method="post" action="/auth/start"'), app.indexOf("</form>"));
    expect(form.match(/className="e-btn"/g)).toHaveLength(3);
    expect(form).toContain("<LogoApple />");
    expect(form).toContain("<LogoGoogle />");
    expect(form).toContain("<Smartphone");
    // La «G» de Google va en sus colores: la guía de marca no deja recolorearla.
    const g = app.slice(app.indexOf("function LogoGoogle"), app.indexOf("function SsoLogin"));
    for (const c of ["#FFC107", "#FF3D00", "#4CAF50", "#1976D2"]) expect(g).toContain(c);
  });
});

describe("la entrada no se mezcla con la app con sesión", () => {
  it("Turnstile se pide en oscuro, como el fondo", () => {
    expect(app).toMatch(/appearance: "interaction-only",[\s\S]{0,200}theme: "dark",/);
  });

  it("la entrada y el QR solo usan las clases de la entrada", () => {
    for (const src of [app, qr]) {
      for (const m of src.matchAll(/className="([^"]+)"/g)) {
        for (const c of m[1]!.split(/\s+/)) expect(["entrada", "ok", "fuerte"].includes(c) || c.startsWith("e-"), c).toBe(true);
      }
    }
  });

  it("lo que usa la app con sesión sigue en styles.css", () => {
    for (const sel of [".brand {", ".brand i {", ".fade {", "h1 {"]) expect(styles).toContain(sel);
  });

  it("las clases de la entrada vieja ya no están", () => {
    for (const sel of [".shell {", ".card {", ".btn {", ".login {", ".qr-login", ".qr-code {"]) expect(styles).not.toContain(sel);
  });
});
