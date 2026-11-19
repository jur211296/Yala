---
id: 2026-11-18-verificacion-google-sin-casa
status: backlog
priority: high
area: "correo-banco, atajo-banco, google-oauth, web"
created: 2026-11-18
updated: 2026-11-18
source: "encargo 2026-11-18 · Verificación de Google sin pagar CASA (decisión de Jürgen del 18-nov: no se paga la evaluación)"
---

# Registrar desde los avisos del banco sin el permiso restringido de Gmail

El 18-nov Google pidió una evaluación de seguridad ADA-CASA AL1 antes del 16-feb-2027 para verificar
`gmail.readonly` en el proyecto `yala-502622`. Jürgen decidió no pagarla. El análisis completo, con fuentes, la tabla
comparativa y los recorridos de cada alternativa, está en
`docs/analisis/2026-11-18-verificacion-google-sin-casa/` y en el artifact público https://claude.ai/artifact/TS9AE5C6A16WmDVzdP2GWB (la entrega; el README es su resumen).

## Lo medido

- **Nadie en producción usa Gmail.** La App Store (rama `1.0`, versión 2.2) usa Google solo para iniciar sesión
  (`openid`, `email`, `profile`; `additionalScopes: nil`). «Conectar Gmail» vive solo en el PR abierto de «Conectar
  Gmail» mínimo, detrás de `DEV_BUILD`, y nunca se mergeó.
- **2.3 ya trae dos caminos sin Gmail:** el correo del banco por reenvío a `auto+<código>@yalainbox.com` (MX de
  Cloudflare activos, medido con `dig` el 18-nov) y el atajo del banco (automatización de Atajos sobre la notificación
  del banco, medida en el iPhone 14 con iOS 27.2.1: corre bloqueado y sin preguntar).
- **Pedir la exención de CASA no se sostiene:** Google la exige si los datos de Gmail se guardan o viajan por un
  servidor, y con la cuenta en la nube el borrador sacado de Gmail se sincroniza a `inbox_drafts` con su texto.
- **La web publicada sí habla de Gmail:** sección 5 de la política, proveedores, conservación, derechos y términos,
  en 6 idiomas.

## Decisión de Jürgen tras el análisis (18-nov, en el chat de la sesión)

«Si requiere el pago, fuera. Nos quedamos con lo que tenemos.» «Conectar Gmail» queda fuera porque exige CASA, y el
registro automático sigue con lo que 2.3 ya trae: el atajo del banco y el reenvío a la dirección de Yala. En la sesión
del análisis no se implementó nada nuevo. Lo que queda abierto es la parte de Google (retirar el permiso en la
consola, contestar el correo y quitar la sección de Gmail de la política), que sigue en la card «Avisos del banco sin
Gmail» para su GO.

## Recomendación

1. **Ya (sin código de la app):** retirar `gmail.readonly` del proyecto, contestar a Google que se retira el permiso
   restringido y que solo queda el inicio de sesión (borrador en el análisis), cerrar el PR de «Conectar Gmail»
   mínimo y sacar la sección de Gmail de la política y los términos por hotfix de `1.0`.
2. **2.3:** el atajo del banco como camino principal y gratis (B2), con tres disparadores según cómo avisa cada banco:
   la notificación de su app, el SMS (Interbank, BBVA) o el correo en la app Mail (BCP, Yape), confirmado con avisos
   reales; y el reenvío como segundo camino, con guía por banco y lectura por reglas antes de la IA.
3. **Después (2.4):** traer el historial: el conector de IA que lee el Gmail de la persona con su propio permiso, y
   la importación del estado de cuenta.
4. **Descartado:** CASA, FinanceKit (no está en Perú), agregadores con clave bancaria y mantener Gmail en el
   proyecto de producción.

## Sesiones propuestas (sin encolar)

Ver «Sesiones de implementación» en el análisis. Las encola Jürgen o su bot cuando decida.
