# Tanda de QA de Jürgen · 2.3, build 8 (barrido del 24-nov-2026)

<!-- guion-check:inicio -->
> ✅ **Nada fuera:** los 43 de `tickets/qa/` y las cards «in qa» del tablero salen en el guion · comprobado el 2026-11-24 con `qa/scripts/guion-tanda-check.py`.
<!-- guion-check:fin -->

Lo que queda para tu iPhone después del barrido de la 2.3 antes de la build 8. El recorrido está en
[`barrido-2-3-antes-build-8/lista.md`](barrido-2-3-antes-build-8/lista.md) y la clasificación de cada card y ticket en
[`barrido-2-3-antes-build-8/clasificacion.md`](barrido-2-3-antes-build-8/clasificacion.md).

## Resumen

- Revisados: 25 cards y 23 tickets en QA, más los 16 PR mergeados desde la build 7.
- Cerrados con evidencia: 2 cards (fluidez de Estadísticas y rebote de Reportes) y 3 tickets.
- Probado a mano: iPhone 14 real (Device MCP, build optimizada), iPad Pro 13 y Duo cerrado simulados.
- Bugs nuevos: 2 cards de bug 2.3 con cierre autónomo (guía de Atajos en iOS 27 y «Ver detalle ›» del Panel).
- Para tu iPhone: las mismas 4 pruebas de la build 7 (9 cards), que siguen sin hacer. Nada nuevo entra a la tanda.
  Vistos buenos: 6, por su canal. En espera: 10. Decisión pendiente: 1.
- Tiempo del barrido: unas 2 h.

## Lo que bloquea la build 8

Nada. Los dos bugs nuevos no rompen un flujo principal: la guía de Atajos describe el Atajos de iOS 26 (quien siga la
guía en iOS 27 no encuentra los botones) y «Ver detalle ›» ya pasaba en la 2.2 publicada.

## Las pruebas, por montaje

Son las de la build 7, con la build 8 de TestFlight. Mismos pasos que en
[`tanda-qa-jurgen-2.3-barrido-antes-build-7.md`](tanda-qa-jurgen-2.3-barrido-antes-build-7.md); aquí, el resumen.

### 1. Entrar con Apple (Yala Dev y la web) — 10 min, no bloquea

Cards `188b`, `4yc7`, `ljz7`, `yzxs` y `vimy`. Lo retiene: no poder entrar es un flujo principal y entrar con Apple pide
tu Face ID; el simulador no inicia sesión con Apple.

1. iPhone 14, Yala Dev › bienvenida › «Entrar con Apple». **Hecho cuando** sale «Ya tienes una cuenta» o «Vamos a crear
   tu cuenta», con la nota de que Apple y Google con el mismo correo abren la misma cuenta.
2. Safari › `app.yala-app.pe` › «Entrar con Apple». **Hecho cuando** ves tu Panel con el mismo saldo que en el iPhone, y
   Panel, «+ Apuntar», Más › Pagos, Estadísticas y Grupos no se salen por la derecha.

### 2. Conecta tu IA de verdad — 10 min, no bloquea

Cards `r8hi` y `o9b0`. Lo retiene: pasa por tu cuenta de Claude y el conector de producción.

1. Build 8, cuenta de Yala: Ajustes › Tu IA › «Copiar» la dirección.
2. claude.ai › Ajustes › Conectores › Añadir conector personalizado › «Yala» › pega › Conectar › entra con Apple o Google.
3. En un chat de Claude: «apunta 25 de almuerzo en Yala». **Hecho cuando** la Bandeja trae ese borrador con la etiqueta
   «Claude» y Ajustes › Tu IA lista a Claude como conectada.

### 3. La prueba de Pro y la compra — 10 min, no bloquea

Cards `l1c5` y `ds65`. Lo retiene: StoreKit en Sandbox solo responde en TestFlight.

1. Build 8 encima. Termina Primeros pasos hasta la oferta del mes de Pro › «Probar un mes gratis» con el tester de
   Sandbox. **Hecho cuando** sale «¡Listo! Tienes Pro» y Ajustes › Yala Pro dice «Activo».

### 4. Volver a tu iCloud sin perder datos — 15 min, no bloquea

Card `b23b`. Lo retiene: perder datos; el espejo real de iCloud no existe en el simulador y pide entrar con Google.

1. Yala Dev «En tu iCloud» con datos › Ajustes › Dónde viven tus datos › «Pasar a tu cuenta de Yala» › Google. Reabre.
2. Crea «Prueba vuelta» de 10 y deja Yala abierta unos minutos en el Panel.
3. Dónde viven tus datos › «Volver a tu iCloud» › «Seguir» › «Volver a tu iCloud». Reabre.
4. **Hecho cuando** Registros sigue con todo, incluido «Prueba vuelta», sin «Datos no disponibles», y al rato dice
   «En tu iCloud».

## Pruebas de interfaz del barrido

`ExitoGruposBandejaCapturasUITests` (gasto de grupo y aprobar varios) en el iPhone 17 Pro simulado: ver `lista.md`. La
suite completa no se corrió en local (tope de 30 min): vale la nocturna.

## Lo que pasó a done

| id | Motivo | Evidencia |
|---|---|---|
| `to65` y su ticket de fluidez de Estadísticas | Probado en el iPhone 14 con la build optimizada y datos pesados | `lista.md`; `evidencia/iphone14/26-…`, `27-…` |
| `syj7` y su ticket del rebote de Reportes | No es grave y el gesto del ticket no rebota en el iPhone 14 | `evidencia/iphone14/04-reportes-sin-rebote.mp4`; `YalaTests/ReportesReboteEncabezado/` |
| `2026-11-24-exito-grupos-y-bandeja-como-personal` | Aprobar uno en el iPhone 14; grupo y varios en el simulador | `evidencia/iphone14/06-…`; `ExitoGruposBandejaCapturasUITests` |

## Lo que se queda

| id | Qué lo retiene |
|---|---|
| `2026-11-23-avisos-del-banco-claridad-y-region` | Su paso 3 falla en iOS 27.2: espera la card de bug `zyaf`; el paso 5 (compra real) va después |
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
