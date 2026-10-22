---
id: web-domain-has-no-spf-dkim-dmarc
status: done
priority: high
area: web, dns
created: 2026-09-05
updated: 2026-09-08
source: medición con dig a petición del owner (2026-09-03)
---

# El dominio no autentica su correo: cualquiera puede escribir como @yala-app.pe

## Cerrado el 2026-09-08 · los tres autentican

**Jürgen pegó los tres registros y entran correctamente.** Verificado contra el autoritativo
(`dig @ns.rcp.net.pe`) en el árbol de la sesión, no leído de una pantalla:

| Comprobación | Resultado |
|---|---|
| Serial de la zona | `2026071400` → **`2026090802`** — el panel guardó de verdad |
| SPF | **1** registro `v=spf1 include:_spf.google.com ~all` (más de uno sería `PermError`) |
| Los dos `verification` | **2 de 2** siguen en la raíz — la trampa 1 no mordió |
| DMARC | `v=DMARC1; p=none; rua=mailto:admin@yala-app.pe` |
| DKIM | 2 cadenas que **concatenan a una clave RSA de 2048 bits válida** (`openssl pkey` la parsea) |
| Nombre duplicado | vacío en `google._domainkey.…yala-app.pe.yala-app.pe` **y** en `_dmarc.…` |
| MX y A | intactos: 5 registros de Google, `216.198.79.1` |

El DKIM llegó **partido en dos cadenas** —el valor de 2048 bits pasa de 255 caracteres— y el panel
las partió bien. Eso es la diferencia entre un registro publicado y uno que además sirve, y se
comprueba reconstruyendo la clave:

```bash
dig +short TXT google._domainkey.yala-app.pe @ns.rcp.net.pe \
  | tr -d '" ' | tr -d '\n' | sed 's/.*p=//' | fold -w 64 \
  | (echo "-----BEGIN PUBLIC KEY-----"; cat; echo; echo "-----END PUBLIC KEY-----") \
  | openssl pkey -pubin -noout -text | head -1     # -> RSA Public-Key: (2048 bit)
```

**El `echo` suelto del tercer renglón no es adorno**: `tr -d '\n'` deja el base64 sin salto final, así
que sin él `-----END-----` se pega a la clave y `openssl` dice `unable to load Public Key` sobre una
clave que está perfecta. Costó un falso rojo al escribir esto.

**Qué caza y qué no** (medido con controles negativos, 2026-09-08): caza el valor truncado, los
caracteres perdidos en medio y **las dos cadenas en orden invertido** —los tres modos en que un panel
rompe un DKIM largo—. **No** caza basura pegada al final, porque el DER lleva su propia longitud y
los bytes de más se ignoran. Un `openssl` contento no es prueba de que el registro sea idéntico al
que dio Google; es prueba de que la clave se reconstruye.

### El correo confirma que Google firma (2026-09-08, 07:23 Lima)

Correo real de `admin@yala-app.pe` a una cuenta externa. `Authentication-Results` de
`mx.google.com`:

    dkim=pass  header.i=@yala-app.pe  header.s=google
    spf=pass   smtp.mailfrom=admin@yala-app.pe
    dmarc=pass (p=NONE sp=NONE dis=NONE)  header.from=yala-app.pe

Tres cosas de esa cabecera que importan más que los tres `pass`:

1. **Firmó con NUESTRO selector.** `DKIM-Signature: d=yala-app.pe; s=google` — es la clave que
   publicamos, no una firma genérica de Google (esa va aparte, con `d=1e100.net`). Esto es lo que
   demuestra que el paso 3 surtió efecto; era la única pregunta que ningún `dig` podía contestar.
2. **El alineamiento es estricto.** `header.from`, el `d=` de la firma y `smtp.mailfrom` son el mismo
   dominio. DMARC pasa si SPF **o** DKIM pasan *alineados*; aquí pasan los dos, así que el resultado
   no depende de ninguno en solitario.
3. **La IP remitente cae dentro del SPF por la vía correcta.** `209.85.220.41` ∈ `209.85.128.0/17`,
   que viene de `_spf.google.com` — no es un `pass` por un mecanismo laxo.

**Queda un seguimiento, y tiene ticket propio**: `dmarc-sube-la-politica-tras-observar`. `p=none`
observa pero no protege, y subirlo sin haber leído los informes es como se tira correo legítimo.

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

## Lo MEDIDO ANTES de publicar — 2026-09-08 por la mañana (`dig` contra `ns.rcp.net.pe`, flag `aa`)

Sin cambios respecto al 2026-09-03 en lo que toca a este ticket: **los tres registros siguen
ausentes**. La zona no se ha tocado (serial del SOA `2026071400`, del 14 de julio).

| Registro | Estado 2026-09-08 |
|---|---|
| SPF (TXT raíz) | **No existe.** La raíz solo tiene `google-site-verification` y `apple-domain-verification` |
| DMARC (`_dmarc`) | **NXDOMAIN** — el nombre ni siquiera está creado |
| DKIM | **Nada.** Barrido de 23 selectores (`google`, `google1/2/3`, `default`, `selector1/2`, `s1/s2`, `k1/k2`, `20230601`…) en TXT y CNAME |
| MX | Google Workspace, 5 registros, correctos — **no tocar** |
| A raíz | `216.198.79.1` (Vercel) — **no tocar** |
| SOA | `2026071400 7200 300 604800 7200` — el último `7200` es la caché negativa (trampa 3) |

**Controles de la medición** (sin ellos, «no hay nada» y «mi consulta no ve nada» son la misma
salida):

- *Positivo del servidor+tipo*: el TXT de la raíz **sí** devuelve los dos `verification` ⇒ el
  autoritativo responde TXT y la ausencia de SPF es real.
- *Positivo del barrido DKIM*: el mismo `dig +short TXT <sel>._domainkey.<dom>` detecta DKIM en 6
  dominios ajenos que sí lo publican (`selector1._domainkey.microsoft.com`,
  `google._domainkey.github.com`, `k1._domainkey.mailchimp.com`, `s1._domainkey.sendgrid.net`,
  `20230601._domainkey.gmail.com`, `selector2._domainkey.microsoft.com`) ⇒ el método ve DKIM cuando
  lo hay.
- *Negativo*: un selector inventado sobre uno de esos dominios devuelve vacío ⇒ no da falsos
  positivos.

**Remitentes — premisa re-comprobada el 2026-09-08.** El único remitente de `@yala-app.pe` sigue
siendo Google Workspace. MEDIDO en este árbol: cero proveedores de envío (`sendgrid`, `mailgun`,
`postmark`, `ses`, `resend`, `brevo`…) en todo el repo; la web **no** manda correo (no hay rutas de
API ni `nodemailer`/`MailChannels`: `admin@yala-app.pe` es un `supportEmail` que se pinta como
`mailto:` en `SupportPage.astro`, y eso envía desde el cliente del visitante, no desde el dominio);
ningún subdominio publica MX propio (probados `mail`, `smtp`, `www`, `app`, `api`, `web`, `dev`,
`staging`, `news`, `correo`, `m`). **Esto es lo que hace seguro el `~all`**: si hubiera un remitente
fuera de Workspace, el SPF de abajo mandaría a spam correo legítimo.

**Presupuesto de lookups del SPF**: `include:_spf.google.com` consume 4 de los 10 permitidos (1 el
include + 3 `_netblocks`). Margen de 6 para lo que venga.

## Decidido por el owner (2026-09-03)

- Buzón de informes DMARC (`rua`): **`admin@yala-app.pe`**.
- Empezar en **`p=none`** (observación). No arrancar en `p=reject`.

---

# CHECKLIST PARA PEGAR — HECHO el 2026-09-08

> Se conserva porque documenta el orden y las trampas: si hay que rehacerlo (rotar la clave,
> mover el dominio de registrador, subir la política), el procedimiento es este mismo.

> El orden importa: **generar el DKIM antes de publicarlo, y activarlo después de publicarlo.**
> Si se pulsa "Iniciar autenticación" antes de que el TXT esté en el DNS, Google falla la
> comprobación y hay que esperar a reintentarlo.

## Paso 0 · Anotar el testigo (10 segundos, ahorra un diagnóstico)

```
dig +short SOA yala-app.pe @ns.rcp.net.pe
```

Hoy responde con el serial **`2026071400`**. **Ese número tiene que cambiar** cuando el panel
publique los registros. Si al terminar sigue igual, el panel no aplicó nada — y eso se parece mucho
a «no ha propagado todavía», que es una espera inútil.

## Paso 1 · Consola de Workspace — generar el DKIM, SIN activarlo

`admin.google.com` → **Aplicaciones → Google Workspace → Gmail → Autenticar correo** → dominio
`yala-app.pe` → longitud de clave **2048 bits** → **Generar registro nuevo**.

Copiar las dos cosas que muestra:

- el **host** — será `google._domainkey`
- el **valor** — empieza por `v=DKIM1; k=rsa; p=` y sigue con una tirada larga de caracteres

⚠️ **No pulsar "Iniciar autenticación" todavía.** Ese es el paso 3.

## Paso 2 · Panel DNS de punto.pe — los tres TXT de una sentada

Tipo **TXT** en los tres. TTL: el que ofrezca por defecto (3600 está bien).

| # | Host | Valor |
|---|---|---|
| 1 | `google._domainkey` | *(el valor largo del paso 1, tal cual, completo)* |
| 2 | `@` (o el campo vacío, según el panel) | `v=spf1 include:_spf.google.com ~all` |
| 3 | `_dmarc` | `v=DMARC1; p=none; rua=mailto:admin@yala-app.pe` |

⚠️ El registro 2 se **AÑADE** a los dos TXT que ya hay en la raíz. No se reemplaza nada — ver
trampa 1.

## Paso 3 · Volver a Workspace y pulsar **"Iniciar autenticación"**

**Es el paso que se olvida.** Sin él, el TXT del DKIM está publicado y Google **sigue sin firmar**
el correo que sale: DKIM daría `none` en las cabeceras y DMARC se apoyaría solo en SPF.

Google tarda entre unos minutos y ~48 h en confirmar. El estado se ve en esa misma pantalla.

## Paso 4 · Verificar (esto ya lo puede correr cualquiera)

Pegar entero en una terminal:

```bash
NS=ns.rcp.net.pe; D=yala-app.pe
echo "SOA (el serial debe haber cambiado desde 2026071400):"
dig +short SOA $D @$NS | awk '{print "   serial =", $3}'
echo "SPF (debe salir v=spf1 ... Y SEGUIR los dos verification):"
dig +short TXT $D @$NS | sed 's/^/   /'
echo "DMARC (ya no debe ser NXDOMAIN):"
dig +short TXT _dmarc.$D @$NS | sed 's/^/   /'
echo "DKIM (debe empezar por v=DKIM1):"
dig +short TXT google._domainkey.$D @$NS | sed 's/^/   /'
echo "Host mal escrito (trampa 2) — esto DEBE salir vacío:"
dig +short TXT google._domainkey.$D.$D @$NS | sed 's/^/   /'
echo "MX intactos (5 líneas de google.com):"
dig +short MX $D @$NS | sort | sed 's/^/   /'
echo "A intacto (216.198.79.1):"
dig +short A $D @$NS | sed 's/^/   /'
```

**Los `dig` van contra el autoritativo a propósito** (`@ns.rcp.net.pe`), no contra `8.8.8.8` — ver
trampa 3.

## Paso 5 · Un correo de comprobación

Desde `admin@yala-app.pe` (**no** desde un alias ni con "enviar como") a una cuenta externa —un
Gmail personal sirve—. En Gmail: **⋮ → "Mostrar original"**. La cabecera `Authentication-Results`
tiene que dar **SPF, DKIM y DMARC en `pass`**, los tres.

Si DKIM sale `none` o `fail` y SPF sale `pass`: falta el paso 3, o Google todavía no ha confirmado.

---

## Trampas de esta zona

1. **AÑADIR el SPF, no reemplazar.** La raíz ya tiene dos TXT (`google-site-verification` y
   `apple-domain-verification`). Si el panel presenta el TXT de la raíz como un campo único y se
   sobrescribe, **se tumban la verificación de Google y la de Apple** de una vez. Tras publicar, el
   paso 4 debe seguir mostrando los dos `verification` **además** del `v=spf1`.

2. **Host relativo vs. absoluto.** Unos paneles quieren `google._domainkey` (relativo) y otros
   `google._domainkey.yala-app.pe.` (absoluto, con punto final). Si se teclea el nombre completo en
   un panel que ya añade el dominio, queda
   `google._domainkey.yala-app.pe.yala-app.pe` — publicado, invisible, y sin error en ningún sitio.
   El paso 4 lo detecta: esa consulta tiene que salir **vacía**. Lo mismo vale para `_dmarc`.

3. **Caché negativa de 2 h.** SOA `7200 300 604800 7200`: como `_dmarc` es NXDOMAIN hoy, los
   resolvers públicos pueden seguir diciendo que no existe **hasta 2 h después** de crearlo. Por eso
   los `dig` del paso 4 van contra el autoritativo. No es un fallo del registro: es memoria del
   resolver.

4. **Si el panel rechaza el valor de DKIM por largo.** Un DKIM de 2048 bits pasa de 255 caracteres y
   los paneles antiguos lo parten mal. Dos salidas, en este orden: (a) partirlo a mano en trozos de
   ≤255 entre comillas si el panel lo admite; (b) si no, **regenerar con 1024 bits** en el paso 1.
   **Un DKIM de 1024 que funciona vale más que uno de 2048 roto.**

5. **El `rua` debe ser una dirección del propio dominio.** Con un buzón externo (un Gmail personal,
   por ejemplo) los informes NO llegan salvo que el dominio destino publique
   `yala-app.pe._report._dmarc.<dominio>`, cosa que Google no va a hacer. Es el error que deja DMARC
   puesto y mudo. Por eso `admin@yala-app.pe`.

6. **No subir `p=` por encima de `none` en esta tanda.** Ver la sección siguiente.

## Después, no ahora

`p=none` es observación, no protección. En 1–2 semanas los informes en `admin@` dirán quién manda de
verdad como `@yala-app.pe`. Solo entonces se sube a `p=quarantine` y luego `p=reject`. Antes no:
subir la política sin haber leído un solo informe es como se tira correo legítimo propio.

## Corregido el 2026-09-08: el segundo nameserver SÍ responde

La versión anterior de este ticket decía, como hallazgo de paso, que **`ns2.rcp.net.pe`
(209.45.127.3) no respondía** —3 de 3 timeouts el 2026-09-03— y que el dominio corría sobre un solo
NS operativo. **Hoy eso ya no se sostiene.** Re-medido el 2026-09-08:

| Nameserver | Respuestas autoritativas (`aa` + `NOERROR`) | Latencia | Serial |
|---|---|---|---|
| `ns.rcp.net.pe` (161.132.17.10) | **6/6** | 2 ms | `2026071400` |
| `ns2.rcp.net.pe` (209.45.127.3) | **6/6** | 2 ms | `2026071400` |

Los dos sirven la zona, con el **mismo serial** (zona sincronizada), y la delegación es coherente:
el TLD `.pe` declara los dos y la propia zona declara los dos. **No hay punto único de fallo y no hay
nada que reportarle a la RCP.** Lo del 2026-09-03 fue una caída transitoria o una ruta bloqueada
desde el Mac —la medición de entonces no podía distinguirlo, y ya da igual cuál de las dos era.
