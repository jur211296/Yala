# Checklist de envío de 2.1 a la App Store

> **Medido el 2026-10-10 sobre `origin/2.1` en `6937828ff`.** Las citas `fichero:línea` son de ese árbol.
> Si lees esto más tarde, vuelve a medir antes de marcar nada: en este repo los documentos envejecen
> más rápido que el código.
>
> **Estado:** ✅ **verificado** = medido en el código o con un comando, citado · 🔲 **no verificado** =
> vive fuera del repo (App Store Connect, la consola de CloudKit, Supabase de producción, Google Cloud o
> Vercel) y se comprueba con el paso que se indica.
>
> **Responsables:** **J** = Jürgen · **L** = Lola · **F** = Frank.

## Resumen: lo que hoy impide enviar

1. **La política de privacidad y los términos mienten sobre 2.1** (§2). Por decisión de Jürgen del
   2026-09-09 eso bloquea el envío. El ticket que lo cubre (`session-redesign-web-and-store-copy`, card
   `i6tj`) solo corrige Grupos y sigue en `backlog`. El Modo Nube, los identificadores y el borrado de
   cuenta no los cubre ningún ticket: se abre uno nuevo
   (`privacy-policy-and-terms-miss-cloud-mode-identifiers-and-account-deletion`).
2. **Las etiquetas de App Privacy se quedan cortas** (§1). Faltan nombre, email, ID de usuario, contenido
   del usuario, uso del producto y diagnósticos. El ID de dispositivo figura como «no vinculado» y sí
   está vinculado.
3. **El esquema de CloudKit de Production no está comprobado** (§5.2). PR #442 abierto, con la guía.
4. ~~La migración `g17_01` no está aplicada~~ → **hecho**: aplicada en staging y producción; md5(prosrc) de `migration_progress` = `776dac35d585393fabeabedf8eafee82` en los dos, re-medido por Frank el 2026-10-10 15:05 Lima con la Management API (§5.3). Ya no bloquea.
5. **Bloqueantes del tablero:** 2 en `blocked` y 15 en `in qa` con prioridad `high` (§6).

---

## 1. Etiquetas de privacidad (App Privacy en App Store Connect)

### 1.1 Lo que sale del teléfono en 2.1

Todo sale por **dos servidores propios**: el gateway de Cloudflare
(`Yala/App/Services/ProxyConfig.swift:19`, `yala-gateway-production…workers.dev`) y Supabase de producción,
que solo se usa para el login (`Yala/App/Services/CloudBackendConfig.swift:47`). El resto va a Apple
(CloudKit, StoreKit, App Attest, notificaciones push, `itunes.apple.com/lookup`) y a Google (inicio de
sesión). La extensión de compartir y los widgets no hacen ninguna llamada de red (0 `URLSession` en
`YalaShare/` y `YalaWidgets/`).

| Qué | Qué viaja | Dónde se queda | Cita |
|---|---|---|---|
| **Modo Nube**, al 100 % en producción | Todos los datos financieros (cuentas con número de cuenta, movimientos con nota, presupuestos, pagos programados, borradores de la Bandeja con texto en bruto, preferencias), con `user_id` en 16 tablas | Supabase, us-east-1. El equipo **puede verlos**: no hay cifrado de punta a punta (texto del consentimiento, `Yala/Resources/es.lproj/Localizable.strings:4696`) | `gateway/wrangler.toml:127,136`; `supabase-staging.ddl:15-446`; `gateway/src/index.ts:72-77` |
| **Cuenta** con Apple o Google | Email y nombre. Apple los pide con `[.fullName, .email]`; Google usa los scopes por defecto (`openid email profile`, inferido del SDK) | `auth.users` de Supabase | `Yala/Services/CloudSync/CloudAuthService.swift:318,381`; `qa/cloud/g12_01_delete_account_auth_users.sql:4` |
| **IDFV** del dispositivo | Se manda como `device_id` | `profiles.leader_device_id`, **vinculado a la cuenta** | `Yala/Services/CloudSync/MigrationWorkExecutor.swift:343-347`; `gateway/src/sync/account.ts:118` |
| **App Attest** | La clave del dispositivo; acompaña a toda llamada de IA y de tipos de cambio | D1 `attest_keys` y, con Modo Nube, `attest_keys.user_id` en Supabase | `gateway/migrations/0001_init.sql:5-16`; `supabase-staging.ddl:438-446`; `gateway/src/attest/session.ts:22` |
| **Grupos en el backend**, al 100 % | Nombre del grupo, alias de cada miembro, importes, descripciones, notas y liquidaciones. Cifrado con una llave del servidor, no de punta a punta. No viajan emails | Supabase | `gateway/wrangler.toml:170`; `supabase-groups-staging.ddl:110-263`; `gateway/src/groups/rpc.ts:40-80` |
| **Push de Grupos** | Token APNs y plataforma, con `user_id` | `push_tokens` | `supabase-groups-staging.ddl:280`; `Yala/Services/CloudSync/Groups/PushTokenRegistrationClient.swift:62` |
| **IA** | Fotos de recibos (`ImageVisionService.swift:200-209`), audio de voz (`VoiceTranscriptionService.swift:162-166`), texto del chat y contexto financiero con nombres de cuenta (`FullFinancialContextBuilder.swift:419-426`) | Pasa por el gateway, que **no guarda el contenido** (`gateway/src/index.ts:30`). Solo registra métricas sin texto (`gateway/src/ai/handler.ts:85-104`). Proveedor: **solo OpenAI** (`gateway/src/ai/routes.ts:180-306`). Gemini está preparado y apagado (`:316-326`) | `gateway/src/index.ts:61-62` |
| **Tipos de cambio** | Solo códigos de divisa y fechas | Proxy a `api.exchangerate.host` | `Yala/Services/ExchangeRateAPIService.swift:52,71`; `gateway/src/proxy/rates.ts:8` |
| **Telemetría propia** | Un ping diario, el alta y avisos técnicos, con un hash anónimo de instalación y la versión de la app | Cloudflare Analytics Engine. TelemetryDeck está eliminado (`d460480bf`) | `Yala/Services/Metrics/MetricsEvent.swift:36-41`; `MetricsService.swift:549-556`; `gateway/src/metrics.ts:101-106` |
| **Compras** | StoreKit 2, sin RevenueCat. La transacción firmada va al gateway | `account_entitlements`, **por `user_id`** | `Yala/App/Services/StoreKitManager.swift:20-21,240-243`; `gateway/migrations/0002_account_entitlements.sql:14-22` |
| **Crash o publicidad** | Nada: no hay Sentry, Crashlytics, MetricKit, IDFA, ATT ni SDK publicitario | — | grep sin resultados (ver «Cómo se midió») |
| **iCloud privado y CloudKit Sharing** | Datos del usuario en su iCloud | Apple. No es recogida del desarrollador y no se declara | `Yala/App/Yala-Release.entitlements:20-26` |

### 1.2 Respuestas propuestas, por categoría

**Tracking: ninguno.** No se cruzan datos con terceros para publicidad.

| Tipo de dato (Apple) | ¿Se recoge? | ¿Vinculado al usuario? | Propósito | Por qué |
|---|---|---|---|---|
| Contact Info → **Name** | Sí | Sí | App Functionality | Nombre de Apple o Google en `auth.users` y alias de miembro de grupo (`supabase-groups-staging.ddl:147`) |
| Contact Info → **Email Address** | Sí | Sí | App Functionality | `auth.users.email` |
| Financial Info → **Other Financial Info** | Sí | Sí | App Functionality | Modo Nube y Grupos (tabla de §1.1) |
| User Content → **Photos or Videos** | Sí | **Sí** (ver nota) | App Functionality | Fotos de recibos a la IA |
| User Content → **Audio Data** | Sí | **Sí** (ver nota) | App Functionality | Notas de voz a la IA |
| User Content → **Other User Content** | Sí | Sí | App Functionality | Notas, texto en bruto de la Bandeja y texto del chat |
| Identifiers → **User ID** | Sí | Sí | App Functionality | `sub` de Supabase y `appAccountToken` |
| Identifiers → **Device ID** | Sí | **Sí** | App Functionality, Analytics | IDFV en `profiles`, clave de App Attest, token APNs y hash de instalación |
| Purchases → **Purchase History** | Sí | Sí | App Functionality | `account_entitlements` |
| Usage Data → **Product Interaction** | Sí | No | Analytics | Ping diario y alta |
| Diagnostics → **Other Diagnostic Data** | Sí | No | App Functionality, Analytics | Avisos técnicos (`MetricsService.swift:497-511`) |
| Diagnostics → Crash Data, Performance Data | No | — | — | Sin SDK de crash ni MetricKit |
| Location, Contacts, Health, Browsing, Search, Sensitive Info, Payment Info | No | — | — | Sin rastro en el código |

**Nota sobre fotos y audio.** Viajan con la clave de App Attest, no con el `user_id`. Con Modo Nube, esa
clave queda unida a la cuenta en `attest_keys.user_id`, así que el servidor *puede* relacionarlas. Lo
prudente es marcarlas como vinculadas. Decide **J**.

### 1.3 Qué cambia frente a lo declarado hoy

- El repo **no guarda copia** de lo que hay hoy en App Store Connect: hay que mirarlo allí. Lo más
  parecido es el manifiesto `Yala/Resources/PrivacyInfo.xcprivacy`, que según el commit `46b076365` se
  alineó con las etiquetas en junio. Declara audio, fotos, información financiera, historial de compras e
  ID de dispositivo (`:11-70`).
- **Faltan:** Name, Email, User ID, Other User Content, Product Interaction y Other Diagnostic Data.
- **Hay que cambiar:** Device ID pasa de «no vinculado» con propósito Analytics
  (`PrivacyInfo.xcprivacy:59-70`) a vinculado, con App Functionality y Analytics.

### Casillas

- [ ] **J** · Abrir App Store Connect → App Privacy y anotar lo declarado hoy · 🔲 no verificado
- [ ] **J** · Ajustar las etiquetas a la tabla de §1.2 y decidir fotos y audio · 🔲 no verificado
- [ ] **F** · Alinear `PrivacyInfo.xcprivacy` con las mismas respuestas, añadir el motivo `1C8F.1` (lectura de los ajustes del App Group, 21 ficheros con `UserDefaults(suiteName:)`) y valorar un manifiesto para el widget · ✅ hueco verificado · ticket `privacy-manifest-misses-cloud-account-data`

---

## 2. Política de privacidad y términos

**Qué hay en producción hoy (medido con `curl` el 2026-10-10):** `yala-app.pe` ya sirve la web de 2.1,
no la de 1.0. El §6 de `/privacy` habla del gateway de Cloudflare, y `/llms.txt` coincide byte a byte con
`Web/public/llms.txt` de 2.1, un fichero que no existe en `origin/1.0`. Pero la rama de producción de
Vercel sigue siendo `1.0`: **un redeploy desde ahí devolvería el texto de TelemetryDeck**, que es falso
desde julio.

El texto legal sale de las claves `privacy*` y `terms*` de `Web/src/i18n/translations.ts` (seis idiomas).
`Web/privacy_content.md` no se publica (`Web/vercel.json:57` lo redirige). Las líneas de abajo son del
bloque `es`.

### 2.1 Frases falsas con 2.1

| Dónde | Lo que dice | Lo que pasa en 2.1 |
|---|---|---|
| Privacidad §5 `privacyGroupsText` (`:309`) · Términos §5 `termsDataText` (`:237`) · FAQ `faq9A` (`:307`) | Grupos va «mediante CloudKit Sharing de Apple… no en servidores nuestros» | Grupos vive en el backend propio, al 100 % (`gateway/wrangler.toml:170`; `Yala/Services/CloudSync/CloudSyncFlags.swift:653`). La app dice «viven en la nube de Yala» (`Localizable.strings:4842`) |
| Privacidad §2 `privacyDataBullet2` (`:197`) · Términos §3 `termsAccountText` (`:229`) | «Sin registro» · «no requiere crear una cuenta» | Modo Nube y Grupos piden cuenta de Apple o Google (`CloudAuthService.swift:378`) |
| Privacidad §3 `privacyIcloudText` (`:200`) · Términos §5 (`:237`) | «Nosotros no tenemos acceso» | En Modo Nube, «nuestro equipo puede verlos… No usamos cifrado de extremo a extremo» (`Localizable.strings:4696`) |
| Privacidad §2 `privacyDataIntro` (`:195`) · Términos §5 (`:237`) | Todo se guarda en el dispositivo y en iCloud | Modo Nube guarda en Supabase (`gateway/wrangler.toml:96,127`) |
| Privacidad §7 `privacyNotDoBullet4` (`:209`) | «No recopilamos identificadores de tu dispositivo» | IDFV, App Attest, token APNs y hash de instalación (tabla §1.1) |
| Términos §8 `termsSubscriptionText` (`:241`) | Gratis: «2 cuentas, 3 presupuestos» | El código da **4 cuentas** y 3 presupuestos (`Yala/App/Services/FeatureGateService.swift:26-31`) |
| FAQ `faq1A` (`:160`) · home `v3Priv1` (`:398`) | «Yala no tiene servidores propios» · «No tenemos cuenta tuya» | Falso, por lo mismo |

### 2.2 Lo que falta

- **Una sección de Modo Nube.** Qué se sube, quién lo ve, dónde está (Supabase, us-east-1), Apple y Google
  como proveedores de inicio de sesión, y retención. La app promete que la política dice dónde están los
  servidores (`Yala/Services/CloudSync/CloudConsentText.swift:24-26`), y la política no lo dice.
- **«Eliminar mi cuenta» dentro de la app** (§5.7). Hoy la política y los términos dan a entender que
  borrar la app lo borra todo (`privacyRightsText` `:211`, `termsTerminationText` `:245`).
- **El gateway de IA.** La política dice que los datos van «a OpenAI» (`:202`). Antes pasan por el gateway
  propio, que guarda metadatos de cada llamada.
- **Los encargados del tratamiento:** Supabase, Cloudflare, OpenAI, Apple y Google.
- **La fecha:** sigue «Junio 2026» (`:190`, `:222`).

### Casillas

- [ ] **L** · `session-redesign-web-and-store-copy` (card `tablero-la-web-la-politica-y-la-ficha-dicen-que-i6tj`, hoy en `backlog`, asignada a Frank para pasársela a Lola): corregir lo de Grupos en la política, los términos y la FAQ · ✅ frases verificadas · **bloqueante: en producción ANTES del envío**
- [ ] **L** · Ticket nuevo `privacy-policy-and-terms-miss-cloud-mode-identifiers-and-account-deletion`: Modo Nube, identificadores, borrado de cuenta, gateway de IA, encargados, el límite de 4 cuentas y la fecha · ✅ frases verificadas · **bloqueante**
- [ ] **J** · Desplegar la web corregida y comprobar con `curl -sL https://yala-app.pe/privacy | grep -c CloudKit` que da 0 · 🔲 no verificado
- [ ] **J** · Cambiar la rama de producción de Vercel de `1.0` a la que lleve la web corregida, para que un redeploy no la devuelva al texto viejo · 🔲 no verificado (dato de la memoria de Frank, no del panel)

---

## 3. Capturas

**Tamaños.** La app corre en iPad (`TARGETED_DEVICE_FAMILY = "1,2"` en `Yala.xcodeproj/project.pbxproj:574`),
así que App Store Connect pide **iPhone 6,9"** (1320×2868) e **iPad 13"** (2064×2752 o 2048×2732).
Fuente: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
El tamaño de iPad está confirmado en esa página; el de iPhone 6,9" sale de un hilo del foro de 2024 y conviene mirarlo en la página viva.

**Lo que hay.** `marketing/App Store/PNG-iphone-{ESPAÑOL,INGLES}` (10 cada uno, 1320×2868) y
`PNG-ipad-{ESPAÑOL,INGLES}` (8 cada uno, 2752×2064 en horizontal). Los tamaños valen. El contenido es del
generador de 2.0 (commit `6e8ef0714`, 11-jun), anterior incluso a 2.0.4.

| Captura | Por qué se rehace | Ticket |
|---|---|---|
| 1 · Hero del Panel | Cuentas en tarjetas grandes y hero reordenado | `tickets/done/panel-accounts-redesign.md` |
| 2 · Yala IA | Chat con forma de mensajería y tarjeta de registro nueva | `tickets/qa/ai-chat-reads-heavier-than-a-messaging-app.md`, `tickets/qa/chat-draft-card-redesign.md` |
| 3 · Grupos | **Su texto «Vía tu iCloud» es falso** (`marketing/screenshots-appstore/generator/src/app/page.tsx:49,64`); vista del gasto rediseñada | `tickets/qa/group-expense-views-redesign.md` |
| 4 · Registro | Voz e imagen en una hoja; selectores a media altura | `tickets/qa/voice-entry-end-to-end.md`, `tickets/qa/image-entry-end-to-end-redesign.md` |
| 5 · Score | El hero de Estadísticas es ahora el del Panel | `tickets/done/hero-estadisticas-stock-vs-flujo-entre-pestanas.md` |
| 8 · Distribución | Hero nuevo | `tickets/qa/distribution-subviews-miss-the-new-panel-hero.md` |
| 10 · Privacidad | «Respaldo solo en tu nube» ya no cuenta la historia: ahora tú eliges iCloud o la nube de Yala (`page.tsx:56-58,71-73`) | — |
| **Todas las de iPad** | 2.1 trae la interfaz nativa de iPad: barra lateral, dos columnas, Yala IA al lado | `tickets/done/ipad-native-app.md` |
| Nueva (opcional) | Bienvenida con Apple y Google | `tickets/qa/onboarding-login-should-match-the-sep15-reference.md` |
| 6, 7 y 9 | Presupuestos, Flujo de caja y Temas: sin rediseño conocido, probablemente valen | — |

### Casillas

- [ ] **L** · Rehacer las capturas 1, 2, 3, 4, 5, 8 y 10 de iPhone, en es y en, **después** de que pasen los tickets en `qa` de la tabla · ✅ lista verificada contra tickets
- [ ] **L** · Rehacer todas las de iPad con la interfaz nativa · ✅
- [ ] **L** · Confirmar en la página de Apple el tamaño vigente del iPhone 6,9" · 🔲 no verificado

---

## 4. Notas de la versión y ficha

**Última versión publicada: 2.0.4** (6-jul-2026): `tickets/done/remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark.md:105`,
y es el último tag (`v2.0.4`). La rama `origin/2.0.5` solo llegó a TestFlight. Así que **todo lo hecho
desde 2.0.4 es nuevo** para quien tiene la app de la tienda.

**Idiomas.** La app trae 10 idiomas base (es, en, pt, fr, it, de, nl, pl, ja, zh-Hans) en 16 carpetas
`.lproj` (`project.pbxproj:390-408`). La ficha los cubre: 7 en `marketing/App Store/metadata/` más nl, pl,
ja y zh-Hans en `marketing/App Store/metadata-2.0-extra-locales.md`. **El repo no guarda el subtítulo ni
las keywords de es y en**, y sus descripciones son anteriores a 2.0: antes de editar, `asc metadata pull`.

### 4.1 Frases de la ficha que ya son falsas

- «No almacenamos nada en servidores» (`marketing/App Store/metadata/description-es.md:25`), y lo mismo en los 7 idiomas.
- «Grupos… todo viaja por tu iCloud privado» (`marketing/App Store/whats-new/v2.0.md` y los locales extra).
- «Grupos (en beta)»: Grupos ya no pide código beta (commit del 2026-08-11).
- «45+ divisas» y «más de 50» en la misma descripción. El código tiene 54 (`Yala/Utils/CurrencyUtils.swift`).
- La voz figura como solo Pro. Ahora hay prueba gratis de 5 notas de voz y 5 fotos (`gateway/src/policy.ts:28-46`).

### 4.2 Borrador de las notas de la versión

Solo incluye lo confirmado. Las líneas marcadas **[qa]** dependen de un ticket aún en `qa`: si no pasa, la línea se quita.

**Español**

```
Yala 2.1 llega con muchas novedades:

• Tú eliges dónde viven tus datos: en tu iCloud privado, como siempre, o en tu cuenta en la nube de Yala, entrando con Apple o con Google.
• Grupos, abierto para todos: ya no necesitas código beta. Entras con tu cuenta de Apple o Google, invitas con un enlace y los avisos te llegan aunque la app esté cerrada. Además: un tope de gasto para el grupo, un recordatorio amable cuando una deuda lleva semanas quieta, el resumen del viaje en una imagen para mandar al chat y la opción de pasarle el grupo a otra persona antes de salir.
• Registro por voz y por foto, renovados: Yala escucha o lee y tú confirmas en la misma hoja. También puedes subir un archivo o un PDF. [qa]
• Yala IA con nueva cara: se lee como un chat de mensajería y el gasto que te propone se edita como cualquier registro. [qa]
• Prueba sin Pro: 5 notas de voz y 5 fotos de regalo para que veas cómo funciona. [qa]
• Panel renovado: tus cuentas en tarjetas grandes, cuánto te dio o te quitó el tipo de cambio y el signo «≈» cuando un total usa un tipo aproximado.
• Ajustes más claros, al estilo de iOS, y pantallas de bienvenida nuevas. [qa]
• Yala en el iPad, a lo grande: barra lateral, dos columnas, varias ventanas, atajos de teclado, arrastrar recibos y widgets grandes.
• En el iPhone, Yala también gira a horizontal y se adapta mejor a los textos grandes.
• Y muchas correcciones para que todo cuadre mejor.
```

**English**

```
Yala 2.1 is packed with new things:

• You choose where your data lives: in your private iCloud, as always, or in your Yala cloud account, signing in with Apple or Google.
• Groups, open to everyone: no beta code needed. Sign in with Apple or Google, invite with a link, and get notified even when the app is closed. Plus: a spending cap for the group, a friendly reminder when a debt has been sitting for weeks, a trip summary as an image you can send to the chat, and the option to hand the group to someone else before you leave.
• Voice and photo logging, refreshed: Yala listens or reads, and you confirm on the same sheet. You can also upload a file or a PDF. [qa]
• A new look for Yala AI: it reads like a messaging chat, and the expense it suggests can be edited like any other record. [qa]
• Try it without Pro: 5 voice notes and 5 photos on us, so you can see how it works. [qa]
• A refreshed Dashboard: your accounts as big cards, how much the exchange rate gave or took, and a "≈" sign when a total uses an approximate rate.
• Clearer Settings, iOS style, and new welcome screens. [qa]
• Yala on iPad, in full: sidebar, two columns, multiple windows, keyboard shortcuts, drag-and-drop receipts, and large widgets.
• On iPhone, Yala now turns to landscape and adapts better to large text sizes.
• And lots of fixes so everything adds up better.
```

Las fuentes de cada línea: Modo Nube y Grupos, `gateway/wrangler.toml:127,170` y commits de julio-agosto;
Grupos, `tickets/done/groups-budget.md`, `groups-settlement-reminder.md`, `groups-shareable-summary.md`,
`groups-owner-transfer-and-leave.md`; Panel, `tickets/done/panel-accounts-redesign.md` y
`fx-pnl-education-card.md`; iPad, `tickets/done/ipad-native-app.md` y sus fases; horizontal,
`tickets/done/iphone-supports-landscape-orientation.md`. Las [qa]: `voice-entry-end-to-end`,
`image-entry-end-to-end-redesign`, `ai-chat-reads-heavier-than-a-messaging-app`,
`ai-every-call-sends-its-task-and-passes-the-bench`, `settings-redesign-as-grouped-lists-like-ios` y
`onboarding-login-should-match-the-sep15-reference`.

Dejo fuera «puedes volver a tu iCloud»: `tickets/qa/reverse-cutover-cerrado-para-cuentas-born-cloud.md`
dice que no vale para quien empezó en la nube. Y fuera el conector de Claude, que está en staging.

### 4.3 Ficha (es y en)

- **Subtítulo** (≤ 30): es `Gastos con IA, voz y grupos` (27) · en `Track & split expenses with AI` (30).
- **Keywords** (≤ 100): es `finanzas,presupuesto,dinero,ahorro,dividir,cuentas,recibos,flujo de caja,divisas,deudas,viaje,iCloud` · en `finance,budget,money,saving,spending,bills,receipts,cash flow,currency,debts,trip,iCloud,widget,iPad`.
- **Bloque de privacidad** (sustituye a «PRIVACIDAD PRIMERO»). Tiene que decir lo mismo que la política corregida; si chocan, manda la política.
  - es: «PRIVACIDAD, A TU MANERA: Tú eliges dónde viven tus datos: en tu dispositivo y en tu iCloud privado, o en tu cuenta en la nube de Yala, entrando con Apple o con Google. Grupos funciona con tu cuenta de Apple o Google. No nos conectamos a bancos ni vendemos tus datos.»
  - en: «PRIVACY, YOUR WAY: You choose where your data lives: on your device and in your private iCloud, or in your Yala cloud account, signing in with Apple or Google. Groups works with your Apple or Google account. We don't connect to banks and we don't sell your data.»
- **Párrafo Pro:** «Empieza con 5 notas de voz y 5 fotos de regalo. Con Pro desbloqueas Yala IA, escaneo y dictado ilimitados…» [qa]. Yala IA sigue siendo solo Pro: `.chatAssistant` está en `isProOnly` (`Yala/App/Services/FeatureGateService.swift:35-37`).
- **Divisas:** «Más de 50 divisas» / «50+ currencies».
- **Bullets nuevos:** iPad nativo, voz y foto en una hoja con PDF [qa], Apple o Google, Grupos sin beta.

### Casillas

- [ ] **L** · `asc metadata pull` para tener el subtítulo, las keywords y la descripción vivos · 🔲 no verificado
- [ ] **J** · Aprobar las notas de la versión y la ficha de es y en (§4.2 y §4.3) y tachar las líneas [qa] que no pasen · ✅ contenido verificado contra tickets
- [ ] **L** · Traducir notas y ficha a de, fr, it, pt-PT, pt-BR, nl, pl, ja y zh-Hans · 🔲
- [ ] **L** · Quitar de los 7 idiomas «no almacenamos nada en servidores», «Grupos en beta» y «vía tu iCloud» · ✅ frases verificadas

---

## 5. Técnico

### 5.1 Versión y build

- [ ] **J** · La versión es 2.1 y el build 15 en todos los targets: 20 apariciones de cada uno en `project.pbxproj`. El build real se mira al subir, desde la Mini · ✅ verificado
- [ ] **F** · **El widget fija su build a mano a `3`** (`YalaWidgets/Info.plist:23-24`, desde `0d68a5d0d`, mayo), y la app va en 15. App Store Connect avisará de que no coinciden. Hay que poner `$(CURRENT_PROJECT_VERSION)` · ✅ verificado · ticket `release-plist-leftovers-widget-build-faceid-appattest`
- [ ] **J** · Archivar con el scheme **«Yala»**, no «Yala Dev»: la configuración Release-Dev no define `DEV_BUILD` y apuntaría al backend de producción con los entitlements de Debug (`project.pbxproj:897`) · ✅ verificado

### 5.2 Esquema de CloudKit en Production

- [ ] **J** · Exportar el esquema de Production de `iCloud.com.jurgenschmidt.yala` y comprobar los 14 campos opcionales que la app escribe y el snapshot del repo no trae (por ejemplo `CD_Account.CD_accountNumber`, `CD_FavoritePayment.CD_amount`), y el tipo de `CD_CashFlowOverride.CD_line` (el repo dice `REFERENCE`; la app escribe `STRING`). Si faltan, Deploy Schema Changes. No hace falta build nuevo · 🔲 no verificado
  - Ticket: `tickets/backlog/personal-cloudkit-schema-snapshot-misses-optional-fields.md` (card `tablero-el-esquema-de-icloud-del-repo-no-tiene-c-o2li`).
  - La guía de 10 minutos está en el **PR #442**, abierto (`gh pr view 442`: `OPEN`, `BLOCKED`): `docs/cloudkit-schema-diff-2.1.md` en esa rama.
  - Si Production dice `REFERENCE` para `CD_line`, el arreglo es de código y lleva su propio ticket (`personal-cloudkit-cashflow-override-line-declared-as-reference`, en la rama del PR).

### 5.3 Backend: migraciones y Worker

- [x] **J** · Aplicar `qa/cloud/g17_01_reverse_claim_keeps_reverted_at.sql`: staging → goldens → producción → humo · ✅ aplicada en staging y producción; md5(prosrc) de `migration_progress` = `776dac35d585393fabeabedf8eafee82` en los dos, re-medido por Frank el 2026-10-10 15:05 Lima con la Management API. La sesión de la checklist no tenía credencial para medirlo y lo dio por no aplicado.
- [ ] **J** · El resto de la base de producción está al día según el runbook: `hlc01` aplicada el 2026-10-07 (`:423-425`). El Worker de producción es la versión `4e93d41f…` del 2026-10-08 (`:460-480`). No hay Edge Functions (0 `functions/v1`) · ✅ verificado en el runbook, 🔲 en la consola
- [ ] **J** · Flags de producción para el envío: Modo Nube 100, elección en la bienvenida 100, Grupos 100, versión mínima 0, `TRUST_ATTESTED_AS_PRO` false (`gateway/wrangler.toml:127,136,170,173,92`). Comprobar que lo desplegado coincide: `curl -s https://yala-gateway-production.misty-surf-6866.workers.dev/config` · ✅ verificado en el repo, 🔲 en vivo
- [ ] **J** · El conector de Claude (`mcp0_*`) **no** va a producción en 2.1 (`docs/RUNBOOK-staging-ddl.md:238-240`) · ✅

### 5.4 Entitlements

- [ ] **J** · Release: notificaciones push en `production` (`Yala/App/Yala-Release.entitlements:10-11`), Sign in with Apple (`:12-15`), `applinks:yala-app.pe` (`:16-19`), los 4 contenedores de iCloud (`:20-26`) y los App Groups (`:39-43`) · ✅ verificado
- [ ] **J** · Que el App ID de producción tenga dados de alta los contenedores y el App Group `.dev` que la Release también declara; si no, el perfil de distribución falla al exportar · 🔲 no verificado
- [ ] **J** · Que `https://yala-app.pe/.well-known/apple-app-site-association` se sirva en vivo: sin él, los enlaces de invitación a Grupos no abren la app. En el repo está en `Web/public/.well-known/apple-app-site-association:6-15` · 🔲 no verificado
- [ ] **F** · App Attest no declara su entitlement. En distribución atesta en producción igualmente (verificado en dispositivo el 2026-08-02, `docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md`); declararlo `production` quita la ambigüedad · ✅ verificado · mismo ticket que §5.1

### 5.5 Cifrado y permisos

- [ ] **J** · `ITSAppUsesNonExemptEncryption = false` (`Yala/Resources/Info.plist:112-113`). Encaja: solo HTTPS y primitivas del sistema; el cifrado de Grupos es `pgcrypto` en el servidor · ✅ verificado
- [ ] **J** · Textos de permisos: micrófono, cámara y fotos dicen «se envía a OpenAI» (`Info.plist:23-32`, en los 16 idiomas) · ✅ verificado
- [ ] **F** · Sobra `NSFaceIDUsageDescription`: el bloqueo con Face ID se quitó (0 `LocalAuthentication`; limpieza en `AppBootstrapper.swift:2688-2701`). No bloquea · ✅ verificado · mismo ticket que §5.1

### 5.6 Compras y suscripciones

- [ ] **J** · En App Store Connect, el grupo «Yala Pro» con `com.yala.pro.monthly` y `com.yala.pro.yearly` (`StoreKitManager.swift:20-21`) en «Ready to Submit», con precios, oferta de introducción y localizaciones. El fichero de pruebas `Yala/Configuration.storekit` trae 4,99 y 29,99 con un mes gratis; compara con lo que muestra la paywall · 🔲 no verificado
- [ ] **J** · Dar de alta la URL de App Store Server Notifications V2: `https://yala-gateway-production.misty-surf-6866.workers.dev/webhooks/appstore` (`gateway/src/index.ts:69`). El repo no deja constancia de que esté · 🔲 no verificado
- [ ] **J** · El gateway de producción acepta compras sandbox (`gateway/src/storekit/verifyStoreKitJWS.ts:78-83`), así que la compra del revisor desbloquea Pro · ✅ verificado

### 5.7 Borrado de cuenta y notas para el revisor

- [ ] **J** · El borrado de cuenta (regla 5.1.1(v)) está en Perfil → «Tu cuenta de Yala» → «Eliminar cuenta» (`Yala/App/Views/Profile/YalaAccountView.swift:181-191`). Aparece con cualquier sesión en la nube, también la de solo Grupos (`AccountDeletionService.swift:54-63`). Borra el servidor y revoca Apple y Google (`AccountDeletionService.swift:180-260`) · ✅ verificado
- [ ] **J** · **App de Google en Google Cloud (`yala-502622`):** si sigue en «Prueba», el revisor no puede entrar con Google. Publicarla · 🔲 no verificado (el dato es de julio, de la memoria, no del repo)
- [ ] **J** · Cuenta de review: no hay modo demo (los `DevSeed*` van bajo `#if DEBUG`) y el login es solo Apple o Google, así que el revisor usa su Apple ID. Para Grupos hacen falta dos identidades: dejar un grupo creado con una cuenta tuya y un enlace de invitación vigente en las notas · ✅ verificado lo del código, 🔲 la cuenta
- [ ] **J** · Escribir las notas para el revisor. Borrador:

```
Yala works without an account: data stays in the user's private iCloud.
Optional "Yala cloud account" (Settings › Storage, or "Your cloud account" on the welcome screen) signs in with Apple or Google and syncs data to our backend.
Groups: sign in with Apple or Google, accept the consent screen, then join our test group with this link: <enlace>. Two identities are needed to see the split.
Account deletion: Profile › Your Yala account › Delete account (visible once signed in). It deletes the data on our servers and revokes Sign in with Apple / Google.
Pro: the sandbox purchase unlocks Pro. Without Pro you get 5 voice notes and 5 photos to try the AI.
```

---

## 6. Bloqueantes abiertos del tablero (versión 2.1)

Leídos con `tablero listar --proyecto Yala --json` el 2026-10-10. Responsable = asignado en la card.

### 6.1 En `blocked`

- [ ] **J** · `tablero-las-preferencias-se-volvian-a-guardar-so-d44s` · Las preferencias se volvían a guardar solas: falta probarlo con dos aparatos · `tickets/blocked/apppreferences-rewritten-on-launch.md`
- [ ] **J** · `tablero-validar-en-testflight-unirse-a-un-grupo-e1ah` · Unirse a un grupo desde TestFlight con dos iPhone · `tickets/blocked/groups-join-intent-reconciler.md`

### 6.2 En `in qa`, prioridad `high`

- [ ] **J** · `tablero-el-esquema-de-icloud-del-repo-no-tiene-c-o2li` · Esquema de CloudKit (§5.2)
- [ ] **J** · `tablero-en-el-segundo-dispositivo-de-una-cuenta-gk5w` · Volver a iCloud en el segundo dispositivo; `g17_01` ya aplicada (§5.3); solo falta el device-QA con dos iPhone · `tickets/blocked/reverse-exit-on-a-reverted-account-rejects-the-retry.md`
- [ ] **J** · `tablero-tu-segundo-iphone-no-puede-activar-la-nu-w7w8` · El segundo iPhone no puede activar la nube; device-QA con la build del PR #422
- [ ] **J** · `tablero-tras-vaciar-los-datos-desde-otro-disposi-pb6r` · Tras vaciar desde otro dispositivo, widget, Siri y recordatorios siguen con datos del dueño; device-QA
- [ ] **J** · `tablero-borrar-un-gasto-de-la-bandeja-de-entrada-yneu` · La x de la Bandeja no borra · `tickets/qa/inbox-dismiss-x-does-not-delete-the-draft-for-good.md`
- [ ] **J** · `tablero-los-gastos-compartidos-planificados-apar-qo5b` · Gasto compartido planificado sale dos veces · `tickets/qa/shared-scheduled-expense-shows-twice-in-inbox.md`
- [ ] **J** · `tablero-al-compartir-una-imagen-a-yala-la-lectur-nxle` · Compartir una imagen no siempre arranca la lectura · `tickets/qa/share-image-reading-does-not-always-start.md`
- [ ] **J** · `tablero-la-lectura-de-imagen-pone-en-la-nota-tex-tkun` · La nota de la foto trae texto del banco · `tickets/qa/image-note-uses-bank-template-instead-of-merchant.md`
- [ ] **J** · `tablero-mejorar-el-registro-por-imagen-de-punta-g5wl` · Registro por imagen; **decidir propuesta A, B o C** · `tickets/qa/image-entry-end-to-end-redesign.md`
- [ ] **J** · `tablero-mejorar-el-registro-por-voz-de-punta-a-p-u58k` · Registro por voz; device-QA · `tickets/qa/voice-entry-end-to-end.md`
- [ ] **J** · `tablero-un-estado-de-cuenta-en-pdf-solo-se-lee-e-4j2s` · PDF de varias páginas y con contraseña · `tickets/qa/pdf-statement-reads-only-the-first-page.md`
- [ ] **J** · `tablero-ui-tres-tests-de-la-suite-advisory-falla-wsc6` · Tres tests de UI fallan siempre · `tickets/qa/advisory-ui-tests-fail-every-retry.md`
- [ ] **F** · `tablero-al-archivar-una-cuenta-sigue-contando-en-fmiy` · Cuenta archivada suma en el total · `tickets/qa/archived-accounts-still-count-in-the-panel-total.md`
- [ ] **F** · `tablero-decidir-tras-cancelar-la-entrada-con-la-069g` · «Borrar todo y continuar» en bucle con cambios de grupos · `tickets/qa/fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes.md`
- [ ] **F** · `tablero-la-qa-nocturna-se-corta-por-tiempo-cada-7zso` · QA nocturna cortada por tiempo · `tickets/qa/nightly-ui-suite-hits-its-110-minute-cap-every-night.md`

### 6.3 Fuera de esas columnas, pero bloquea igual

- [ ] **L** · `tablero-la-web-la-politica-y-la-ficha-dicen-que-i6tj` (en `backlog`) · Política y términos (§2)

### 6.4 Decidir si bloquean (`espera decisión`, prioridad `medium`)

Decidir esto es de **J**. Si alguna bloquea, pasa a §6.2.

- `tablero-al-tocar-un-segmento-de-una-grafica-con-5g94` · Tocar un segmento con exclusiones activas
- `tablero-con-datos-en-el-telefono-y-sin-icloud-es-gwfi` · «Es mi primera vez → privado» sin iCloud solo deja borrar o volver
- `tablero-decidir-tras-reintentar-una-migracion-fa-l36m` · Tras «Reintentar» una migración fallida, ¿vuelve a preguntar el borrado de iCloud?
- `tablero-una-foto-compartida-espera-sin-avisar-de-msje` · Una foto compartida espera detrás de una hoja abierta

---

## 7. Encontrado fuera del alcance

- **Textos de la app que contradicen el Modo Nube:** `profile.privacyTitle` y `profile.privacyDesc`
  («Tus datos nunca salen de tu dispositivo», `Yala/Resources/es.lproj/Localizable.strings:1151-1152`),
  `common.dataPrivacy` (`:507`) y `onboarding.privacyIcloud` (`:1832`). El revisor puede leerlos
  · ticket `in-app-privacy-copy-says-data-never-leaves-the-device` · **F**

## Cómo se midió

- Árbol: `git rev-parse HEAD` → `6937828ff`, igual que `origin/2.1`.
- Sin tracking ni crash: `grep -rE "ASIdentifierManager|ATTrackingManager|Sentry|Crashlytics|MXMetricManager|RevenueCat" Yala YalaShare YalaWidgets` → 0.
- Web en producción: `curl -sL https://yala-app.pe/privacy` y `/llms.txt`, comparado con `Web/public/llms.txt`.
- Tablero: `tablero listar --proyecto Yala --json`, filtrado por `version == 2.1`.
- Lo que vive en App Store Connect, la consola de CloudKit, Supabase de producción, Google Cloud y Vercel
  **no se ha consultado**: está marcado 🔲.
