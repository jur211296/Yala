# Cambios legales web 2.0 — DRAFT para revisión humana

> ⚠️ **ESTE TEXTO ES UN BORRADOR (DRAFT).** Fue redactado para reflejar con precisión las funciones nuevas de Yala 2.0 (Yala IA con OpenAI y Grupos con CloudKit Sharing) y **debe pasar por revisión legal humana antes de publicar.** No es asesoría legal.

**Dónde vive:** el contenido legal renderizado está en `Web/src/i18n/translations.ts` (claves `privacy*` / `terms*`) y se muestra vía `PrivacyPage.astro` / `TermsPage.astro`. Se actualizó en **los 6 idiomas** (es, en, de, fr, it, pt). El archivo `src/pages/privacy_content.md` (referencia ES, no renderizada) también se actualizó para no contradecir.

**Motivo del cambio:** la versión anterior afirmaba textualmente *"No se envían montos, historial de gastos ni información personal"*. Con **Yala IA** eso dejó de ser cierto: el chat envía contexto financiero real a OpenAI. Mantener esa frase incumpliría la coherencia que Apple exige entre web ↔ app ↔ App Store Connect.

---

## A. Qué se envía realmente a OpenAI (fuente de verdad)

Verificado en `Yala/Services/Chat/FullFinancialContextBuilder.swift`. Cuando el usuario usa **Yala IA (chat)** — función **Pro**, con consentimiento explícito la primera vez — se envía a OpenAI el contexto financiero de los últimos ~13 meses:

- Montos (convertidos a la divisa preferida), ingresos/gastos por periodo, saldos por cuenta y saldo total.
- Nombres de **categorías y subcategorías** + totales y variaciones.
- **Nombres de comercios** derivados de las notas de transacciones (canonicalizados).
- **Nombres de cuentas** (y su tipo).
- **Etiquetas** (top 10), **presupuestos** (nombre, límite, gastado), **pagos programados/suscripciones**.
- Patrones (gasto por día de semana, reparto por "naturaleza" de gasto).
- País e idioma (para localizar la respuesta).

Además, las funciones Pro previas siguen igual: **voz** (audio + transcripción), **imágenes** (foto comprimida sin metadatos), **auto-categorización** (nombres de categorías). Tipos de cambio vía `exchangerate.host` (solo códigos de divisa).

**Postura de OpenAI sobre entrenamiento:** según la política de la **API** de OpenAI, los datos enviados por API **no se usan para entrenar modelos por defecto**. El texto lo refleja así. → **A confirmar por revisión legal** contra los términos vigentes de OpenAI al publicar.

**Alineación con el consent in-app (verificada 2026-06-14):** el texto de la web se redactó para ser consistente con el **consentimiento que el usuario acepta dentro de la app** (`Yala/Resources/*.lproj/Localizable.strings` → `aiConsent.chatMessage`), que enmarca el envío como *"un resumen de tu situación financiera: saldos y nombres de tus cuentas, totales por categoría, comercios frecuentes, presupuestos y pagos recurrentes"*. La web usa ese mismo marco y añade detalle propio de una política (subcategorías, etiquetas) — sin contradecir el consent ni declarar menos de lo que la app envía. La auditoría `AUDIT-appstore-guidelines.md` (raíz del repo) detalla qué envía `FullFinancialContextBuilder` y confirma esta lista. La versión anterior del consent in-app afirmaba falsamente *"account names are never shared"* (hallazgo #2 del audit) — ya corregida por la sesión de App Store.

---

## B. Política de Privacidad — cambios

### B.1 Sección 4 reescrita: "Yala IA y funciones inteligentes" (`privacyProText` + `privacyProTitle`)
- **Antes:** título "Funciones inteligentes"; afirmaba que solo se enviaban datos agregados y **"No se envían montos, historial de gastos ni información personal"**.
- **Ahora:** título "Yala IA y funciones inteligentes"; describe explícitamente que Yala IA (chat) **sí** envía el contexto financiero detallado (lista del punto A) a OpenAI, solo con consentimiento; mantiene voz/imagen/auto-categorización; aclara que OpenAI no entrena con datos de API, procesamiento puntual, sin copias en servidores propios, y que se puede usar Yala sin activar IA.
- **Por qué:** corrige la afirmación falsa y cumple disclosure honesto del tratamiento de datos financieros.

### B.2 Sección 5 NUEVA: "Grupos y gastos compartidos (Beta)" (`privacyGroupsTitle` + `privacyGroupsText`)
- Declara que gastos, saldos y nombres de miembros se comparten con los demás integrantes vía **CloudKit Sharing de Apple**; viajan/almacenan en iCloud de Apple (no en servidores propios); solo miembros ven el contenido; datos fuera del grupo no se comparten; Beta; se puede salir cuando se quiera.
- **Por qué:** Grupos introduce compartición de datos entre usuarios — requiere disclosure de qué/con quién/dónde.

### B.3 Renumeración
Al insertar Grupos como sección 5, se renumeraron: Analítica 5→6, Lo que NO hacemos 6→7, Tus datos 7→8, Cambios 8→9, Contacto 9→10. Fecha "Última actualización" → **Junio 2026**.

---

## C. Términos de Uso — cambios

### C.1 Sección 2 "Descripción del servicio" (`termsServiceText`)
- Añade que la app permite **dividir gastos en grupos** y **consultar a Yala IA** (asistente con IA). Mantiene "no es asesoría financiera".

### C.2 Sección 5 "Tus datos" (`termsDataText`)
- Amplía: las funciones de IA (Yala IA, voz, imagen) procesan datos puntualmente vía **OpenAI** cuando se activan; si se usan Grupos, se comparten ciertos datos (gastos, saldos, nombre) con los demás miembros vía **CloudKit de Apple**; sin acceso nuestro; remite a la **Política de Privacidad** (frase conservada literal para que el enlace siga funcionando).

### C.3 Sección 6 NUEVA: "Grupos y contenido compartido (Beta)" (`termsGroupsTitle` + `termsGroupsText`)
- Responsabilidad del usuario sobre el contenido que comparte y a quién invita; los miembros ven gastos/saldos/nombre; **Beta** (saldos orientativos, posibles errores); sin responsabilidad por disputas entre miembros ni por exactitud de datos compartidos.

### C.4 Renumeración
IP 6→7, Suscripciones 7→8, Limitación 8→9, Terminación 9→10, Cambios 10→11, Ley 11→12, Contacto 12→13. Fecha → **Junio 2026**.

---

## D. Coherencia en la home (no legal, pero relacionado)
- Copy de confianza `heroTrust`/`ctaTrust`: "100% privado" → **"Privado por diseño"** (con IA opt-in, "100%" podía leerse como engañoso).
- Sección Yala IA incluye **nota de transparencia** con link a Privacidad.
- 2 FAQ nuevas (datos de Yala IA / privacidad de Grupos) en home y soporte.

---

## E. 🚩 Flags para reconciliar FUERA de la web (acción del owner)

Apple compara web ↔ app ↔ App Store Connect. Estos puntos **no se tocaron** (fuera del alcance web) pero requieren decisión:

1. **`Yala/Resources/PrivacyInfo.xcprivacy` → `FinancialInfo`.** La sesión de App Store **ya añadió** `NSPrivacyCollectedDataTypeFinancialInfo` (linked, no-tracking, AppFunctionality) al manifiesto — alineado con el disclosure de la web. Pendiente del owner: (a) commitear ese cambio, y (b) reflejarlo en las **nutrition labels de App Store Connect** (Apple compara web ↔ app ↔ ASC). Reabrir la decisión **D-C** en `DECISIONS.md`. Detalle en `AUDIT-appstore-guidelines.md` (hallazgo #3).

2. **`App Store/metadata/description-*.md`** aún dicen *"no almacenamos nada en servidores… Tu información es tuya. Punto."* → matizar en ASC por Yala IA (OpenAI) y Grupos (CloudKit), para que la ficha del App Store no contradiga la web.

3. **Sub-procesador OpenAI:** confirmar si la política de privacidad debe **nombrar a OpenAI como sub-procesador** de forma más formal (lista de sub-procesadores / DPA) según GDPR/leyes aplicables (Yala lista mercados en EU: de/fr/it/pt-PT).

4. **Grupos + GDPR:** al compartir datos entre usuarios (CloudKit Sharing), revisar si aplica algún rol de responsable/encargado y si el texto Beta cubre la responsabilidad del usuario que invita.

5. **OpenAI "no entrena con datos de API":** confirmar contra los términos vigentes de la API de OpenAI a fecha de publicación (la postura puede cambiar; el texto cita "según su política de API").

---

## F. Texto fuente (para que el revisor edite directamente)
Todo el texto está en `Web/src/i18n/translations.ts`. Buscar las claves: `privacyProTitle`, `privacyProText`, `privacyGroupsTitle`, `privacyGroupsText`, `privacyAnalyticsTitle`…`privacyContactTitle` (renumeradas), `termsServiceText`, `termsDataText`, `termsGroupsTitle`, `termsGroupsText`, `termsIpTitle`…`termsContactTitle` (renumeradas), `privacyLastUpdate`, `termsLastUpdate`. Hay una entrada por idioma (es/en/de/fr/it/pt).
