Yala
# Construir «Comercios en común»: lista anónima de comercio a tipo, con las opciones recomendadas que eligió Jürgen
---
toca: gateway/src/comercios-comun/,gateway/test/comercios-comun/,gateway/migrations/0005_comercios_comun.sql,gateway/src/index.ts,Yala/Services/ComerciosEnComun/,Yala/App/Services/MerchantMemoryService.swift,Yala/App/Services/MerchantCanonicalizer.swift,Yala/App/Views/Profile/,YalaTests/ComerciosEnComun/,YalaUITests/ComerciosEnComun/,Web/src/pages/privacy.astro,Web/src/pages/en/privacy.astro,Web/src/pages/de/privacy.astro,Web/src/pages/fr/privacy.astro,Web/src/pages/it/privacy.astro,Web/src/pages/pt/privacy.astro,Yala/Resources/de.lproj/ComerciosEnComun.strings,Yala/Resources/en-GB.lproj/ComerciosEnComun.strings,Yala/Resources/en.lproj/ComerciosEnComun.strings,Yala/Resources/es-419.lproj/ComerciosEnComun.strings,Yala/Resources/es-AR.lproj/ComerciosEnComun.strings,Yala/Resources/es-ES.lproj/ComerciosEnComun.strings,Yala/Resources/es.lproj/ComerciosEnComun.strings,Yala/Resources/fr.lproj/ComerciosEnComun.strings,Yala/Resources/it.lproj/ComerciosEnComun.strings,Yala/Resources/ja.lproj/ComerciosEnComun.strings,Yala/Resources/nl.lproj/ComerciosEnComun.strings,Yala/Resources/pl.lproj/ComerciosEnComun.strings,Yala/Resources/pt-BR.lproj/ComerciosEnComun.strings,Yala/Resources/pt-PT.lproj/ComerciosEnComun.strings,Yala/Resources/pt.lproj/ComerciosEnComun.strings,Yala/Resources/zh-Hans.lproj/ComerciosEnComun.strings,tickets/backlog/2026-11-22-comercios-en-comun-construir.md,tickets/done/2026-11-22-comercios-en-comun-construir.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets


## Qué hacer
Jürgen eligió el 22-nov las opciones recomendadas de la propuesta (decisión registrada t1890u-2): artifact https://claude.ai/artifact/PsU8Pp6cwPbEPaBPLiw8tL, fuente `docs/propuestas/2026-11-22-historico-comercios/index.html` y ticket `tickets/done/2026-11-22-historico-comercios-compartido-propuesta.md`. Lee primero `decision/jurgen` en la base del artifact; si no hay nada guardado, usa todas las recomendadas del ticket. En resumen: se comparte el tipo de comercio de la lista cerrada, en D1 del gateway; el teléfono baja la lista entera; aporte semanal en lote sin hora ni importe; variante B (3 dispositivos, 7 días, acuerdo ≥75 %, dos votos de ventaja, 5 para cambiar); orden: tu memoria, luego la lista común, la IA y el banco de 666; la lista solo propone; aviso una vez y opción para salirse en Perfil. Escribe la política en `Web/` y deja el texto de la etiqueta de privacidad de la App Store en el cierre. Todo queda probado en desarrollo y staging: la migración D1 de producción, el deploy del gateway, la web publicada y la etiqueta de la App Store quedan como pasos para Dan con el OK de Jürgen. Usa el siguiente número de migración libre si 0005 ya existe.

## Reglas
- Antes de tocar nada, verifica contra `origin/2.3` que cada ticket siga pasando (varios son viejos). Si uno ya no pasa o ya está hecho, muévelo a done con la evidencia y sigue con los demás.
- Si un ticket resulta ser una decisión de diseño o de producto que solo Jürgen puede tomar, no la inventes: déjalo en backlog con la pregunta y las opciones con su recomendación, y anótalo en el cierre.
- Textos nuevos en su propia tabla `.strings` (la del toca), no en Localizable.strings ni L10n.swift, en los 16 idiomas y siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
- Si hace falta tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.
- Producción (iCloud Production, Supabase prod, gateway, web publicada) no se toca: déjalo probado en desarrollo y anotado para Dan, con el OK de Jürgen.
- Nada de pago.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre; no lo des por ocupado sin comprobarlo. En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA y sin saltarse hooks. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones (resueltas en autónomo, modo semi)

Medido en `origin/2.3` (e73702cc3). `decision/jurgen` del artifact está vacío → todas las recomendadas del ticket de la propuesta.

1. **Qué viaja**: `{comercio limpio, tipo}` del `VisionMerchantKind` (lista de la foto, la misma `PHOTO_MERCHANT_KINDS` del gateway). Fuera `rent` y `taxes`. Solo gastos; la subcategoría tiene que traducirse a UN solo tipo (traducción inversa de `MerchantKindSubcategory.match`).
2. **Quién aporta**: solo borradores capturados (voz, Siri, foto, captura de pantalla, aviso/correo del banco, Apple Pay, automatización). Fuera: manual, pagos programados, suscripciones, grupos y lo apuntado por el conector de IA (`aiConnector`: el nombre lo escribe una IA, no una lectura). Un comercio aportado no se repite.
3. **Dónde se engancha en la app**: dentro de `MerchantMemoryService` (en el toca). `suggest(for:)` consulta la lista común cuando la memoria no propone; así Apple Pay, banco, correo, voz, Bandeja y foto la reciben sin tocar cada uno. `updateMemory` gana un parámetro `source:` (por defecto `nil` = no aporta) y las tres llamadas lo pasan: única edición fuera del toca en esos ficheros.
4. **Orden**: memoria con su política › memoria que existe aunque no llegue al umbral (gana sobre la lista común, propone lo suyo) › lista común (solo `.suggest`, nunca `.autoAssign`) › IA › banco de 666.
5. **Servidor**: D1 del gateway, migración 0005 (libre). Rutas `POST /comercios-comun/aportes` y `GET /comercios-comun/lista` con el token de App Attest. Huella = HMAC del keyId con llave derivada de `JWT_SIGNING_SECRET` (sin secret nuevo que configurar). 7 días de uso = `attest_keys.created_at`; sin fila (token de desarrollo) solo vale fuera de producción. Tope 30 aportes por teléfono y semana. Variante B: 3 teléfonos, ≥75 %, dos de ventaja; cambiar uno publicado pide 5. **Sin cron**: la lista se recalcula al primer GET de cada día UTC (no toca `wrangler.toml`).
6. **Limpieza del nombre (B)**: si casa con el banco de 666 → la marca; si no, canónico de siempre sin números, sucursal/«SUC», ciudades de Perú y razón social. Vive en `Yala/Services/ComerciosEnComun/`.
7. **Estado local en un fichero JSON** (Application Support), no en SwiftData: un `@Model` nuevo es un campo de CloudKit y no hace falta sincronizar esto.
8. **Aviso una vez**: el aviso flotante de siempre (`DraftDiscardUndoNotice`) la primera vez que algo se encola, con «No aportar». La salida permanente: fila «Comercios en común» en Perfil junto a «Privacidad IA», con su pantalla. Recibir no se apaga.
9. **Línea «Así suele categorizarse X en Yala · Cambiar»**: en la tarjeta de «Esto leí» cuando la subcategoría del borrador es la que da la lista común y no hay memoria de ese comercio (se calcula al pintar, sin guardar nada en el borrador).
10. **Envío y descarga**: al volver a primer plano, lista una vez al día (ETag) y lote una vez a la semana en orden al azar. Un enganche de una línea en el arranque (fuera del toca, anotado).
11. **Web**: apartado nuevo en la política de los 6 idiomas de `Web/` (es, en, de, fr, it, pt), con el texto propuesto. Se publica cuando Jürgen pase la web a 1.0.
12. **Producción**: migración D1, deploy del gateway, web y etiqueta de privacidad quedan para Dan con el OK de Jürgen.
