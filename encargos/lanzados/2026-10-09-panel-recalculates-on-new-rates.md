---
esfuerzo: high
---
# El Panel recalcula solo cuando llegan las tasas del día y cuando el arranque repara importes provisionales

## Contexto
Card del tablero `tablero-el-panel-no-recalcula-al-llegar-tasas-nu-t72p` (lista para lanzar, vence 2026-10-10). Tickets: `tickets/backlog/panel-no-recalcula-al-llegar-tasas-nuevas.md` (principal) y `tickets/backlog/reparacion-de-tasas-no-avisa-al-panel.md`. Los dos salen de la review adversarial de `fx-pnl-education-card` (2026-09-07) y el triage de Frank del 2026-10-07 los confirmó vivos en el código de 2.1. Van juntos porque es el mismo refresco del Panel.

Lo que le pasa al usuario: abre la app a primera hora, la tasa de hoy aún no está y el Panel usa la de ayer con su «≈». Dos segundos después llegan las tasas de hoy y el Panel no se entera: el saldo sigue a la tasa de ayer y la marca de aproximado sigue encendida hasta que toca un filtro, hace pull-to-refresh o vuelve de segundo plano. Y si el arranque repara importes provisionales (gastos en divisa de un día sin tasas), el Panel sigue con los números envenenados toda esa sesión.

Según los tickets (son pistas, verifícalas en este árbol antes de tocar nada):
- `ExchangeRateService` postea `.yalaExchangeRatesUpdated` al persistir tasas nuevas, y el único receptor (en `AppBootstrapper`, hacia la L1222 en 2.1 de hoy) invalida la caché del converter. No hay ningún receptor en `PanelView`, `PanelShell`, `PanelDataObservers` ni `PanelSessionObservers`. `AccountCurrencyMigrationService` postea la misma notificación.
- `TransactionUpdateService.updateProvisionalTransactions` (hacia la L235) muta los `@Model` en sitio y hace `context.save()`, sin bumpear `sessionState.dataVersion` ni postear nada. Se llama desde `AppBootstrapper.loadExchangeRates` después de dos `await` de red; el Panel calcula con un debounce de 150 ms.
- Es el caso que describe `.claude/rules/swiftui-ds.md`: al precalcular en el ViewModel, el refresco depende entero de que todo mutador desemboque en el recálculo.
- Desde `fx-pnl-education-card` hay en el Panel una card cuyo sujeto es la tasa, con una marca de aproximado que puede quedar mintiendo.

CADENA tras cerrar `chat-context-archived-accounts-and-mtd` (PR #418 en cola de auto-merge a 2.1; card obwc en done). No depende de ella: trabaja sin esperarla. `PanelViewModel` ya trae el cambio de presupuestos del PR #416 (mergeado). Las cards high que quedan necesitan backend/deploy o están en manos de Jürgen; esta es la mejor medium sin decisión pendiente, sin deploy, sin secretos y sin gasto de API (no hagas llamadas de pago a modelos ni corras el banco).

Para orientarte: `CLAUDE.md`, `.claude/rules/swiftui-ds.md`, `.claude/rules/currency-fx.md`, `.claude/rules/testing.md` y los dos tickets.

Antes de tocar UI, mira `~/Claude/referencias-ui/README.md` (referencias de patrones de la flota: inspiración, no copiar pantallas ni marcas) y respeta `.claude/rules/swiftui-ds.md`.

## Que se pide
1. Reproducir los dos casos (con test, y en el simulador si se puede forzar el día sin tasas).
2. Arreglar con un solo camino robusto: que persistir tasas nuevas y reparar importes provisionales desemboquen en el recálculo del Panel (por ejemplo, bumpeando `dataVersion` o con el Panel observando la notificación, lo que sea coherente con `.claude/rules/swiftui-ds.md`), sin recalcular de más: mide cuántos recálculos hay por evento antes y después.
3. La marca de aproximado se apaga sola cuando la tasa buena ya está en disco.
4. Si el widget de la pantalla de inicio o Estadísticas tienen el mismo agujero, anótalo en un ticket aparte en `tickets/backlog/` con lo medido y no lo arregles aquí.
5. Tests: reparar importes provisionales despierta al Panel; persistir tasas nuevas despierta al Panel. Controles rojos con el código viejo.
6. Si el cambio se ve en el simulador, deja `capturas/antes.png` y `capturas/despues.png` en el worktree, con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas y deja un guion de device-QA en `tickets/qa/`.
7. Anota lo medido en los dos tickets y muévelos según las convenciones del repo.
8. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-el-panel-no-recalcula-al-llegar-tasas-nu-t72p` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.
9. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --fecha <AAAA-MM-DD> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre.

## Que NO hay que tocar
- El converter y su cadena de escalones: solo cambia quién se entera de que hay tasas nuevas.
- El reparador de importes en sí (`updateProvisionalTransactions`), más allá de que avise.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~22 GB libres el 2026-10-09, muy por debajo del umbral de 32: limpia primero, evita tandas grandes de capturas y, si baja de ~18 GB, para, limpia y sigue).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Al llegar las tasas del día, el saldo del Panel y la marca de aproximado se corrigen solos; tras reparar importes provisionales en el arranque, el Panel recalcula en esa misma sesión.
- Sin recálculos de más (medido).
- Tests con controles rojos con el código viejo; builds `Yala` y `Yala Dev` verdes; capturas antes y después, o guion de device-QA.
- PR a 2.1 en auto-merge, tickets movidos, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (árbol de 2.1 del 2026-10-09, `29ccdc909`).**
- En arranque en FRÍO el caso del ticket no se da: `bootstrap` hace `await loadExchangeRates` (paso 2, que incluye
  `updateTodayIfNeeded` y la reparación) y al final (paso 19, `AppBootstrapper.swift:695`) bumpea `dataVersion`, que el
  Panel convierte en `reloadAndRecalculate()`. Los agujeros son los escritores que corren FUERA del arranque:
  `NewTransactionViewModel.loadExchangeRate` (`updateTodayIfNeeded` al preparar una transferencia entre cuentas de divisas distintas con fecha de hoy; si se
  cancela no hay bump),
  `CurrencySettingsView`/`AccountFormView` (`forceUpdateToday` + `forceRefreshRates`, solo marcan
  `needsExchangeRateWidgetRefresh`, que nadie observa), y la reparación desde `UserDataResetView` e `ImportIntroSheet`.
- Volver de segundo plano en un día nuevo NO trae las tasas de hoy: no hay `updateTodayIfNeeded` en primer plano ni al
  cambiar de día. Es otra causa del «≈» pegado y no se arregla aquí (ticket aparte).

**D1 · ¿Por qué camino se entera el Panel de las tasas nuevas?** → El Panel observa `.yalaExchangeRatesUpdated`
(`.onReceive` en `PanelDataObservers`, molde de la casa) y llama a `PanelViewModel.exchangeRatesDidUpdate()`, que marca
el widget de tipo de cambio para refrescar y pide `recalculateData()` (sin recarga: persistir tasas no toca filas).
Por qué: es la señal que ya emiten todos los escritores de tasas y la que invalida la caché del converter; el recálculo
llega 150 ms después de la invalidación. Alternativa descartada: bumpear `dataVersion` al persistir tasas — recargaría
todas las pestañas (y arreglaría Estadísticas, que el encargo pide dejar en ticket) por un cambio que no mueve filas.

**D2 · ¿Cómo avisa la reparación de importes provisionales?** → `updateProvisionalTransactions` bumpea
`SessionState.shared.dataVersion` cuando guardó cambios (`changedCount > 0 && savedCleanly`), dentro del escritor.
Por qué: reparar SÍ muta filas, y `dataVersion` es la señal de «datos cambiados» de toda la app; es lo que hace su
gemelo `ChatUnsignedExpenseRepairService` y lo que pide el AC del ticket. Dentro del escritor para que un llamador
nuevo no se lo olvide. Alternativa descartada: postear `.yalaExchangeRatesUpdated` (invalida la caché sin motivo y no
recarga filas) o bumpear en cada llamador (tres sitios hoy, el cuarto se olvidaría).

**D3 · ¿Se suprime el aviso durante el arranque, que ya cubre el bump final?** → No. Se mide y se informa.
Por qué: el coste es un recálculo más en el primer arranque de un día con tasas nuevas (o con reparación); un gate por
«arranque asentado» acopla el servicio al orden del bootstrap y falla en silencio si ese orden cambia.

**D4 · ¿Widget de inicio y Estadísticas?** → Se miden y van a ticket aparte en `tickets/backlog/`, sin arreglar.
La reparación bumpea `dataVersion`, así que lo que ya cuelga de esa señal se entera también: es el efecto de D2, no un
arreglo aparte, y se anota en el ticket.

**D5 · Tests.** → (a) la reparación que cambia algo bumpea `dataVersion` exactamente una vez y la que no cambia nada no
lo toca; (b) el ViewModel del Panel con un converter propio: con solo la fila de ayer el saldo sale «≈»; se guarda la
de hoy, se invalida como hace el receptor del arranque, `exchangeRatesDidUpdate()` y la marca se apaga, con UN solo
cálculo contado; (c) source-scan del cableado `.onReceive` → `exchangeRatesDidUpdate()`, porque el `onReceive` es vista.
Controles rojos: quitar el bump (a), quitar el recálculo del método (b), quitar el `.onReceive` (c).
Para contar cálculos y no depender del `applicationState` del host de test, el ViewModel gana una costura mínima
(`isApplicationActive` inyectable y un contador DEBUG de `performCalculation`).

**D6 · Capturas.** → Si en el simulador se puede forzar un día sin la fila de hoy (borrándola y su marca de intento),
antes/después del Panel tras cancelar esa transferencia. Si no, guion de device-QA en `tickets/qa/`.
