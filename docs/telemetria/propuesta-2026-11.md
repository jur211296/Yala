# Telemetría propia y panel por secciones — propuesta (sesión 1)

*2026-11-05 · propuesta para que Jürgen decida; no implementa nada.*
Maqueta: [`maqueta-panel.html`](maqueta-panel.html) · publicada en <https://claude.ai/artifact/6RGD5czHr7HvP9cR3JmRBT>

## 0 · Lo que cambia respecto a la card

La card (22-oct) pide «telemetría propia para reemplazar TelemetryDeck». **Medido el 5-nov: ese reemplazo ya ocurrió.**

- TelemetryDeck salió del código el 2026-07-17 (`d460480bf`, «purga total»): SDK fuera, ~190 llamadas de producto borradas por decisión de Jürgen, que dejó solo dos KPI (activos/día, altas/día) y los canarios.
- La **2.1 publicada** (22-oct) ya lleva la telemetría propia: `POST /metrics` del gateway → Workers Analytics Engine (`yala_metrics`, 90 días). Comprobado: `v2.1.0` contiene el commit de la purga; `v2.0.0`–`v2.0.2` no.
- La clave de TelemetryDeck tampoco está ya en `Secrets.xcconfig` (pendiente D4 de julio, hecho).
- ⇒ **El «envío doble unas semanas y apagar TelemetryDeck» del `hechaCuando` sobra.** Lo único pendiente de TelemetryDeck es cerrar la app en su web (pendiente D1 de julio), porque solo le pueden llegar aparatos en 2.0.0–2.0.2.

Lo que **sí** falta es lo que Jürgen pedía de verdad: un panel legible por secciones, con frases. Y para cuatro de las seis secciones (Grupos, Pro, partes de Uso y Registro) hoy no llega ningún dato, porque la purga de julio las apagó.

## 1 · Inventario

### 1.1 Lo que llega hoy (medido)

| Fuente | Qué es | Dataset | Desde |
|---|---|---|---|
| App · `ping` | «abrí la app», una vez al día por instalación (día UTC) | `yala_metrics` | 2026-08-07 |
| App · `register` | alta: `local` (`initial`) o `cloud` (`bornCloud`, `migration`…) | `yala_metrics` | 2026-08-17 |
| App · `canary` | 124 avisos internos (`MetricsCanary`) — sync, nube, grupos, routing, cuenta | `yala_metrics` | 2026-08-07 |
| Gateway · `canary` (`blob4='gateway'`) | 10 avisos del servidor: avisos de grupo entregados/fallidos, tokens, coherencia | `yala_metrics` | 2026-10-25 |
| Gateway · uso de IA | cada llamada: tarea, proveedor, modelo, tokens, `finish_reason`; sin contenido | `yala_ai_usage` | 2026-11-04 (primer dato 5-nov) |

Columnas: `blobs [evento, nombre, detalle, versión, install]`, `doubles [valor]`, `indexes [install]`. Contrato y SQL de referencia: `qa/cloud/README.md` § «Telemetría propia».

**Cifras del 5-nov** (las usa la maqueta): 15,3 activos/día de media en 7 días (13,0 la semana anterior); 35 instalaciones activas en 7 días, 82 en 30; 8 altas en 7 días (5 locales, 3 nube) frente a 28 la anterior; versión: 2.1 → 31, 2.2 → 3, 2.0.5 → 1; 30 aparatos activaron la nube en 30 días; copias iCloud 3.050 bien / 31 fallidas en 8 aparatos; 26 avisos de grupo entregados en 7 días, 0 fallidos.

### 1.2 Lo que TelemetryDeck tenía hasta julio (ya no existe)

157 eventos en `TelemetryService.swift` (borrado en `d460480bf`; se lee con `git show d460480bf^:Yala/Services/TelemetryService.swift`):

| Familia | Eventos | Ejemplos | Hoy |
|---|---|---|---|
| Diagnóstico | 63 | filtros de presupuesto vacíos, export de iCloud, Merkle | **migrados** a canarios propios |
| Grupos | 21 | grupo creado, gasto agregado, invitación aceptada, liquidación | perdidos |
| Chat IA | 20 | abierto, pregunta enviada, límite diario, borrador guardado | perdidos (el servidor ahora ve las llamadas) |
| Activación | 15 | pasos del onboarding, abandono, camino elegido | perdidos (queda `register`) |
| Pro | 13 | paywall visto, prueba iniciada, compra, tope Free | perdidos |
| Atajos | 7 | atajo ejecutado/fallido, Apple Pay, Siri | perdidos |
| Uso | 6 | transacción guardada, borrador aprobado, cuenta creada | perdidos |
| App | 6 | abierta, pidió reseña, sugerencias | `ping` cubre «abierta» |
| Análisis | 4 | hero IA generado/tocado | perdidos |
| Planificación | 2 | presupuesto y pago programado guardados | perdidos |

## 2 · Secciones y métricas propuestas

Cada métrica lleva una frase de plantilla. Origen: **ya llega** · **servidor** (sin tocar la app) · **evento nuevo**.

| Sección | Métrica | Frase de ejemplo | Origen |
|---|---|---|---|
| Uso | activos por día / semana / mes | «Esta semana abrieron Yala 15 personas al día de media, 2 más que la anterior.» | ya llega |
| Uso | versión en uso | «Casi todos ya están en la 2.1.» | ya llega |
| Uso | retención a 7 y 30 días | «De los que se dieron de alta hace dos semanas, 6 de cada 10 siguen.» | servidor (cruza `register` con `ping`) |
| Uso | funciones usadas | «Registrar un gasto es lo más usado.» | evento nuevo |
| Registro | altas por día, local o nube | «Esta semana se dieron de alta 8 personas.» | ya llega |
| Registro | embudo del alta | «Se pierde 1 de cada 3 antes de terminar.» | evento nuevo |
| Grupos | avisos entregados / fallidos | «Se entregaron 26 avisos sin fallos.» | ya llega |
| Grupos | grupos activos, invitaciones aceptadas | «Hay 9 grupos con movimiento.» | servidor (Supabase de Grupos) |
| Nube | activaciones, copias, datos que no cuadran | «30 aparatos activaron la nube.» | ya llega |
| Nube | cuentas en la nube | «Hay N cuentas con la nube encendida.» | servidor (Supabase) |
| Pro | pruebas, compras, renovaciones, bajas | «Empezaron 4 pruebas y 2 pasaron a suscripción.» | servidor (`/webhooks/appstore`) |
| Pro | vio la oferta, chocó con el tope | «22 vieron la pantalla de Pro.» | evento nuevo |
| IA | llamadas por tarea, costo | «La IA costó US$ X esta semana.» | ya llega / servidor |
| IA | límite diario alcanzado | «N agotaron sus preguntas del día.» | evento nuevo |
| Salud | canarios con umbral y color | «24 avisos dieron señal; ninguno pasa su umbral.» | ya llega (falta el umbral) |

Salud es una séptima sección que no estaba en la card: los canarios ya existen y hoy solo se leen a mano con SQL.

## 3 · Arquitectura

**Ingesta: no cambia.** `POST /metrics` + Analytics Engine ya está en producción y es barato para este volumen (≈350 escrituras al día con la flota de hoy). El cliente (`MetricsService` → `MetricsSpool` → `MetricsClient`) aguanta cortes de red. Si se añade un evento `use`, entra como cuarto tipo en la whitelist del gateway (`e ∈ {ping, register, canary, use}`) y en el wire v1, sin versión nueva.

**Lo nuevo que propongo:**

1. **Resumen diario a D1.** Un cron del Worker agrega cada día (activos, altas, retención por cohorte, canarios, IA) y lo guarda en D1. Resuelve el límite de 90 días de Analytics Engine (diferido D3 de julio) y da conteos exactos para comparar semanas. Los eventos crudos se quedan en AE.
2. **Conteos del servidor.** El mismo cron lee agregados de Supabase (grupos, miembros, invitaciones, cuentas nube) y de los avisos de Apple que ya recibe `/webhooks/appstore`. Ningún dato por persona sale de ahí: solo conteos.
3. **Panel.** Un Worker aparte (`panel`), detrás de Cloudflare Access con `admin@yala-app.pe`, que lee D1 y pinta la página de la maqueta. Aparte del gateway para que un fallo del panel no toque el sync de producción.
4. **Frases.** Plantillas deterministas con umbrales («2 más que la semana pasada», «la mitad que…»). El resumen semanal con IA es opcional y reusaría los proveedores del gateway.

Alternativa descartada para la ingesta: **D1 como almacén de eventos crudos** — cada evento sería una escritura a una base SQLite con límites de escritura por segundo; AE está hecho para eso y ya funciona.

## 4 · Privacidad y etiquetas de la App Store

- Sin PII: `install` = SHA-256 truncado de un UUID local; nunca userID, correo, montos ni texto.
- El panel no enseñaría cortes con menos de 3 aparatos.
- `PrivacyInfo.xcprivacy` ya declara `ProductInteraction` (no vinculado, Analytics) y `OtherDiagnosticData` (no vinculado). Un evento `use` cabe ahí: **no cambia el manifiesto**. Hay que confirmar que la ficha de privacidad de App Store Connect dice lo mismo (eso lo ve Jürgen; no hay acceso desde aquí).
- Visto de paso: `DeviceID` está declarado como **vinculado** (`Linked=true`, App Functionality + Analytics), mientras el mensaje del commit de julio dice que «conserva NotLinked». No lo toco; va como pregunta.

## 5 · Decisiones para Jürgen

1. **¿Volvemos a medir qué funciones se usan?** A · evento `use`, uno al día por función, ~15 funciones *(recomendado)* · B · no, solo lo que llega + servidor · C · volver al detalle de TelemetryDeck (embudos, paywall, tutoriales). *Revierte en parte la decisión de julio.*
2. **¿Dónde vive el panel?** A · Worker propio con Cloudflare Access *(recomendado)* · B · ruta dentro del gateway · C · artifact de claude.ai refrescado por una tarea programada.
3. **¿Historia de más de 90 días?** A · resumen diario en D1 *(recomendado)* · B · no por ahora.
4. **¿Frases?** A · plantillas fijas *(recomendado)* · B · + resumen semanal con IA en el panel · C · B y además al digest de Slack.
5. **¿Grupos, Nube y Pro desde el servidor (Supabase + avisos de Apple)?** A · sí *(recomendado)* · B · solo lo que mande la app.
6. **¿Cerramos ya la app en TelemetryDeck?** A · sí *(recomendado)* · B · esperar al panel.
7. **`DeviceID` en el manifiesto: ¿vinculado o no?** A · revisar y alinear con la ficha de App Store Connect en la sesión de ingesta *(recomendado)* · B · dejarlo.
8. **Reescribir el «hecha cuando» de la card** sin envío doble ni retirada de TelemetryDeck del código (ya hecho): «el panel por secciones está publicado, Jürgen lo aprueba y la app TelemetryDeck está cerrada».

## 6 · Siguiente, según lo que elijas

Con las recomendadas: **sesión 2** ingesta (`use` en la app + whitelist del gateway + cron a D1 con conteos de servidor), **sesión 3** panel (Worker + Access + frases), **sesión 4** umbrales de Salud y cierre de TelemetryDeck. Si eliges B en la 1, la sesión 2 no toca la app y todo cabe en dos sesiones.
