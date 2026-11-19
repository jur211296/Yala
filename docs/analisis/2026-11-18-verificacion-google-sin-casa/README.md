# Avisos del banco sin Gmail (18-nov-2026)

**La entrega es el artifact** (`artifact/index.html`, publicado en https://claude.ai/artifact/TS9AE5C6A16WmDVzdP2GWB). Este README es
su resumen para buscar en el repo. Contexto: Google pidió una evaluación CASA AL1 de pago antes del 16-feb-2027 para
verificar `gmail.readonly` en `yala-502622`, y Jürgen decidió no pagarla (`docs/DECISIONS.md`, entrada del 18-nov).

## Medido en el repo (18-nov, rama 2.3)

| Pieza | Estado | ¿Lee Gmail? |
|---|---|---|
| Iniciar sesión con Google (`CloudAuthService`, `additionalScopes: nil`) | App Store 2.2 y 2.3 | No |
| «Conectar Gmail» (`GmailBankAlertImporter`) | Solo en el PR abierto de «Conectar Gmail» mínimo, detrás de `DEV_BUILD`; nunca mergeado | **Sí, lo único** |
| Correo del banco por reenvío (`BankEmailClient`, `gateway/src/mail/`) | 2.3; MX de Cloudflare de yalainbox.com activos (`dig`); 5 correos de prueba y después Pro; exige la nube | No |
| Atajo del banco (`BankNoticeIntent`, `BankNoticeRules`) | 2.3; B0 y B1 hechos en el iPhone 14 (iOS 27.2.1); falta B2 | No |
| Política y términos (`Web/src/i18n/translations.ts`) | Publicados en `1.0` con la sección 5 de Gmail, 6 idiomas | Hay que retirarla |
| La extensión de compartir (`YalaShare`) | Acepta imágenes y un PDF, no texto | No |

**Por qué Google pide CASA, y por qué no vale pedir la exención:** Google exige la evaluación cuando los datos de Gmail se guardan o viajan por un servidor (developers.google.com/workspace/gmail/api/auth/scopes). «Conectar Gmail» lee en el iPhone, pero con la cuenta en la nube el borrador sale a nuestra base con su texto (`supabase-staging.ddl`, tabla `inbox_drafts`: `raw_text`, `evidence`). La exención solo valdría para iCloud privado.

Nadie de la App Store usa Gmail: la rama `1.0` no tiene ni el importador ni el reenvío ni el atajo. No se consultó
producción ni la consola de Google; el tope de usuarios sin verificar (3 de 100) es el medido el 23-oct.

## Recomendación

1. **Ya:** quitar `gmail.readonly` y apagar la API de Gmail en la consola, contestar a Google (borrador en inglés en
   el artifact), retirar la sección de Gmail de la política y los términos, y cerrar el PR de «Conectar Gmail».
2. **2.3:** atajo del banco (B2) como camino principal y gratis; reenvío como segundo camino, con remitentes por
   banco y lectura por reglas antes de la IA.
3. **2.4:** historial con el conector de IA y la importación del estado de cuenta; compartir un correo como texto.
4. **Descartado:** CASA, FinanceKit (no está en Perú), agregadores y open banking, Gmail en modo prueba.

Las fuentes oficiales de Google, Apple y los bancos están citadas en el artifact, sección «Fuentes».
