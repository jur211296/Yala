/**
 * La entrada de Yala web (Apple, Google, el código QR, la página de la cámara y los avisos).
 *
 * Lote 6 la pintó con el fondo de la bienvenida de iOS, siempre oscura. Desde el 17-nov (Jürgen) sigue el tema de la
 * web —claro u oscuro según el sistema, o el elegido en Ajustes— con el estilo del resto de la app web, y lleva el logo
 * oficial en lugar del cuadrado con degradado.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const leer = (ruta: string) => readFileSync(new URL(ruta, import.meta.url), "utf8");
const styles = leer("../src/client/styles.css");
const app = leer("../src/client/App.tsx");
const qr = leer("../src/client/QrLogin.tsx");
const shell = leer("../src/client/app/Shell.tsx");

/** El bloque de la entrada en styles.css: desde su cabecera hasta el final. */
const entrada = styles.slice(styles.indexOf("La entrada: entrar"));

describe("la entrada sigue el tema de la web", () => {
  it("ya no lleva el fondo de la bienvenida de iOS", () => {
    expect(styles).not.toMatch(/#08081a|en-entrada|radial-gradient/i);
    expect(app).not.toMatch(/en-entrada|FONDO_ENTRADA/);
  });

  it("sus colores son los del tema, sin colores propios ni mirar al sistema", () => {
    expect(entrada).not.toMatch(/prefers-color-scheme|data-tema|color-scheme/);
    // Ningún color escrito a mano salvo el blanco del texto del botón fuerte y del cuadro del QR.
    const colores = [...entrada.matchAll(/#[0-9a-f]{3,8}\b|rgba?\(/gi)].map((m) => m[0].toLowerCase());
    expect(colores.every((c) => c === "#fff"), colores.join(" ")).toBe(true);
    for (const v of ["var(--card)", "var(--ink)", "var(--ink2)", "var(--fill)"]) expect(entrada).toContain(v);
  });

  it("la caja es una tarjeta de la app web y los botones son los redondos", () => {
    const caja = entrada.slice(entrada.indexOf(".e-caja {"), entrada.indexOf("}", entrada.indexOf(".e-caja {")));
    for (const d of ["background: var(--card);", "border: 1px solid var(--card-borde);", "border-radius: var(--radio-tarjeta);", "box-shadow: var(--sombra);"]) {
      expect(caja).toContain(d);
    }
    const btn = entrada.slice(entrada.indexOf(".e-btn {"), entrada.indexOf("}", entrada.indexOf(".e-btn {")));
    expect(btn).toContain("border-radius: 99px;");
    expect(btn).toContain("background: color-mix(in srgb, var(--ink2) 14%, transparent);");
    expect(btn).not.toMatch(/backdrop-filter/);
  });
});

describe("el logo oficial", () => {
  it("la entrada y la barra lateral usan el logo del tema, no el cuadrado con degradado", () => {
    expect(styles).not.toMatch(/linear-gradient\((?:140|135)deg, #6063f1, #ff0080\)/);
    for (const sel of [".e-logo {", ".brand i {"]) {
      const css = styles.slice(styles.indexOf(sel), styles.indexOf("}", styles.indexOf(sel)));
      expect(css, sel).toContain("background: var(--logo) center / contain no-repeat;");
      // Sin deformar: la proporción del PNG oficial recortado.
      expect(css, sel).toContain("aspect-ratio: 402 / 308;");
    }
    expect(app).toContain('<span className="e-logo" role="img" aria-label="Yala" />');
    expect(shell).toContain('<i role="img" aria-label="Yala" />');
  });

  it("el favicon es el ícono de la app", () => {
    const html = leer("../index.html");
    expect(html).toContain('<link rel="icon" href="/favicon-32.png"');
    expect(html).toContain('<link rel="apple-touch-icon" href="/apple-touch-icon.png" />');
    expect(html).not.toContain("favicon.svg");
  });
});

describe("los tres accesos", () => {
  it("llevan su ícono y el mismo diseño", () => {
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
  it("Turnstile se pide en el tema de la página", () => {
    expect(app).toMatch(/appearance: "interaction-only",[\s\S]{0,200}theme: temaEsOscuro\(\) \? "dark" : "light",/);
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
