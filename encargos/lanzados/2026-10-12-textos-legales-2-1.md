# Textos legales 2.1: política de privacidad y términos que cuentan la verdad del código

Cards: bis6 («La política y los términos no cuentan el Modo Nube, los identificadores ni el borrado de cuenta») e i6tj («La web, la política y la ficha dicen que Grupos viaja por iCloud; con el rediseño es una cuenta en la nube»). Cierre: propuesta para revisión (Lola + Jürgen aprueban el PR). Bloquea el envío de 2.1.

## Contexto
La política y los términos de yala-app.pe (`Web/src/i18n/translations.ts`, textos sin tocar desde el 2026-09-04 en 2.1 y desde junio en 1.0) dicen cosas falsas sobre 2.1. Jürgen decidió el 2026-10-12 que una sesión de Frank escribe el borrador en un PR; Lola y Jürgen lo revisan; basta la aprobación de Jürgen (sin abogado). Excepción explícita a «Web/ es territorio de Lola» solo para esta tarea.
Lee primero: `tickets/backlog/privacy-policy-and-terms-miss-cloud-mode-identifiers-and-account-deletion.md`, `tickets/backlog/session-redesign-web-and-store-copy.md`, `docs/RELEASE-CHECKLIST-2.1.md` §2, `Yala/PrivacyInfo.xcprivacy` (PR #446), `Yala/Services/CloudSync/CloudConsentText.swift`, `storage.consent.*` en `Yala/Resources/es.lproj/Localizable.strings`.

## Qué se pide
Reescribir política y términos (bloques `privacy*` y `terms*`, y las frases ligadas de FAQ/home que contradigan la política: `faq1A`, `v3Priv1`, `v3CtaNote`, límites del plan gratis `pricingFree1`, `faq7A`, `v3FreeDesc`) en los **6 idiomas** (es, en, de, fr, it, pt), con fecha **«Octubre 2026»**. Todo lo que diga el texto debe salir del código y la config, no del marketing. Cada afirmación nueva, con cita `fichero:línea` en la descripción del PR.

Errores a corregir (mínimo):
1. «Sin registro» / «no requiere crear una cuenta»: el Modo Nube y Grupos piden cuenta de Apple o Google.
2. «No tenemos acceso»: en Modo Nube el equipo puede ver los datos; no hay cifrado de extremo a extremo (decirlo igual que la app).
3. «Todo vive en el dispositivo y en iCloud»: explicar los dos modos (privado/iCloud vs. nube) y Grupos como cuenta en nuestro servidor.
4. «No recopilamos identificadores»: IDFV, clave de App Attest, token APNs, hash de instalación (y lo que encuentres; cuadrar con PrivacyInfo.xcprivacy y las etiquetas de App Privacy de la checklist).
5. Grupos «mediante CloudKit»: ahora es backend de Yala.
6. IA «a OpenAI»: pasa antes por nuestro gateway, que guarda metadatos sin contenido (`gateway/src/ai/handler.ts`); decir qué se guarda y cuánto tiempo si el código lo fija.
7. Plan gratis «2 cuentas»: el código da 4 (`FeatureGateService.swift`); verifica también presupuestos.
8. Añadir «Eliminar mi cuenta» dentro de la app y qué borra (`AccountDeletionService.swift`); que borrar la app no borra lo que está en la nube.
9. Añadir el **conector MCP para Claude** (`mcp/`): qué datos expone, cómo se autoriza (OAuth), cómo se revoca.
10. Lista de **proveedores (encargados) con país/región**, verificados en código y config: Supabase, Cloudflare, OpenAI, Vercel, Apple, Google y cualquier otro que el código use de verdad (busca en `gateway/`, `mcp/`, `wrangler.toml`, `supabase/`, SDKs de la app; p. ej. analítica, crash reporting, tasas de cambio). Si un país/región no se puede verificar en el repo, márcalo «no verificado» en el PR, no lo inventes.
11. Retención y derechos (acceso, exportación, borrado) acordes al código.
12. Nada de TelemetryDeck u otros restos que el código ya no use.

## Qué NO tocar
- Código de la app, gateway, mcp, App Store Connect, ficha y capturas de la tienda.
- **NO cambiar la rama de producción de Vercel ni desplegar nada.** Eso lo hace Jürgen tras aprobar (déjalo como paso en la descripción del PR: «tras merge, cambiar la rama de producción de Vercel de 1.0 a 2.1 y comprobar /privacy y /terms»).
- No tocar 1.0.

## Reglas de build y Mini
Sin xcodebuild ni simulador (solo Web/). En `Web/`: `npm ci` y `npm run build` (o el script que use) deben pasar; revisa las 12 páginas (6 idiomas × privacy/terms) en el build local o con `npm run preview`, con capturas de antes/después de /privacy y /terms en es y en en en `~/Claude/worktrees/_capturas/<fecha>-textos-legales-2-1/`. Carga de la Mini < 8; no compite con la sesión viva.

## Gate tras el CI del PR anterior
Puede arrancar con la sesión de 0ekl viva (no compila iOS). Antes de abrir el PR: `git fetch origin && git rebase origin/2.1`.

## PR a 2.1
Un PR contra 2.1, **sin auto-merge**: lo aprueban Lola y Jürgen. Descripción en lenguaje de usuario: tabla «antes / después» por afirmación, citas al código, lista de proveedores con país y fuente, lo no verificado, y el paso de Vercel pendiente para Jürgen. Mueve los tickets a in qa en el mismo PR.

## Cómo se sabe
Ninguna frase de la política o los términos contradice el código; los 12 errores anteriores corregidos en los 6 idiomas; fecha «Octubre 2026»; build de Web/ verde; PR abierto contra 2.1 esperando aprobación de Jürgen; nada desplegado.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · El conector de Claude solo existe en staging (`mcp/wrangler.toml:4`) y la app no tiene pantalla para él. ¿Entra en la política?** → Sí, como sección propia que dice que está en pruebas y aún no abierto al público, y cómo funcionará: solo lectura, OAuth con la cuenta de Yala, caducidad a 30 días sin uso y 90 como máximo, revocable desde Claude, cortado al borrar la cuenta.
Por qué: el encargo lo pide y decir cómo trata los datos antes de abrirlo no es fabricar una función. Alternativa descartada: describirlo como disponible (falso hoy) u omitirlo (incumple el punto 9).

**D2 · País de cada proveedor.** → En el texto solo va la región que el repo verifica: Supabase en us-east-1, EE. UU. (`gateway/wrangler.toml:93-94`, `qa/cloud/README.md:1318`). Para OpenAI, Cloudflare, Vercel, Apple, Google y exchangerate.host el texto dice qué hace cada uno sin país, y el PR los lista como «no verificado».
Por qué: el encargo prohíbe inventarlo. Alternativa descartada: poner el país de la sede de cada empresa, que no sale del código.

**D3 · Qué claves de FAQ y home entran.** → Las seis que nombra el encargo (`faq1A`, `faq7A`, `v3Priv1`, `v3CtaNote`, `pricingFree1`, `v3FreeDesc`) más `faq9A` (Grupos por CloudKit, la cubre el ticket i6tj) y `v3Priv3` (forma parte de las mismas «tres frases» que `v3Priv1` y es falsa: el modo nube, Grupos y la analítica también sacan datos del teléfono). El resto (`faq3A`, `v3Faq3A`, `faq6A`, `v3Faq4A`, `llms.txt`, claves muertas) va a «Encontrado» para Lola.
Por qué: el criterio del encargo es «frases ligadas que contradigan la política»; esas dos lo hacen de frente. Alternativa descartada: barrer toda la web, que es territorio de Lola.

**D4 · Hacen falta secciones nuevas y los componentes tienen las claves fijadas.** → Se tocan `PrivacyPage.astro` y `TermsPage.astro` para añadir las secciones (cuenta en la nube, conector de Claude, identificadores, proveedores, retención) con el mismo marcado de las existentes. No se cambia el diseño.
Por qué: sin eso las claves nuevas no se pintan. Alternativa descartada: meter todo en las claves existentes, que deja secciones de 2.000 caracteres sin títulos.

**D5 · La exportación del plan gratis solo permite semana o mes (`SharedModels.swift:185-190`).** → La política lo dice tal cual y ofrece escribir a admin@yala-app.pe para pedir una copia completa. Se apunta en «Encontrado» como riesgo legal (portabilidad tras pago).
Por qué: la política no puede prometer «exporta todo» si el código no lo deja. Alternativa descartada: cambiar el código (fuera de alcance).

**D6 · Volver a iCloud no borra la copia del servidor (`qa/cloud/README.md:255-257`).** → La política lo dice: la copia queda congelada en nuestros servidores hasta que elimines la cuenta.
Por qué: es dónde viven los datos de la gente. Alternativa descartada: callarlo porque la app dice «sin perder nada» (eso es cierto, pero no cuenta lo que se queda).

**D7 · Lo que el código no fija (copias de seguridad de Supabase, retención de logs de Cloudflare, retención de OpenAI).** → No se promete plazo. El texto dice lo que el código sí fija (90 días de analítica, 30/90 días del conector, invitaciones a 30 días) y el PR lista lo no verificado.
Por qué: un plazo inventado es peor que ninguno. Alternativa descartada: copiar los plazos públicos de cada proveedor.

**D8 · La analítica propia no se puede desactivar.** → Se dice en la política.
Por qué: la versión anterior lo daba a entender opcional («señales mínimas»), y el código no tiene interruptor. Alternativa descartada: omitirlo.

**D9 · Fecha.** → «Octubre 2026» traducida en cada idioma (October, Oktober, Octobre, Ottobre, Outubro).

**D10 · Tickets y tablero.** → Los dos tickets pasan a `tickets/qa/` con `status: qa` en este PR; las cards bis6 e i6tj a `in qa`. La parte de i6tj que toca la ficha y las capturas de la tienda queda anotada en el ticket como pendiente de Lola.
Por qué: el encargo lo pide. El ticket i6tj cubre también la ficha, que no se toca aquí.

## Paso 0 bis — correcciones de Lola (2026-10-12, con la delegación de Jürgen)

> Lola aprobó el texto con correcciones y autorizó el merge con CI verde. Lista entera en
> `~/Claude/tmp-frank/textos-legales-2-1-correcciones.md`. Supersede a D1, D3 (en lo que dejaba fuera), D5 y D7.

**D11 · Exportación del plan gratis.** → Todo gratis: todos los períodos (también «Todo el tiempo» y «Personalizado»), en CSV y en Excel. Se retira la función Pro `exportExtendedPeriods`, la insignia y la oferta del selector, y el paso «Exportar sin límites» del tour Pro.
Por qué: lo contestó Lola (opción 1) al preguntar. Su encargo decía «formatos avanzados siguen en Pro», pero Excel ya era gratis (`ExportSummaryStepView.swift:172-182`) y la única puerta era el período (`SharedModels.swift:185-190`). Alternativa descartada: pasar Excel a Pro, que quitaba algo a los usuarios gratis.

**D12 · El ancla `coachMarkAnchor("proExportExtended")` de `ProfileView` se queda, huérfana.** → No se toca `ProfileView`.
Por qué: es inofensiva (solo registra un marco que nadie lee) y tocar `ProfileView` arrastra 40 suites de XCUITest al gate. Alternativa descartada: borrarla y correr las 40.

**D13 · Conector de Claude.** → Fuera de la política, los términos y la web hasta que se abra (supersede D1).

**D14 · Fotos.** → Se envían sin metadatos: el JPEG se reescribe con ImageIO sin propiedades. ImageIO deja siempre un `{Exif}` con el ancho y el alto en píxeles, y no se puede quitar (medido); el test lo admite y nada más.

**D15 · Copias de seguridad de Supabase.** → «hasta 7 días» (supersede D7 en ese punto). La cifra viene de la medición que cita Lola; en esta sesión el token de gestión de `~/Secrets/yala-supabase-mgmt` devolvió «Invalid access token» y no se pudo volver a medir.

**D16 · Claves sin uso.** → Se borran las tres que nombra Lola (`privacyNot3`, `groupsBullet3`, `groupsNote`) y otras tres sin uso que decían algo falso: `groupsSubtitle` (Grupos «vía tu iCloud»), `pricingPro7` y `howStep2Desc` (auto-categorización).

**D17 · `Web/privacy_content.md`.** → Se borra: nada lo usa y es una copia vieja de la política que sigue nombrando TelemetryDeck.

**D18 · La ficha de la App Store («45+ divisas», en `marketing/`).** → No se toca: es territorio de Lola.
