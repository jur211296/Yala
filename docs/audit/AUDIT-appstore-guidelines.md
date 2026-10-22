# Audit — App Store Review Guidelines (Yala 2.0)

**Fecha:** 2026-06-14 · **Método:** 4 investigadores en paralelo (IAP, privacy/permisos, borrado/login, integraciones+OpenAI) + verificación manual de cada bloqueante para descartar falsos positivos.

## Veredicto
Sin bloqueantes de IAP, borrado de datos, login ni completitud — esas áreas **cumplen**. El riesgo de rechazo está **concentrado en un solo tema: la divulgación del uso de OpenAI con datos financieros**, que es además el área por la que Apple ya rechazó una vez (rechazo #2). Tres hallazgos de **alto riesgo de rechazo**, todos del mismo eje. Verificados en código, no especulación.

---

## 🔴 Alto riesgo de rechazo (verificados)

### 1. El copy público dice "todo en tu dispositivo / nada en servidores" — y se envía a OpenAI
- **Dónde:** `marketing/App Store/metadata/description-en.md:25` → *"Your financial data is stored exclusively on your device. We don't connect to banks, don't sell data, and store nothing on servers. Your information is yours. Period."* (y la frase equivalente en la web, `Web/src/i18n/translations.ts`).
- **Realidad:** el chat/voz/imágenes envían contexto financiero a OpenAI (`FullFinancialContextBuilder`, `ImageVisionService`, `TranscriptionParserService`).
- **Por qué rechaza:** Guideline 5.1.1/5.1.2 — Apple compara las afirmaciones de la ficha/política con el comportamiento real. "Exclusively on your device" + "store nothing on servers" es insostenible cuando se transmiten datos a un tercero.
- **Fix:** reescribir el copy de privacidad en la descripción de App Store Connect **y** en la web (lo cubre el chip de rediseño web #4), declarando el uso de OpenAI con claridad. Matiz defendible a conservar: OpenAI no entrena con los datos (política de API) y no hay servidores propios de Yala.

### 2. El texto del consent del chat es factualmente falso
- **Dónde:** `Yala/Resources/en.lproj/Localizable.strings:3496` (`aiConsent.chatMessage`):
  > *"...merchant names, amounts and dates of **relevant** transactions, and related budget status. Your full history, personal notes, and **account names are never shared**."*
- **Realidad (verificada):** [`FullFinancialContextBuilder.swift:330`](Yala/Services/Chat/FullFinancialContextBuilder.swift:330) envía `name: account.name`; además se manda un snapshot agregado amplio: ~15 meses de períodos, top categorías/subcategorías, top 20 merchants, presupuestos, pagos recurrentes, tags y top transacciones por subcategoría. Es mucho más que "transacciones relevantes", y **los nombres de cuenta SÍ se comparten** (contradice el texto al pie de la letra).
- **Por qué rechaza:** disclosure inexacto (5.1.1/5.1.2). Un reviewer que abra el chat y observe el tráfico, o que compare el texto con el comportamiento, lo detecta. Especialmente sensible dado el rechazo previo.
- **Fix:** reescribir `aiConsent.chatMessage` (y revisar `aiConsent.insightsMessage`) en los **16 locales** para reflejar honestamente qué se envía. Quitar la afirmación "account names are never shared" o dejar de enviarlos. Esto NO es falta de consent — el consent existe y es revocable (`chatConsentAlert`, `AIPrivacySettingsView`); el problema es solo el contenido del texto.

### 3. `PrivacyInfo.xcprivacy` no declara `FinancialInfo`
- **Dónde:** `Yala/Resources/PrivacyInfo.xcprivacy` — solo declara `AudioData` y `PhotosorVideos`.
- **Estado:** ya es una **decisión consciente diferida** (D-C en `DECISIONS.md`). Pero los 2 auditores de privacidad independientes la marcaron como riesgo, y dado que el chat transmite datos financieros a un tercero, la omisión es difícil de justificar ante Apple.
- **Recomendación:** re-evaluar D-C. Añadir la entrada `NSPrivacyCollectedDataTypeFinancialInfo` (linked, no-tracking, AppFunctionality) es barato y elimina un motivo de rechazo. Debe ir alineado con las nutrition labels de App Store Connect y con los fixes #1/#2.

---

## ✅ Falsos positivos descartados (verificados, NO actuar)
- **`NSCameraUsageDescription` faltante** — un agente lo marcó bloqueante. **Falso:** la app NO accede a la cámara; usa `PhotosPicker` (galería) en `ImageSelectionView`/`PersonalDetailsView`. El grep de captura directa (`UIImagePickerController`/`AVCaptureDevice`/`sourceType .camera`) salió vacío. No se necesita el string.
- **"No hay consent para el chat"** — **Falso:** existe `chatConsentAlert` gateado por `aiChatConsentAccepted` (`ViewModifiers.swift:357`, `DetailContainerView:747`), revocable desde `AIPrivacySettingsView`. El problema real es el **texto** (#2), no la ausencia.
- **`NSSiriUsageDescription` faltante** — la app usa **App Intents** (no SiriKit/`INPreferences`); App Intents no requiere ese purpose string. No aplica.

## 🟡 Menores
- **Copy del trial** podría ser más explícito sobre el cargo tras los 30 días (`ProTrialOfferSheet`), aunque la tarjeta de plan ya muestra "gratis 30 días, luego $X". Bajo.
- **API key de OpenAI en el binario** (`Info.plist:20` → `APIKeyService`): riesgo de **seguridad**, no de guideline. Ya documentado en D-C; corresponde al security review #2 (proxy backend).

## ✅ Cumple (verificado)
- **IAP / Suscripciones (3.1.1/3.1.2):** botón Restaurar en `SubscriptionView:105` y `ProTrialOfferSheet:112`; precio/periodo/qué incluye; links a Términos y Privacidad en el paywall; StoreKit 2 con manejo de cancelado/pendiente/error; `manageSubscriptionsSheet`; sin pagos alternativos.
- **Borrado de datos (5.1.1(v)):** `DataWipeService` borra los 15 modelos + preferencias + perfil; accesible en Perfil → Datos; confirmación multi-paso; coordinación cross-device por iCloud KV.
- **Sign in with Apple (4.8):** NO aplica — no hay login social de terceros (solo iCloud implícito). Sin demo account necesaria.
- **Completitud (2.1):** app completa, sin placeholders.
- **`ITSAppUsesNonExemptEncryption=false`** declarado (`Info.plist:111`).
- **Sin afirmaciones financieras reguladas:** el system prompt del chat prohíbe consejos de inversión.

---

## Cómo se conecta con el resto del release
Los 3 hallazgos altos son **el mismo problema visto en 4 superficies** (descripción ASC, web, consent in-app, manifest). Conviene arreglarlos en conjunto:
- **#1** → chip de rediseño web #4 (privacy/terms) + editar la descripción en App Store Connect.
- **#2** → fix de strings en los 16 locales (tarea de código acotada).
- **#3** → editar `PrivacyInfo.xcprivacy` + nutrition labels en ASC; reabrir D-C en `DECISIONS.md`.
- El **security review #2** ataca la causa de fondo de la API key (#menor) y del data-flow a OpenAI.
