/**
 * La dirección de reenvío que DESPLIEGA cada entorno (decisión de Jürgen del 2026-11-10: dominio aparte, solo para
 * recibir). Los tests de `mail.test.ts` prueban el parser con la configuración por defecto; aquí se fija el VALOR de
 * `wrangler.toml`, que es lo que entregaría un deploy: `auto-staging+<código>@yalainbox.com` en staging y
 * `auto+<código>@yalainbox.com` en producción. Moverlo es un diff que rompe un test, no un deploy silencioso.
 *
 * Scan manual del TOML, como `config.test.ts` y `wrangler.forceupdate.test.ts` (sin dependencia nueva), con su propio
 * control positivo: un scanner roto devolvería `undefined` y caería en el valor por defecto sin que nadie lo viera.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { codeFromRecipient, formatAddress, mailConfig } from "../src/mail/address";

const TOML = readFileSync(new URL("../wrangler.toml", import.meta.url), "utf8");

function varIn(header: string, key: string): string | undefined {
  let dentro = false;
  for (const linea of TOML.split("\n")) {
    const t = linea.trim();
    if (t.startsWith("[")) {
      dentro = t === `[${header}]`;
      continue;
    }
    if (!dentro || t.startsWith("#")) continue;
    const m = t.match(new RegExp(`^${key}\\s*=\\s*"([^"]*)"`));
    if (m) return m[1];
  }
  return undefined;
}

function vars(header: string) {
  return { MAIL_ADDRESS_LOCAL: varIn(header, "MAIL_ADDRESS_LOCAL"), MAIL_ADDRESS_DOMAIN: varIn(header, "MAIL_ADDRESS_DOMAIN") };
}

const CODE = "abcdefghjk";

describe("wrangler.toml · la dirección del correo del banco por entorno", () => {
  it("control positivo: el scanner lee una variable conocida de cada sección", () => {
    expect(varIn("vars", "ENVIRONMENT")).toBe("staging");
    expect(varIn("env.production.vars", "ENVIRONMENT")).toBe("production");
  });

  it("staging entrega auto-staging+<código>@yalainbox.com", () => {
    expect(vars("vars")).toEqual({ MAIL_ADDRESS_LOCAL: "auto-staging", MAIL_ADDRESS_DOMAIN: "yalainbox.com" });
    const cfg = mailConfig(vars("vars"));
    expect(formatAddress(CODE, cfg)).toBe("auto-staging+abcdefghjk@yalainbox.com");
    expect(codeFromRecipient("auto-staging+abcdefghjk@yalainbox.com", cfg)).toBe(CODE);
    expect(codeFromRecipient("auto+abcdefghjk@yalainbox.com", cfg)).toBeNull();
  });

  it("producción entrega auto+<código>@yalainbox.com", () => {
    expect(vars("env.production.vars")).toEqual({ MAIL_ADDRESS_LOCAL: "auto", MAIL_ADDRESS_DOMAIN: "yalainbox.com" });
    const cfg = mailConfig(vars("env.production.vars"));
    expect(formatAddress(CODE, cfg)).toBe("auto+abcdefghjk@yalainbox.com");
    expect(codeFromRecipient("auto+abcdefghjk@yalainbox.com", cfg)).toBe(CODE);
    expect(codeFromRecipient("auto-staging+abcdefghjk@yalainbox.com", cfg)).toBeNull();
  });

  it("el dominio viejo ya no es nuestro, ni en un entorno ni sin configurar", () => {
    for (const cfg of [mailConfig(vars("vars")), mailConfig(vars("env.production.vars")), mailConfig({})]) {
      expect(codeFromRecipient(`${cfg.local}+abcdefghjk@yala-app.pe`, cfg)).toBeNull();
    }
  });

  it("sin variables, el valor por defecto es auto@yalainbox.com", () => {
    expect(mailConfig({})).toEqual({ local: "auto", domain: "yalainbox.com" });
  });
});
