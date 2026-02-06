# Privacy Policy / Política de Privacidad

---

## Español

**Última actualización:** 6 de febrero de 2026

### Introducción

Yala ("la aplicación", "nosotros") es una aplicación de finanzas personales diseñada para ayudarte a gestionar tus gastos, cuentas y presupuestos. Tu privacidad es importante para nosotros, y esta política explica cómo manejamos tu información.

### Datos que Almacenamos

Yala almacena la siguiente información financiera que tú ingresas voluntariamente:

- **Transacciones:** Montos, fechas, notas, categorías y subcategorías
- **Cuentas:** Nombres, tipos, divisas y saldos
- **Presupuestos:** Límites, períodos y umbrales de alerta
- **Pagos planificados:** Suscripciones y pagos recurrentes
- **Preferencias:** Idioma, divisa preferida, tema visual y configuraciones de notificación

Estos datos se almacenan en tu dispositivo usando tecnología de Apple (SwiftData) y se sincronizan automáticamente con tu cuenta de iCloud si tienes una (ver sección iCloud).

### Sincronización con iCloud

Si tienes una cuenta de iCloud activa en tu dispositivo, tus datos financieros se sincronizan automáticamente usando **CloudKit** (la base de datos privada de Apple). Esto significa:

- Tus datos se almacenan cifrados en los servidores de Apple asociados a tu cuenta de iCloud
- Solo tú puedes acceder a estos datos (base de datos privada de CloudKit)
- La sincronización permite acceder a tus datos desde múltiples dispositivos con la misma cuenta de iCloud
- Apple gestiona la seguridad y cifrado de los datos en tránsito y en reposo
- Nosotros no tenemos acceso a tus datos almacenados en iCloud

Si no tienes cuenta de iCloud, tus datos se almacenan exclusivamente en tu dispositivo.

### Servicios Externos

Yala se conecta a los siguientes servicios externos:

**1. API de tipos de cambio (exchangerate.host)**
- **Propósito:** Obtener tasas de cambio actualizadas para conversión entre divisas
- **Datos enviados:** Códigos de divisa (ej: USD, EUR, PEN) y rangos de fechas
- **No se envían:** Datos personales, montos de transacciones ni información financiera

**2. OpenAI API (funciones Pro)**
- **Transcripción de voz (Whisper):** Cuando usas la entrada por voz, tu grabación de audio se envía a los servidores de OpenAI para ser transcrita a texto. El audio no se almacena permanentemente en la app ni en nuestros servidores.
- **Análisis de imágenes (GPT-4o Vision):** Cuando usas la entrada por imagen, la foto de tu recibo o captura de pantalla se envía a los servidores de OpenAI para extraer los datos de la transacción. La imagen no se almacena permanentemente en la app ni en nuestros servidores.
- **Importante:** Estas funciones solo están disponibles para suscriptores Pro y requieren tu activación explícita.
- **Política de OpenAI:** Los datos enviados a la API de OpenAI están sujetos a la [política de privacidad de OpenAI](https://openai.com/privacy). OpenAI no usa datos enviados vía API para entrenar sus modelos.

**3. App Store (Apple)**
- **Propósito:** Gestión de suscripciones Pro (compra, renovación, cancelación)
- **Datos:** Apple gestiona la transacción de pago. Nosotros solo recibimos el estado de la suscripción, no tus datos de pago.

### Permisos de la Aplicación

Yala solicita los siguientes permisos, siempre con tu autorización explícita:

- **Micrófono:** Para grabar entrada de voz y crear transacciones (función Pro). Solo se graba cuando tú inicias la grabación.
- **Biblioteca de fotos:** Para seleccionar imágenes de recibos o capturas de pantalla bancarias (función Pro). Solo se accede cuando tú seleccionas una imagen.
- **Face ID / Touch ID:** Para proteger el acceso a la app con autenticación biométrica. Es opcional y configurable.
- **Notificaciones:** Para enviarte recordatorios de pagos planificados, alertas de presupuestos y reportes periódicos. Es opcional y configurable.

Yala **no accede** a:
- Tu ubicación
- Tus contactos
- Tu calendario
- Tus datos de salud

### Datos Compartidos con Terceros

No vendemos, alquilamos ni compartimos tus datos financieros con terceros para fines de marketing, publicidad o análisis.

Los únicos datos que salen de tu dispositivo son:
- Datos financieros sincronizados con tu iCloud privado (gestionado por Apple)
- Audio enviado a OpenAI para transcripción (solo si usas entrada por voz Pro)
- Imágenes enviadas a OpenAI para análisis (solo si usas entrada por imagen Pro)
- Códigos de divisa enviados a exchangerate.host para tipos de cambio

Yala:
- No utiliza servicios de análisis (analytics)
- No incluye publicidad
- No rastrea tu actividad
- No recopila identificadores de dispositivo

### Seguridad

Tus datos están protegidos por múltiples capas de seguridad:

- **Cifrado del dispositivo:** iOS cifra todos los datos en reposo
- **Cifrado en tránsito:** Todas las comunicaciones con servicios externos usan HTTPS
- **iCloud:** Datos cifrados por Apple en tránsito y en reposo
- **Autenticación biométrica:** Opción de bloquear la app con Face ID o Touch ID
- **Keychain de iOS:** Configuraciones sensibles se almacenan en el llavero cifrado del dispositivo
- **Protección de archivos:** Los archivos exportados usan cifrado completo de iOS (inaccesibles cuando el dispositivo está bloqueado)
- **Sandbox de Apple:** La app opera en un entorno aislado que impide el acceso de otras apps a tus datos

### Tus Derechos

Tienes control total sobre tus datos:

- **Acceso:** Puedes ver todos tus datos en la aplicación en cualquier momento
- **Exportación:** Puedes exportar tus datos en formato CSV o Excel (XLSX)
- **Eliminación:** Puedes borrar todos los datos desde Ajustes > Borrar datos
- **Desinstalación:** Si eliminas la aplicación, los datos locales se eliminan permanentemente. Los datos en iCloud se pueden gestionar desde los ajustes de iCloud de tu dispositivo.

### Menores de Edad

Yala no está dirigida a menores de 13 años. No recopilamos intencionalmente información de menores de edad.

### Cambios a Esta Política

Si actualizamos esta política de privacidad, publicaremos la nueva versión en https://yala-app.pe/privacy con una fecha de actualización revisada.

### Contacto

Si tienes preguntas sobre esta política de privacidad, puedes contactarnos en:

**Email:** admin@yala-app.pe
**Web:** https://yala-app.pe

---

## English

**Last updated:** February 6, 2026

### Introduction

Yala ("the app", "we") is a personal finance application designed to help you manage your expenses, accounts, and budgets. Your privacy is important to us, and this policy explains how we handle your information.

### Data We Store

Yala stores the following financial information that you voluntarily enter:

- **Transactions:** Amounts, dates, notes, categories and subcategories
- **Accounts:** Names, types, currencies and balances
- **Budgets:** Limits, periods and alert thresholds
- **Scheduled payments:** Subscriptions and recurring payments
- **Preferences:** Language, preferred currency, visual theme and notification settings

This data is stored on your device using Apple technology (SwiftData) and automatically syncs with your iCloud account if you have one (see iCloud section).

### iCloud Synchronization

If you have an active iCloud account on your device, your financial data automatically syncs using **CloudKit** (Apple's private database). This means:

- Your data is stored encrypted on Apple's servers associated with your iCloud account
- Only you can access this data (CloudKit private database)
- Syncing allows you to access your data from multiple devices with the same iCloud account
- Apple manages the security and encryption of data in transit and at rest
- We do not have access to your data stored in iCloud

If you don't have an iCloud account, your data is stored exclusively on your device.

### External Services

Yala connects to the following external services:

**1. Exchange Rate API (exchangerate.host)**
- **Purpose:** Obtain updated exchange rates for currency conversion
- **Data sent:** Currency codes (e.g., USD, EUR, PEN) and date ranges
- **Not sent:** Personal data, transaction amounts or financial information

**2. OpenAI API (Pro features)**
- **Voice transcription (Whisper):** When you use voice input, your audio recording is sent to OpenAI's servers for transcription to text. Audio is not permanently stored in the app or on our servers.
- **Image analysis (GPT-4o Vision):** When you use image input, your receipt photo or screenshot is sent to OpenAI's servers to extract transaction data. Images are not permanently stored in the app or on our servers.
- **Important:** These features are only available to Pro subscribers and require your explicit activation.
- **OpenAI Policy:** Data sent to the OpenAI API is subject to [OpenAI's privacy policy](https://openai.com/privacy). OpenAI does not use API data to train its models.

**3. App Store (Apple)**
- **Purpose:** Pro subscription management (purchase, renewal, cancellation)
- **Data:** Apple manages the payment transaction. We only receive the subscription status, not your payment data.

### App Permissions

Yala requests the following permissions, always with your explicit authorization:

- **Microphone:** To record voice input and create transactions (Pro feature). Recording only occurs when you initiate it.
- **Photo Library:** To select receipt images or banking screenshots (Pro feature). Access only occurs when you select an image.
- **Face ID / Touch ID:** To protect app access with biometric authentication. Optional and configurable.
- **Notifications:** To send you scheduled payment reminders, budget alerts and periodic reports. Optional and configurable.

Yala **does not access:**
- Your location
- Your contacts
- Your calendar
- Your health data

### Data Shared with Third Parties

We do not sell, rent, or share your financial data with third parties for marketing, advertising or analytics purposes.

The only data that leaves your device is:
- Financial data synced with your private iCloud (managed by Apple)
- Audio sent to OpenAI for transcription (only if you use Pro voice input)
- Images sent to OpenAI for analysis (only if you use Pro image input)
- Currency codes sent to exchangerate.host for exchange rates

Yala:
- Does not use analytics services
- Does not include advertising
- Does not track your activity
- Does not collect device identifiers

### Security

Your data is protected by multiple layers of security:

- **Device encryption:** iOS encrypts all data at rest
- **Encryption in transit:** All communications with external services use HTTPS
- **iCloud:** Data encrypted by Apple in transit and at rest
- **Biometric authentication:** Option to lock the app with Face ID or Touch ID
- **iOS Keychain:** Sensitive settings are stored in the device's encrypted keychain
- **File protection:** Exported files use iOS complete encryption (inaccessible when device is locked)
- **Apple Sandbox:** The app operates in an isolated environment that prevents other apps from accessing your data

### Your Rights

You have complete control over your data:

- **Access:** You can view all your data in the app at any time
- **Export:** You can export your data in CSV or Excel (XLSX) format
- **Deletion:** You can delete all data from Settings > Delete data
- **Uninstallation:** If you delete the app, local data is permanently removed. iCloud data can be managed from your device's iCloud settings.

### Children

Yala is not intended for children under 13 years of age. We do not intentionally collect information from minors.

### Changes to This Policy

If we update this privacy policy, we will post the new version at https://yala-app.pe/privacy with a revised update date.

### Contact

If you have questions about this privacy policy, you can contact us at:

**Email:** admin@yala-app.pe
**Web:** https://yala-app.pe

---

*This privacy policy is effective as of February 6, 2026.*
