# Clasificación de lo que está en QA — barrido 2.3 antes de la build 8 (24-nov-2026)

Base: `origin/2.3` en `472b7d780`. Fuentes: 25 cards «in qa» del tablero (14:00 Lima) y 23 tickets de `tickets/qa/`.
Desde el barrido de la build 7 entraron 4 tickets y 2 cards nuevos (marcados con ★); el resto sigue con el destino y el
motivo de `docs/qa/barrido-2-3-antes-build-7/clasificacion.md`, comprobado que su código no cambió en estos 16 PR.

## Recuento

| Destino | Items |
|---|---|
| done con evidencia del barrido | 2 cards + 3 tickets |
| sigue en QA, a la espera de su card de bug | 1 ticket |
| iPhone de Jürgen (filtro doble §4) | 9 cards en 4 pruebas (las mismas de la build 7) |
| visto bueno de Jürgen (§2.6) | 6 |
| en espera (infra, credencial, marketing o despliegue) | 10 |
| decisión pendiente | 1 |

## Lo nuevo (★)

| id | Qué | Destino | Motivo y evidencia |
|---|---|---|---|
| ★ `to65` · `2026-11-23-estadisticas-fluidez-scroll-y-chips` | Cambiar de chip y el scroll de Estadísticas | done | Probado en el iPhone 14 con la build optimizada y ~3 veces la semilla `pesado`: volver a cada pestaña es inmediato (3 de 3), scroll largo bien, el período nuevo llega a las tres pestañas. `lista.md`; `evidencia/iphone14/26-…`, `27-…` |
| ★ `syj7` · `2026-11-23-reportes-rebote-encabezado-comparativa-flujo` | Reportes sin rebote arriba | done | No es grave (§4.1): una animación, no datos ni acceso. Probado en el iPhone 14 con el gesto del ticket (dedo quieto 4 s en el umbral, subir de golpe): sin vaivén, en Comparativa y Flujo de caja. Pin: `YalaTests/ReportesReboteEncabezado/`. `evidencia/iphone14/04-reportes-sin-rebote.mp4` |
| ★ `2026-11-24-exito-grupos-y-bandeja-como-personal` | Éxito de Grupos y de la Bandeja | done | Aprobar uno y «Guardar el siguiente» en el iPhone 14 (`evidencia/iphone14/06-…`); gasto de grupo y aprobar varios con `ExitoGruposBandejaCapturasUITests` en el simulador |
| ★ `2026-11-23-avisos-del-banco-claridad-y-region` | Avisos del banco: guía, región, activo al confirmar | sigue en QA | Pasos 1, 2, 4 y 6 bien en el iPhone 14; el 3 falla: la guía de Atajos describe iOS 26 y el iPhone tiene iOS 27.2 → card `zyaf`. El 5 (una compra real) espera a que esa card cierre |

## Las que siguen igual que en la build 7

| id | Destino | Qué lo retiene |
|---|---|---|
| `188b`, `4yc7`, `ljz7`, `yzxs`, `vimy` · `onboarding-2-3-single-provider-access` | iPhone de Jürgen | §4: entrar con Apple (Face ID) y la web real |
| `r8hi`, `o9b0` · `2026-11-22-conecta-tu-ia-diseno`, `ai-connector-drafts-in-the-inbox`, `claude-mcp-consent-with-apple-and-google` | iPhone de Jürgen | §4: la cuenta de Claude de Jürgen y el conector de producción |
| `l1c5`, `ds65` · `onboarding-2-3-getting-started-complete-and-pro-trial`, `2026-11-20-primeros-pasos-paso-7-implementacion` | iPhone de Jürgen | §4: StoreKit Sandbox solo responde en TestFlight |
| `b23b` · `reverse-on-the-iphone-left-the-local-store-empty` | iPhone de Jürgen | §4: pérdida de datos con el espejo real de iCloud y Google |
| `ea78` · `insights-small-recurring-spending-card` | visto bueno | §2.6: texto y sitio de «Gastos hormiga» |
| `9nn7` · `scheduled-payments-show-subscription-logos` | visto bueno | §2.6: los logos |
| `y6du` · `new-record-suggests-previous-descriptions` | visto bueno | §2.6: las sugerencias |
| `v466` | visto bueno | §2.6: que Yala IA pregunte la cuenta |
| `fu74` · `group-expense-from-a-receipt-with-ai` | visto bueno | §2.6: Jürgen quiere refinar la experiencia |
| `onboarding-sigue-los-estilos-del-resto-de-la-app` | visto bueno | §2.6: estilos de la bienvenida |
| `3w7z`, `i9d8` · `onboarding-2-3-bank-email-step` | en espera | Buzón y gateway de correo (Jürgen o Dan) |
| `vfg1` · `cloud-activation-time-is-unmeasured-between-the-claim-and-the-cutover` | en espera | Una activación real con cuenta nueva |
| `pv2l` · `2026-11-21-ia-ampliada-produccion-navegadores-publicada` | en espera | Despliegue de Dan y la 2.3 en la tienda |
| `j93f` | en espera | Credenciales de staging |
| `3z6j` | en espera | Gateway en producción y una semana de datos |
| `dyhx` · `own-telemetry-panel-by-sections` | en espera | Despliegue de la telemetría propia |
| `vfsf` | en espera | Es de marketing (Lola) |
| `2026-11-22-cuenta-limite-tarjeta-campo-sincronizado` | en espera | El límite sincronizado entre dos aparatos con la misma cuenta de iCloud |
| `siri-free-users-on-device-model-awaits-decision` | decisión pendiente | Jürgen |
