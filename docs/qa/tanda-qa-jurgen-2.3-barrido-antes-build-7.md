# Tanda de QA de Jürgen · 2.3, build 7 (barrido del 23-nov-2026)

Lo que queda para tu iPhone después del barrido de la 2.3 antes de la build 7. El detalle del recorrido está en
[`barrido-2-3-antes-build-7/lista.md`](barrido-2-3-antes-build-7/lista.md) y la clasificación de cada card y ticket en
[`barrido-2-3-antes-build-7/clasificacion.md`](barrido-2-3-antes-build-7/clasificacion.md).

## Resumen

- Revisados: 61 cards y 64 tickets en QA, más los 37 PR mergeados desde la build 6.
- Cerrados con evidencia: 64 (los 60 de la clasificación y 4 que el barrido probó en el iPhone 14 o el simulador:
  `m43b`, `lplc`, `lhxq` y `s591`).
- Probado a mano: iPhone 14 real (Device MCP), iPhone SE e iPad Pro 11 simulados. El Duo no se pudo crear en la Mini.
- Para tu iPhone: 4 pruebas (11 cards). Vistos buenos: 6, por su canal. En espera: 10. Decisión pendiente: 1.
- Tiempo del barrido: unas 2 h.

## Lo que bloquea la build 7

Nada. El esquema de producción de CloudKit con el límite de la tarjeta entró en 2.3 a las 13:31 (PR 1137), así que la
comprobación previa de la subida ya no se frena por él.

## Las pruebas, por montaje

### 1. Entrar con Apple (Yala Dev y la web) — 10 min, no bloquea la build 7

Cards `188b`, `4yc7`, `ljz7`, `yzxs` y `vimy`; ticket `onboarding-2-3-single-provider-access`. Lo retiene: no poder entrar es un flujo principal y entrar con Apple pide
tu Face ID; el simulador no inicia sesión con Apple. Con Google ya se vio el 15-nov.

1. En el iPhone 14, Yala Dev › en la bienvenida, «Entrar con Apple». **Hecho cuando** sale «Ya tienes una cuenta» o
   «Vamos a crear tu cuenta», con la nota de que Apple y Google con el mismo correo abren la misma cuenta.
2. Safari › `app.yala-app.pe` › «Entrar con Apple». **Hecho cuando** ves tu Panel con el mismo saldo que en el iPhone.
3. En la misma web, recorre Panel, «+ Apuntar», Más › Pagos, Estadísticas y Grupos. **Hecho cuando** nada se sale por la
   derecha ni corta importes (card `vimy`).
4. En un ordenador, `app.yala-app.pe` › «Entrar con tu iPhone» y escanea el código con la cámara del iPhone.

### 2. Conecta tu IA de verdad — 10 min, no bloquea

Cards `r8hi` y `o9b0`; tickets `2026-11-22-conecta-tu-ia-diseno`, `ai-connector-drafts-in-the-inbox` y `claude-mcp-consent-with-apple-and-google` (sus pasos 1 y 6, la dirección y la puerta en iCloud, ya los hizo el barrido). Lo retiene: es la puerta de un usuario real a lo nuevo de la 2.3 y pasa por tu cuenta de Claude.

1. Con la build 7 de TestFlight, en una cuenta de Yala (no en iCloud): Ajustes › Tu IA › «Copiar» la dirección
   (`https://mcp.yala-app.pe/mcp`).
2. En claude.ai › Ajustes › Conectores › Añadir conector personalizado › nombre «Yala» y pega la dirección › Conectar ›
   acepta el permiso › entra con Apple o Google. La página de permiso cabe sin desplazar de lado, con «Yala × Claude»
   arriba y los botones de Apple y Google con sus logos.
3. En un chat de Claude: «apunta 25 de almuerzo en Yala».
4. **Hecho cuando** en el iPhone la Bandeja trae ese borrador con la etiqueta «Claude», y Ajustes › Tu IA lista a Claude
   como conectada (puede tardar un minuto), con el chip «De tu IA». Tócale «Desconectar» y comprueba que Claude pide
   volver a conectar.

### 3. La prueba de Pro y la compra — 10 min, no bloquea

Cards `l1c5` y `ds65`; tickets `onboarding-2-3-getting-started-complete-and-pro-trial` y
`2026-11-20-primeros-pasos-paso-7-implementacion`. Lo retiene: no poder pagar; StoreKit en Sandbox solo responde en TestFlight.

1. Instala la build 7 de TestFlight encima. Termina Primeros pasos hasta la oferta del mes de Pro.
2. «Probar un mes gratis» › la hoja de Apple con el tester de Sandbox. **Hecho cuando** sale «¡Listo! Tienes Pro» y
   Ajustes › Yala Pro dice «Activo».

### 4. Volver a tu iCloud sin perder datos — 15 min, no bloquea

Card `b23b`, ticket `reverse-on-the-iphone-left-the-local-store-empty`. Lo retiene: perder datos, y el espejo real de
iCloud no existe en el simulador; además pide entrar con Google.

1. Yala Dev en el iPhone 14 «En tu iCloud» con datos. Ajustes › Dónde viven tus datos › «Pasar a tu cuenta de Yala» ›
   «Continuar con Google». Reabre cuando lo pida.
2. Crea un registro «Prueba vuelta» de 10 y deja Yala abierta unos minutos en el Panel.
3. Ajustes › Dónde viven tus datos › «Volver a tu iCloud» › «Seguir» › «Volver a tu iCloud». Reabre.
4. **Hecho cuando** Registros sigue con todos tus movimientos, incluido «Prueba vuelta», sin «Datos no disponibles», y al
   rato «Dónde viven tus datos» dice «En tu iCloud».

## Pruebas de interfaz del barrido

Diez suites de lo nuevo, juntas sobre la 2.3 con todo mergeado (iPhone 17 Pro simulado): ver el resultado en la lista.
La suite completa no se corrió en local (tope de 30 min de pruebas de interfaz): vale la nocturna.

## Lo que pasó a done

| id | Motivo | Evidencia |
|---|---|---|
| `m43b` (Nuevo registro B1 y pantalla de éxito) | Probado en el iPhone 14: éxito en los cuatro guardados seguidos | `NuevoRegistroExitoSiempreUITests`; `evidencia/iphone14/03-…`, `04-…` |
| `lplc` (Vaciar mis datos abría Exportar) | Probado en el iPhone 14, 3 de 3 | `WipeButtonOwnTapWiringTests`; `evidencia/iphone14/23-…` |
| `lhxq` (Pantalla Tu IA) | Probado en el iPhone 14, el SE y el iPad, con la demo de conectadas y «Desconectar» | `ConectaTuIAUITests`; `evidencia/se/05-…` a `08-…`, `ipad/05-…` |
| `s591` (Eliminar mi cuenta en iCloud privado) | Guion entero del ticket en el iPhone 14 | `evidencia/iphone14/18-…` a `22-…` |
| Las 60 de la clasificación | Ver la tabla «Done» de `clasificacion.md`: caso de la §2, motivo y test o captura de cada una | `barrido-2-3-antes-build-7/clasificacion.md` |

## Lo que se queda

| id | Qué lo retiene |
|---|---|
| `188b`, `4yc7`, `ljz7`, `yzxs`, `vimy` · `onboarding-2-3-single-provider-access` | §4: entrar con Apple (Face ID) y la web real; prueba 1 |
| `r8hi`, `o9b0` · `2026-11-22-conecta-tu-ia-diseno`, `ai-connector-drafts-in-the-inbox`, `claude-mcp-consent-with-apple-and-google` | §4: la cuenta de Claude de Jürgen y el conector de producción; prueba 2 |
| `l1c5`, `ds65` · `onboarding-2-3-getting-started-complete-and-pro-trial`, `2026-11-20-primeros-pasos-paso-7-implementacion` | §4: StoreKit Sandbox solo en TestFlight; prueba 3 |
| `b23b` · `reverse-on-the-iphone-left-the-local-store-empty` | §4: pérdida de datos con el espejo real de iCloud y Google; prueba 4 |
| `ea78` · `insights-small-recurring-spending-card` | §2.6: visto bueno del texto y el sitio de «Gastos hormiga» |
| `9nn7` · `scheduled-payments-show-subscription-logos` | §2.6: visto bueno de los logos |
| `y6du` · `new-record-suggests-previous-descriptions` | §2.6: visto bueno de las sugerencias |
| `v466` | §2.6: visto bueno de que Yala IA pregunte la cuenta |
| `fu74` · `group-expense-from-a-receipt-with-ai` | §2.6: Jürgen quiere refinar la experiencia |
| `onboarding-sigue-los-estilos-del-resto-de-la-app` | §2.6: visto bueno de los estilos de la bienvenida |
| `3w7z`, `i9d8` · `onboarding-2-3-bank-email-step` | En espera: buzón y gateway de correo (Jürgen o Dan) |
| `vfg1` · `cloud-activation-time-is-unmeasured-between-the-claim-and-the-cutover` | En espera: una activación real con cuenta nueva |
| `pv2l` · `2026-11-21-ia-ampliada-produccion-navegadores-publicada` | En espera: despliegue de Dan y la 2.3 en la tienda |
| `j93f` | En espera: credenciales de staging |
| `3z6j` | En espera: gateway en producción y una semana de datos |
| `dyhx` · `own-telemetry-panel-by-sections` | En espera: despliegue de la telemetría propia |
| `vfsf` | En espera: es de marketing (Lola) |
| `2026-11-22-cuenta-limite-tarjeta-campo-sincronizado` | En espera: el límite sincronizado entre dos aparatos con la misma cuenta de iCloud |
| `siri-free-users-on-device-model-awaits-decision` | Decisión pendiente de Jürgen |
