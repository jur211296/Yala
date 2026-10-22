---
id: privacy-policy-and-terms-miss-cloud-mode-identifiers-and-account-deletion
status: done
priority: high
area: "web, legal"
created: 2026-10-10
updated: 2026-10-12
source: "Checklist de envío de 2.1 (docs/RELEASE-CHECKLIST-2.1.md §2), medido sobre origin/2.1 6937828ff"
---

# La política y los términos no cuentan el Modo Nube, los identificadores ni el borrado de cuenta

## Por qué existe

`session-redesign-web-and-store-copy` corrige la política y los términos **solo por el lado de Grupos**.
El resto de lo que 2.1 cambia no lo cubre ningún ticket, y la política bloquea el envío por decisión de
Jürgen del 2026-09-09. Es territorio de Lola (`Web/`): Frank no lo edita.

## Qué es falso o falta (bloque `es` de `Web/src/i18n/translations.ts`; igual en los otros cinco idiomas)

- `privacyDataBullet2` (:197) «Sin registro» y `termsAccountText` (:229) «no requiere crear una cuenta». Modo Nube y Grupos piden cuenta de Apple o Google (`Yala/Services/CloudSync/CloudAuthService.swift:378`).
- `privacyIcloudText` (:200) y `termsDataText` (:237) «no tenemos acceso». La app dice «nuestro equipo puede verlos… No usamos cifrado de extremo a extremo» (`storage.consent.pointServers`, `Yala/Resources/es.lproj/Localizable.strings:4696`).
- `privacyDataIntro` (:195) y `termsDataText` (:237): todo vive en el dispositivo y en iCloud. En Modo Nube vive en Supabase, us-east-1 (`gateway/wrangler.toml:96,127`).
- `privacyNotDoBullet4` (:209) «No recopilamos identificadores de tu dispositivo». Se recogen el IDFV (`Yala/Services/CloudSync/MigrationWorkExecutor.swift:343-347`), la clave de App Attest (`gateway/migrations/0001_init.sql:5-16`), el token APNs y un hash de instalación.
- `termsSubscriptionText` (:241) «2 cuentas, 3 presupuestos». El código da 4 cuentas (`Yala/App/Services/FeatureGateService.swift:26-31`).
- `faq1A` (:160) «Yala no tiene servidores propios» y home `v3Priv1` (:398) «No tenemos cuenta tuya».
- Falta una sección de Modo Nube: qué se sube, quién lo ve, dónde (la app remite a la política para eso, `Yala/Services/CloudSync/CloudConsentText.swift:24-26`), Apple y Google como proveedores de login y retención.
- Falta «Eliminar mi cuenta» dentro de la app (`Yala/Services/CloudSync/AccountDeletionService.swift:180-260`). `privacyRightsText` (:211) y `termsTerminationText` (:245) dan a entender que borrar la app lo borra todo.
- §4 dice que la IA va «a OpenAI» (:202). Antes pasa por el gateway propio, que guarda metadatos sin contenido (`gateway/src/ai/handler.ts:85-104`).
- Faltan los encargados (Supabase, Cloudflare, OpenAI, Apple, Google) y la fecha sigue en «Junio 2026» (:190, :222).

## Riesgo de despliegue

Producción ya sirve la web de 2.1 (medido con `curl` el 2026-10-10), pero la rama de producción de Vercel
sigue siendo `1.0`. Un redeploy desde ahí devolvería el texto de TelemetryDeck. Al publicar la corrección,
Jürgen cambia esa rama.

## Hecho cuando

La política y los términos publicados en `yala-app.pe` cuentan el Modo Nube, los identificadores, el
borrado de cuenta, el gateway de IA, los encargados y el límite real del plan gratis, en los seis idiomas,
antes del envío de 2.1.

## Hecho (2026-10-12, encargo `textos-legales-2-1`)

Frank reescribió la política y los términos en los seis idiomas, con fecha «Octubre 2026», por
excepción de Jürgen a «Web/ es de Lola» solo para esta tarea. Cada afirmación nueva lleva su cita
`fichero:línea` en la descripción del PR. Además: `faq1A`, `faq7A`, `faq9A`, `v3Priv1`, `v3Priv3`,
`v3CtaNote`, `pricingFree1` y `v3FreeDesc`. Nada desplegado.

## Correcciones de Lola (2026-10-12, mismo PR)

Texto aprobado con correcciones: sin la sección del conector de Claude (la política queda en 14 secciones), «más de 50
divisas», copias de seguridad «hasta 7 días», la frase de OpenAI sobre su política para la API, fotos sin GPS ni EXIF
(también en el código), exportación de todos los datos gratis (también en el código: sin puerta Pro en ningún período),
y las dos frases de la app que contradecían la política, corregidas en los 16 idiomas.

## Guion de QA (Lola + Jürgen)

1. Leer el PR: la tabla «antes / después» y la lista de lo no verificado.
2. El PR lo mergea la sesión con CI verde (delegación de Lola, 2026-10-12).
3. Lola: en Vercel, cambiar la rama de producción de `1.0` a `2.1` y esperar al despliegue.
4. Abrir `https://yala-app.pe/privacy` y `https://yala-app.pe/terms`: arriba debe decir
   «Última actualización: Octubre 2026» y la política tiene 14 secciones. Repetir con `/en/privacy`.
5. Comprobar que ya no sale el texto viejo: `curl -sL https://yala-app.pe/privacy | grep -c "Supabase"`
   da más de 0. (El `grep -c CloudKit` de la checklist ya no sirve: la política nueva nombra CloudKit dos veces,
   para el modo privado y para los grupos antiguos.)
6. En un iPhone sin Pro: Perfil → Exportar datos → Período. «Este año», «Año pasado», «Todo el tiempo» y
   «Personalizado» salen sin insignia Pro y se pueden elegir.

## Cierre

Cerrado en el barrido de QA 2026-10-12: la web está desplegada y medida hoy con curl: /privacy y /en/privacy tienen 14 secciones y «Octubre 2026», nombran Supabase, y /terms tiene la fecha nueva. La exportación gratis de todos los períodos la fija ExportFreePeriodsUITests, y Lola aprobó el texto (PR #469). Las etiquetas de App Privacy siguen en su card (kgqv).
