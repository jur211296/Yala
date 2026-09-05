---
name: dns-yala-app-pe
description: Dónde se administra el DNS de yala-app.pe, quién puede entrar, y el estado de autenticación de correo medido el 2026-09-03
metadata:
  type: reference
---

# DNS de yala-app.pe — dónde se toca y quién puede

**Registrador:** NIC.PE / punto.pe. **Zona autoritativa:** servidores de la RCP
(`ns.rcp.net.pe` 161.132.17.10, `ns2.rcp.net.pe` 209.45.127.3).
**Correo:** Google Workspace (MX a ASPMX.L.GOOGLE.COM + ALT1-4). **Web:** Vercel (A 216.198.79.1).

**No hay nada en el repo sobre esto** — ni ticket, ni doc, ni ADR (comprobado 2026-09-03).
Este fichero es el único puntero.

## Lo que yo no puedo hacer aquí

Los dos paneles (consola de Workspace y panel DNS del registrador) exigen autenticarse, y yo no
introduzco credenciales ni entro en cuentas. **Los cambios de DNS y de Workspace los teclea
Jürgen**; lo mío es medir con `dig`, dar los valores exactos y verificar después.

## Estado medido el 2026-09-03 (CADUCA — re-medir con dig antes de citarlo)

Sin SPF, sin DMARC (`_dmarc` daba NXDOMAIN), sin DKIM en ninguno de 20 selectores probados.
El único remitente de `@yala-app.pe` es Google Workspace — confirmado por Jürgen y coherente con
el repo: no hay proveedor de envío, el gateway no manda correo, y `admin@yala-app.pe` solo aparece
como `mailto:` en la web (eso envía desde el cliente del visitante, no desde el dominio).
Buzón elegido para los informes DMARC: `admin@yala-app.pe`.

## Dos trampas de esta zona en concreto

1. **`ns2.rcp.net.pe` no respondía** (3/3 timeouts contra 3/3 respuestas de `ns.`) el 2026-09-03:
   el dominio corría sobre un solo NS operativo. Medido desde el Mac de Jürgen, así que podría ser
   ruta bloqueada y no caída global. Es de RCP, no nuestro. Si algo de red se comporta raro a nivel
   dominio —web, correo, invitaciones, universal links— mira esto antes que el código.
2. **Caché negativa de 2 h.** SOA `7200 300 604800 7200`: un nombre que hoy es NXDOMAIN sigue
   siéndolo para los resolvers hasta 2 h después de crearlo. Verificar contra el autoritativo
   (`dig ... @ns.rcp.net.pe`) para saltarse la espera, y usar el serial del SOA para confirmar que
   el cambio entró.

Ver también [[decisiones-que-esperan-a-jurgen]].
