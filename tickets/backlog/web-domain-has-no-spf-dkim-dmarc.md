---
id: web-domain-has-no-spf-dkim-dmarc
status: backlog
priority: high
area: web, dns
created: 2026-09-05
updated: 2026-09-05
source: medición con dig a petición del owner (2026-09-03)
---

# El dominio no autentica su correo: cualquiera puede escribir como @yala-app.pe

## Qué pasa

`yala-app.pe` no publica **SPF, DKIM ni DMARC**. Dos consecuencias, y la primera es la que sube la
prioridad a `high` en una app de finanzas:

1. **Cualquiera puede falsificar el remitente.** Un correo que diga venir de `admin@yala-app.pe` llega
   a la bandeja de un usuario de Yala sin que nada lo desmienta. Munición directa de phishing contra
   nuestra propia gente.
2. **Nuestro correo legítimo va a spam.** Desde 2024 Gmail y Yahoo exigen autenticación al remitente.
   El correo de soporte que sale de `admin@` compite en desventaja.

No hay ningún flujo de producto roto —Yala no manda correo transaccional— así que no es `high` por
urgencia operativa, sino por exposición: el arreglo son ~20 minutos y el riesgo es suplantación.

## Lo MEDIDO (2026-09-03, `dig` contra el autoritativo `ns.rcp.net.pe`, flag `aa`)

| Registro | Estado |
|---|---|
| SPF (TXT raíz) | **No existe.** La raíz solo tiene `google-site-verification` y `apple-domain-verification` |
| DMARC (`_dmarc`) | **NXDOMAIN** — el nombre ni siquiera está creado |
| DKIM | **Nada.** Barrido de 20 selectores (`google`, `google1/2/3`, `default`, `selector1/2`, `s1/s2`, `k1/k2`…) en TXT y CNAME |
| MX | Google Workspace, 5 registros, correctos — **no tocar** |
| A raíz | `216.198.79.1` (Vercel) — **no tocar** |

Control positivo: el TXT de la raíz sí devuelve los dos `verification`, así que la ausencia de SPF es
real y no un filtro del lado de la medición.

**Remitentes.** El único remitente de `@yala-app.pe` es Google Workspace. MEDIDO en el repo: no hay
proveedor de envío, el gateway no manda correo, y `admin@yala-app.pe` aparece solo como `mailto:` en
la web (eso abre el cliente del visitante, no envía desde el dominio — no cuenta para SPF). Marketing
tampoco tiene herramienta de envío. CONFIRMADO además por el owner el 2026-09-03.

## Decidido por el owner (2026-09-03)

- Buzón de informes DMARC (`rua`): **`admin@yala-app.pe`**.
- Empezar en **`p=none`** (observación). No arrancar en `p=reject`.

## Los pasos (los teclea el owner — ambos paneles exigen autenticarse)

### 1 · Consola de Workspace — generar DKIM, sin activar

`admin.google.com` → **Aplicaciones → Google Workspace → Gmail → Autenticar correo** → dominio
`yala-app.pe` → generar con **2048 bits**. Copiar el host (`google._domainkey`) y el valor
(`v=DKIM1; k=rsa; p=…`). **No pulsar "Iniciar autenticación" todavía.**

### 2 · Panel DNS (punto.pe) — los tres TXT de una sentada

| Host | Valor |
|---|---|
| `google._domainkey` | el valor largo del paso 1 |
| `@` (o vacío) | `v=spf1 include:_spf.google.com ~all` |
| `_dmarc` | `v=DMARC1; p=none; rua=mailto:admin@yala-app.pe` |

### 3 · Volver a la consola y pulsar **"Iniciar autenticación"**

Sin este paso el registro está publicado y Google **sigue sin firmar**. Es el que se olvida.

### 4 · Verificar

```
dig +short TXT yala-app.pe @ns.rcp.net.pe
dig +short TXT _dmarc.yala-app.pe @ns.rcp.net.pe
dig +short TXT google._domainkey.yala-app.pe @ns.rcp.net.pe
```

### 5 · Correo de prueba

Desde `admin@yala-app.pe` (no desde un alias ni con "enviar como") a una cuenta externa. En Gmail:
**tres puntos → "Mostrar original"**. La cabecera `Authentication-Results` debe dar **SPF, DKIM y
DMARC en `pass`**.

## Trampas de esta zona

1. **AÑADIR el SPF, no reemplazar.** La raíz ya tiene dos TXT. Si el panel presenta el TXT de la raíz
   como campo único y se sobrescribe, se tumban la verificación de Google y la de Apple.
2. **Caché negativa de 2 h.** SOA `7200 300 604800 7200`: como `_dmarc` es NXDOMAIN hoy, los resolvers
   pueden seguir diciendo que no existe hasta 2 h después de crearlo. Por eso los `dig` del paso 4 van
   contra el autoritativo y no contra `8.8.8.8`.
3. **Si el panel rechaza el valor de DKIM por largo** (supera 255 caracteres y los paneles antiguos lo
   parten mal): regenerar con **1024 bits**. Un DKIM de 1024 que funciona vale más que uno de 2048 roto.
4. **El `rua` debe ser una dirección del propio dominio.** Con un buzón externo (un Gmail personal, por
   ejemplo) los informes NO llegan salvo que el dominio destino publique
   `yala-app.pe._report._dmarc.<dominio>`, cosa que Google no va a hacer. Es el error que deja DMARC
   puesto y mudo. Por eso `admin@yala-app.pe`.

## Después, no ahora

`p=none` es observación, no protección. En 1–2 semanas los informes en `admin@` dirán quién manda de
verdad como `@yala-app.pe`. Solo entonces se sube a `p=quarantine` y luego `p=reject`. Antes no.

## Fuera de alcance de este ticket, pero medido de paso

**`ns2.rcp.net.pe` (209.45.127.3) no respondía** el 2026-09-03: 3 de 3 timeouts, contra 3 de 3
respuestas de `ns.rcp.net.pe`. El dominio estaría corriendo sobre **un solo nameserver operativo** —
punto único de fallo para la web, el correo, las invitaciones y los universal links. INFERIDO que es
caída del servidor; MEDIDO solo desde el Mac del owner, así que podría ser una ruta bloqueada hacia esa
IP y no una caída global. Es infraestructura de la RCP, no nuestra: hay que reportárselo a ellos.
