---
name: dns-yala-app-pe
description: Dónde se administra el DNS de yala-app.pe, quién puede entrar, y el estado del correo: autentica desde el 2026-09-08 (los tres en pass); queda subir la política DMARC, con ticket propio
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

## Estado el 2026-09-08 DESPUÉS de publicar (CADUCA — re-medir con dig antes de citarlo)

Sin SPF, sin DMARC (`_dmarc` daba NXDOMAIN), sin DKIM en ninguno de 20 selectores probados.
El único remitente de `@yala-app.pe` es Google Workspace — confirmado por Jürgen y coherente con
el repo: no hay proveedor de envío, el gateway no manda correo, y `admin@yala-app.pe` solo aparece
como `mailto:` en la web (eso envía desde el cliente del visitante, no desde el dominio).
Buzón elegido para los informes DMARC: `admin@yala-app.pe`.

**El serial del SOA es el testigo barato de si un cambio entró**: hoy `2026071400` (14 de julio, la
zona no se toca desde entonces). Si tras pegar en el panel el serial no ha cambiado, el panel no
guardó — y eso se confunde con «aún no ha propagado», que es una espera inútil de dos horas.

**El correo de `yala-app.pe` autentica desde el 2026-09-08.** Jürgen pegó los tres (serial
`2026071400` → `2026090802`) y el correo de comprobación dio `dkim=pass spf=pass dmarc=pass`. Ticket
cerrado en `tickets/done/`; el seguimiento —subir `p=none` a `quarantine` y luego `reject`— vive en
`tickets/backlog/dmarc-sube-la-politica-tras-observar.md`, **no antes del 15-sep**, porque los `rua`
llegan una vez al día y hacen falta varios.

**Lo que hay que leer en esa cabecera no son los tres `pass`.** Son otras tres cosas, y ninguna se
ve de un vistazo:

1. **Con qué selector firmó.** `DKIM-Signature: d=yala-app.pe; s=google` es *nuestra* clave; la firma
   de Google va aparte con `d=1e100.net`. Solo eso demuestra que «Iniciar autenticación» surtió
   efecto — el registro puede estar perfecto y Google no firmar todavía, y **ningún `dig` distingue
   esos dos mundos**.
2. **Si el alineamiento es estricto.** `header.from`, el `d=` de la firma y `smtp.mailfrom` han de ser
   el mismo dominio. DMARC pasa con SPF **o** DKIM alineado, así que un `dmarc=pass` puede estar
   sostenido por uno solo; si los dos alinean, no depende de ninguno.
3. **Por qué mecanismo pasó el SPF.** La IP remitente tiene que caer en un rango de
   `_spf.google.com`, no en un `all` laxo.

**Lo que hay que verificar en un DKIM, y no es que exista.** Vino **partido en dos cadenas** porque
2048 bits pasan de los 255 caracteres por cadena, y ahí es donde un panel lo rompe sin avisar. La
comprobación que distingue «publicado» de «además sirve» es reconstruir la clave y parsearla:

    dig +short TXT google._domainkey.yala-app.pe @ns.rcp.net.pe | tr -d '" ' | tr -d '\n' \
      | sed 's/.*p=//' | fold -w 64 \
      | (echo "-----BEGIN PUBLIC KEY-----"; cat; echo; echo "-----END PUBLIC KEY-----") \
      | openssl pkey -pubin -noout -text | head -1     # -> RSA Public-Key: (2048 bit)

**Ese `echo` suelto es el comando entero.** `tr -d '\n'` deja el base64 sin salto final, así que sin
él `-----END-----` se pega a la clave y `openssl` responde `unable to load Public Key` sobre un DKIM
**correcto**. Lo escribí sin el `echo`, lo corrí, y por poco documento un falso rojo — la única razón
por la que no salió es que no entrego un comando sin ejecutarlo.

**Y su control negativo dice qué comprueba de verdad:** caza el truncado, los caracteres perdidos en
medio y **las dos cadenas en orden invertido** (los tres modos en que un panel rompe una clave
larga), pero **no** caza basura pegada al final — el DER lleva su longitud y los bytes de más se
ignoran. Un `openssl` contento prueba que la clave se reconstruye, no que el registro sea idéntico
al que dio Google.

Y dos comprobaciones más que el `dig` a secas no da: que haya **un solo** `v=spf1` (dos son
`PermError` y tumban el SPF entero) y que los `verification` que ya estaban **sigan ahí**.

## Dos trampas de esta zona en concreto

1. ~~`ns2.rcp.net.pe` no respondía~~ — **CORREGIDO el 2026-09-08: sí responde.** 6/6 autoritativas,
   2 ms, con el mismo serial que `ns.` (zona sincronizada) y delegación coherente en el TLD. Lo del
   2026-09-03 (3/3 timeouts) fue transitorio o una ruta, y ya da igual cuál: **no hay punto único de
   fallo y no hay nada que reportarle a la RCP.** Lo dejo escrito porque el dato viejo estaba en el
   ticket y en esta ficha, y era de los que se citan sin volver a medir.
2. **Caché negativa de 2 h.** SOA `7200 300 604800 7200`: un nombre que hoy es NXDOMAIN sigue
   siéndolo para los resolvers hasta 2 h después de crearlo. Verificar contra el autoritativo
   (`dig ... @ns.rcp.net.pe`) para saltarse la espera, y usar el serial del SOA para confirmar que
   el cambio entró.

Ver también [[decisiones-que-esperan-a-jurgen]].
