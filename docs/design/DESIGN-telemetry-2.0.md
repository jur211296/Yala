# DESIGN — Telemetría 2.0

> Estado: **propuesta para revisión** (nada implementado). Autor: sesión de auditoría 2026-06-16.
> Objetivo del owner: *"arreglar el App ID de forma robusta, renombrar las métricas a algo claro en español, y completar la cobertura para saber todo lo que deberíamos saber de la app."*

---

## 0. Diagnóstico (verificado)

- **La telemetría de producción está muda desde mayo.** El `TELEMETRY_DECK_APP_ID` se inyecta vía `$(TELEMETRY_DECK_APP_ID)` desde `Secrets.xcconfig`, pero ese valor **nunca se definió** (ni en `Secrets.xcconfig` ni en el `.template` ni en `project.pbxproj`). Resultado: `""` en todos los builds → `APIKeyService` devuelve `nil` → `TelemetryService.configure()` aborta → cero señales.
- **Histórico (10 binarios archivados):** del build 3 (4 may) al build 21 (15 jun), todos con App ID vacío. TelemetryDeck se integró el **11 mar** (commit `f8908240`); lo que el owner vio "al inicio" fueron sus pruebas de marzo/abril en Debug (Test Mode) antes de que el valor se perdiera del `Secrets.xcconfig`.
- **App ID correcto (provisto por el owner):** `9D2922BB-2BCB-4B63-A0EB-B3AAD33CD6CA`. **No es un secreto** — es un identificador público que viaja en cada request de red de TelemetryDeck. Por eso NO debe vivir en `Secrets.xcconfig`.
- **El gateway de API keys SÍ funciona:** el build 21 ya no expone `OPENAI_API_KEY`/`EXCHANGE_RATE_API_KEY` (las quitó el commit `60fa5607`). Pendiente ajeno a este diseño: **revocar/rotar** las keys viejas filtradas en build ≤18.
- **Enum actual: 108 eventos.** Renombrar es seguro: el `rawValue` solo se usa para enviar la señal (`TelemetryService.track`/`trackOnce`); ningún otro código depende de él.

---

## 1. Fase 1 — Fix robusto del App ID (desbloquea datos de inmediato)

**Principio:** sacar el App ID de la categoría "secreto" y ponerlo donde sea imposible que quede vacío, + una red de seguridad en el pipeline de release.

### 1.1 Valor versionado, no en secrets
Cambiar en `Yala/Resources/Info.plist`:
```diff
- <key>TELEMETRY_DECK_APP_ID</key>
- <string>$(TELEMETRY_DECK_APP_ID)</string>
+ <key>TELEMETRY_DECK_APP_ID</key>
+ <string>9D2922BB-2BCB-4B63-A0EB-B3AAD33CD6CA</string>
```
`APIKeyService.telemetryDeckAppID` sigue leyéndolo del bundle sin cambios. Cero indirección → imposible que se evapore al clonar el repo o regenerar `Secrets.xcconfig` en CI.

### 1.2 Red de seguridad pre-upload (`.asc/`)
Un guard en el pipeline de archive/upload que **aborta la subida** si el `Info.plist` del `.app` tiene:
- `TELEMETRY_DECK_APP_ID` vacío, **o**
- `OPENAI_API_KEY` / `EXCHANGE_RATE_API_KEY` presentes (previene regresión del gateway).

Un solo control protege ambos problemas a futuro. Es justo lo que faltó cuando build 21 (telemetría muda) y build ≤18 (keys filtradas) se subieron sin que nada los detectara.

### 1.3 Un App ID, no dos (Dev/Prod)
TelemetryDeck separa automáticamente las señales de builds Debug (*Yala Dev*) como **Test Mode** y las de Release (*Yala*, TestFlight, Store) como producción. Un solo App ID basta y no contamina los datos de producción.

> Esta fase es independiente y la más urgente: con ella, los datos reales empiezan a fluir sin importar el resto del rediseño.

---

## 2. Esquema de nombres (español, agrupado)

**Convención:** `Categoría · Acción`. El ` · ` agrupa visualmente en el dashboard.

**Categorías de PRODUCTO** (qué usan los usuarios — lo que el owner quiere ver):
`App` · `Activación` · `Uso` · `Planificación` · `Análisis` · `Chat IA` · `Grupos` · `Pro` · `Ajustes` · `Notificaciones` · `Seguridad` · `Atajos`

**Categoría de DIAGNÓSTICO** (salud técnica — se puede ignorar en el dashboard principal):
`Diagnóstico` (absorbe los actuales `cloudkit*`, `routing*`, `tagCatalogRebuilt`, `appEntityShortcutIDsRegenerated`, `budgetFiltersAppearEmpty`, etc.)

**Se mantiene:** el parámetro automático `isProUser` en cada evento.

### 2.1 Mapa de renombrado (representativo — el resto sigue el mismo patrón)

| Hoy (`rawValue`) | Propuesto |
|---|---|
| `appLaunched` | `App · Abierta` |
| `onboardingStarted` | `Activación · Onboarding iniciado` |
| `onboardingCompleted` | `Activación · Onboarding completado` |
| `onboardingCancelled` | `Activación · Onboarding abandonado` |
| `welcomeChooserBranchSelected` | `Activación · Camino elegido` |
| `transactionSaved` | `Uso · Transacción guardada` |
| `draftApproved` | `Uso · Borrador aprobado` |
| `exportCompleted` | `Uso · Exportación completada` |
| `accountCreated` | `Uso · Cuenta creada` |
| `budgetSaved` | `Planificación · Presupuesto guardado` |
| `scheduledPaymentSaved` | `Planificación · Pago programado guardado` |
| `chatQuestionAsked` | `Chat IA · Pregunta enviada` |
| `chatDraftSaved` | `Chat IA · Gasto guardado` |
| `chatVoiceInputUsed` | `Chat IA · Entrada por voz` |
| `groupCreated` | `Grupos · Grupo creado` |
| `groupExpenseAdded` | `Grupos · Gasto agregado` |
| `groupSettlementConfirmed` | `Grupos · Liquidación confirmada` |
| `paywallViewed` | `Pro · Vio el paywall` |
| `proUpsellShown` | `Pro · Oferta mostrada` |
| `purchaseCompleted` | `Pro · 💰 Compra exitosa` |
| `trialStarted` | `Pro · Prueba iniciada` |
| `featureGateHit` | `Pro · Tope de función Free` |
| `intentInvoked` | `Atajos · Atajo ejecutado` |
| `cloudkitExportFailed` | `Diagnóstico · Sync falló` |
| `routingIntentSuperseded` | `Diagnóstico · Routing supersedido` |

> El mapa exhaustivo de los 108 se genera como primer paso de la Fase 2 (mecánico, una sola edición del enum). Aquí se valida el **estilo**.

---

## 3. Eventos NUEVOS — completar la cobertura

Curados y deduplicados de la auditoría por áreas. Filtrado el ruido (ver §5). Todos privacy-safe: solo enums, booleanos, conteos y buckets — **nunca montos, nombres ni notas**.

### P0 — Imprescindibles (lo que hoy nos ciega del negocio)

| Evento | Pregunta que responde | Parámetros privacy-safe |
|---|---|---|
| `App · Sesión iniciada` | ¿Vuelven los usuarios? (regreso, no solo cold start) | `tipo` = frío\|tibio |
| `Activación · Primera transacción` | ¿Llegan al "momento aha"? ¿Cuándo? | `dias_desde_install` (bucket), `origen` = manual\|chat\|atajo |
| `Activación · Primer presupuesto` | Adopción de planificación | `periodo` (enum) |
| `Activación · Primer pago programado` | Adopción de recurrentes | `recurrencia` (enum) |
| `Pro · Suscripción renovada` | ¿Cuántos renuevan? (base de LTV) | `plan` = mensual\|anual |
| `Pro · Suscripción cancelada` | Churn real (no solo "expirando") | `plan`, `dias_como_pro` (bucket) |
| `Pro · Suscripción expirada` | Fin real de la suscripción | `plan`, `era_trial` (bool) |
| `Pro · Compras restauradas` | ¿Se usa restore? ¿Funciona? | `resultado` = exito\|nada\|error |
| `Grupos · Invitación enviada` | Viralidad (hoy evento muerto) | `via` = link\|nativo |
| `Grupos · Invitación aceptada` | Conversión de invitaciones (hoy muerto) | `origen` = link\|nativo |

**Decisión de diseño — activación vía parámetro, no solo evento:** añadir `es_primera: bool` a `Uso · Transacción guardada`, `Planificación · Presupuesto guardado` y `Planificación · Pago programado guardado`. Es más limpio que mantener eventos `firstX` separados, y el dashboard puede filtrar por `es_primera=true`.

**Decisión de diseño — ciclo de suscripción:** renovación/cancelación/expiración son medibles con StoreKit (`Transaction.updates` / `Product.SubscriptionInfo.Status`), pero con esfuerzo y precisión limitada. **Aquí es donde RevenueCat brillaría** (lo hace nativo, con MRR/churn/LTV de fábrica). Recomendación: implementar la versión StoreKit ahora para tener señal, y dejar RevenueCat como épico aparte cuando la monetización sea prioridad. (Ver §7.)

### P1 — Importantes (CRUD y acciones que hoy no vemos)

| Evento | Pregunta | Parámetros |
|---|---|---|
| `Uso · Transacción editada` | ¿Cuánto se corrige vs crea? | `tipo`, `campos` (lista de nombres, sin valores) |
| `Uso · Transacción eliminada` | Confianza en los datos | `tipo`, `antiguedad` (bucket) |
| `Uso · Transacción duplicada` | Uso de plantillas rápidas | `tipo` |
| `Uso · Transferencia guardada` | Adopción + riesgo cross-moneda | `multimoneda` (bool), `origen_tasa` = manual\|auto |
| `Uso · Edición masiva` | ¿Se usa el bulk edit? | `cantidad` (bucket), `campos` |
| `Uso · Búsqueda` | ¿Buscan o filtran? | `con_resultados` (bool) |
| `Uso · Importación` | Adopción de import CSV/XLSX | `formato`, `cantidad` (bucket), `exito` (bool) |
| `Planificación · Presupuesto superado` | ¿Los presupuestos reflejan la realidad? | `periodo`, `porcentaje` (bucket) |
| `Planificación · Alerta de presupuesto` | ¿Sirven las alertas? | `umbral` = 50\|75\|90\|100 |
| `Planificación · Pago marcado como pagado` | ¿Se completan los recurrentes? | `a_tiempo` (bucket de días) |
| `Grupos · Salió del grupo` | Churn de grupos | `antiguedad` (bucket), `con_deuda` (bool) |
| `Grupos · Balances vistos` | ¿Usan la vista central de deudas? | `rol` = admin\|miembro |
| `Chat IA · Borrador editado` | ¿El LLM acierta o hay que corregir? | `campos_editados` |
| `Chat IA · Reintento` | Fricción / errores del gateway | `motivo` (bucket) |

### P2 — Útiles (configuración + consumo; adopción y preferencias)

| Evento | Pregunta | Parámetros |
|---|---|---|
| `Análisis · Período cambiado` | ¿Qué rangos de tiempo usan? | `periodo` (enum), `pantalla` |
| `Análisis · Reporte visto` | ¿Se usan los reportes Pro? | `tab` = comparativa\|flujo |
| `Análisis · Salud financiera vista` | ¿El Financial Score es útil? | `score` (bucket) |
| `Ajustes · Tema cambiado` | Adopción de temas Pro (señal $) | `tema` (enum) |
| `Ajustes · Moneda principal` | Penetración por región/divisa | `moneda` (ISO), `momento` = setup\|cambio |
| `Ajustes · Idioma cambiado` | Distribución de idioma real | `idioma` (ISO) |
| `Notificaciones · Permiso` | ¿Cuántos aceptan notificaciones? | `resultado` = concedido\|denegado |
| `Notificaciones · Tap` | ¿Las notificaciones traen gente de vuelta? | `tipo`, `destino` |
| `Seguridad · Bloqueo biométrico` | Adopción de Face ID lock | `accion` = activado\|desactivado |
| `Atajos · Widget configurado` | Adopción de widgets | `tipo_widget` |

---

## 4. Eventos muertos — limpiar

5 eventos definidos que nunca se disparan (verificado: solo existen en el enum):

- **Cablear** (valen como métrica): `groupInviteSent` → `Grupos · Invitación enviada`; `groupInviteAccepted` → `Grupos · Invitación aceptada`. (Ya en P0.)
- **Eliminar** (redundantes o sin feature): `groupJoined`, `groupMemberAdded`, `groupHistoryImported`.

---

## 5. Lo que NO se trackea (anti-ruido)

Para que el dashboard sea señal, no ruido, **no** se instrumenta: scrubbing/hover en gráficas, cada redimensión de widget, cada expansión de fila de tabla, cada tap de filtro individual (solo "aplicar"), timestamps exactos, ni nada con monto/nombre/nota. Consistente con la regla privacy-first de la app.

---

## 6. Guía de dashboard (TelemetryDeck) — las preguntas clave

Insights a crear una vez fluyan datos. Cada uno responde una pregunta de negocio:

1. **¿Cuánta gente activa hay?** → `App · Abierta` (usuarios únicos por día/semana).
2. **¿Se quedan?** → retención sobre `App · Sesión iniciada`.
3. **¿Llegan al valor?** → embudo `Activación · Onboarding completado` → `Activación · Primera transacción`.
4. **¿Qué función usan más?** → comparar volumen de `Uso ·`, `Chat IA ·`, `Grupos ·`, `Planificación ·`.
5. **¿Convierte el negocio?** → embudo `Pro · Vio el paywall` → `Pro · Prueba iniciada` → `Pro · Compra exitosa`.
6. **¿Qué tope empuja a Pro?** → `Pro · Tope de función Free` agrupado por función.
7. **¿Se quedan Pro?** → `Pro · Suscripción renovada` vs `cancelada`.
8. **¿Qué prefieren?** → distribución de `Ajustes · Moneda principal`, `Ajustes · Idioma`, `Ajustes · Tema`.

---

## 7. Plan de implementación (por fases, para revisar)

| Fase | Qué | Riesgo | Resultado |
|---|---|---|---|
| **1** | Fix App ID (Info.plist literal) + guard pre-upload `.asc/` | Bajo (config) | **Datos reales fluyen ya** |
| **2** | Renombrar los 108 a español + limpiar 5 muertos + cablear 2 invites | Bajo (solo strings) | Dashboard legible |
| **3** | Eventos nuevos **P0** (retención, activación, ciclo Pro) | Medio | Visibilidad de negocio |
| **4** | Eventos nuevos **P1** + **P2** (CRUD, config, consumo) | Medio | Cobertura completa |
| **5** | Armar los Insights del §6 en el dashboard + guía escrita | — | El owner "entiende" la telemetría |

**Recomendación de secuencia:** Fase 1 ya (en el próximo build); Fases 2–3 juntas en un commit de telemetría; Fase 4 incremental; Fase 5 cuando haya ~2 semanas de datos.

**Fuera de este diseño (épicos aparte):**
- **RevenueCat** para monetización seria (MRR/churn/LTV/conversión de trial nativos). El ciclo Pro de la Fase 3 es una aproximación con StoreKit; RevenueCat lo haría mejor.
- **Revocar/rotar** las API keys filtradas en builds ≤18.

---

## 8. Nota de privacidad (app de finanzas)

Todo evento nuevo respeta el diseño actual: **solo** enums fijos, booleanos, conteos y buckets. **Nunca** montos, nombres de cuentas/personas/transacciones, notas, emails ni timestamps exactos. TelemetryDeck mantiene el anonimato (doble hash) y no obliga a declarar tracking invasivo en el App Store — coherente con la filosofía privacy-first reforzada por el épico del gateway.

---

## 9. Estado de implementación (2026-06-16)

Implementado y compilando (build verde en cada paso). **Sin commitear aún** — pendiente de revisión del owner.

**Fix + renombrado**
- `Info.plist` con App ID literal `9D2922BB-…` + `scripts/asc-preflight.sh` (guard pre-upload).
- 105 eventos renombrados a español `Categoría · Acción`; 3 muertos eliminados (`groupJoined`, `groupMemberAdded`, `groupHistoryImported`).

**Eventos nuevos cableados**
- *P0*: Primera transacción/presupuesto/pago, App·Reactivada (warm, con guard anti-doble-cold), Pro·Suscripción terminada, plan mensual/anual en compra, Grupos·Invitación enviada/aceptada.
- *P1*: Transacción eliminada/duplicada, Presupuesto/Pago eliminado, Salió del grupo, Alerta de presupuesto (umbral 100 = superado), Reintento de chat, Balances vistos, Edición masiva (×5 campos), Búsqueda, Importación.
- *P2*: Tema cambiado, Moneda principal, Permiso de notificaciones, Tap de notificación, Bloqueo biométrico, Widget configurado, Reporte visto, Tab de stats visto.

**Diferidos (callsite complejo o valor incremental bajo)** — documentados, no cableados:
- `Pago marcado como pagado` — la confirmación vive dentro de `TransactionAssociationSheet`/VM.
- *Transferencia multimoneda* — `transactionSaved` con `type="transfer"` ya captura el uso; el detalle multimoneda requiere exponer propiedades de cuenta del VM.
- `Período cambiado` — hay varios selectores (Records/Panel/Stats) sin un punto único; necesita un SSOT antes de instrumentar sin duplicar.
- `Salud financiera vista` — `FinancialScoreView` se muestra en el Panel de forma permanente → trackear su aparición sería ruidoso.
- `Idioma cambiado` — el cambio efectivo ocurre en un picker sheet separado (no en `PersonalizationSettingsView`).

**Pendiente del owner**
1. Revisar el diff y commitear (atómico por commit o agrupado).
2. Subir un build nuevo a TestFlight/Store — **es el único paso que reactiva la telemetría en producción**.
3. Correr `scripts/asc-preflight.sh <archive>` entre `-exportArchive` y `asc builds upload`.
4. A las 24–48 h, verificar en el dashboard de TelemetryDeck (Test Mode OFF) que llegan señales reales con los nombres en español.
