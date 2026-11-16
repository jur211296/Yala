---
toca: .claude/rules/gateway-attest.md, Yala/App/AppBootstrapper.swift, Yala/App/Logic/AIConnectorDraftLogic.swift, Yala/App/Logic/DraftConversionEligibilityLogic.swift, Yala/App/Logic/InboxDraftSourceName.swift, Yala/App/Services/AIConnectorDraftService.swift, Yala/App/Views/Inbox/InboxDraftRowView.swift, Yala/Models/InboxDraft.swift, Yala/Services/BankEmail/BankEmailClient.swift, Yala/Utils/L10n.swift, YalaTests/AIConnectorDraftTests.swift, YalaTests/DraftConversionEligibilityLogicTests.swift, YalaTests/ScheduledDraftOccurrenceLogicTests.swift, gateway/migrations/0004_connector_drafts.sql, gateway/src/connector/entrypoint.ts, gateway/src/connector/routes.ts, gateway/src/connector/store.ts, gateway/src/index.ts, gateway/src/sync/account.ts, gateway/test/connector.test.ts, gateway/test/stubs/cloudflare-workers.ts, gateway/vitest.config.ts, mcp/CONECTAR-TU-IA.md, mcp/README.md, mcp/RUNBOOK-produccion.md, mcp/plugin/README.md, mcp/src/authorize.ts, mcp/src/config.ts, mcp/src/env.ts, mcp/src/index.ts, mcp/src/mcp.ts, mcp/src/pages.ts, mcp/src/server.ts, mcp/src/tokens.ts, mcp/src/toolCore.ts, mcp/src/writeTool.ts, mcp/test/e2e/oauth.e2e.test.ts, mcp/test/social-login.test.ts, mcp/test/writeTool.test.ts, mcp/wrangler.toml, Yala/Resources/
esfuerzo: high
cierre: cierra-sola
pruebas-ui: si
depende: Yala/desbloquear-pr-calendario-semana
---

# Desbloquear el PR «Tu IA registra en Yala: Claude, ChatGPT y Grok dejan borradores en la Bandeja»: traer 2.3, resolver el conflicto y dejarlo mergeado

Rama base: 2.3.

## Contexto

Lo encola la conciliación de PR abiertos de 2.3 del 14-nov (`docs/qa/conciliacion-prs-2-3/` en 2.3). Este PR terminó su sesión en modo cola: quedó en cola de auto-merge y el merge de otro PR lo dejó en conflicto, así que lleva días sin entrar. Su código **no está** en 2.3 (medido: ningún commit suyo en 2.3 y casi ninguna de sus líneas) y **nada mergeado lo reemplaza**. Su card dice «done» o «in qa», pero la conciliación la pasó a `blocked` porque el trabajo no está en la rama.

PR: https://github.com/jur211296/Yala/pull/818 — «Tu IA registra en Yala: Claude, ChatGPT y Grok dejan borradores en la Bandeja». Rama: `encargo/2026-11-05-tu-ia-registra-en-yala`.

Cómo está el conflicto: Medido: el conflicto es trivial (`mcp/src/toolCore.ts` se movió a `shared-core/` en #959; este PR solo exportaba cuatro funciones y en `shared-core` falta `export` en `zoneNotice`; más 4 `.strings`, `DECISIONS`, `TICKETS` y `coverage-index`). Lo que NO es trivial: una decisión posterior deja obsoleto su transporte. La D9 del plan de Yala web (`docs/web-app/index.html`, PR #941 del 12-nov) fija «una cola de borradores común: web, correo e IA», y Yala web beta (#970) ya la implementó: la web escribe en `mail_drafts` con `source: "web"` y el iPhone la recoge con la recogida del correo (`WebDraftLogic.swift`). Este PR monta una cola paralela (migración `0004_connector_drafts`, RPC `ConnectorDrafts`, rutas `/connector/drafts`, `AIConnectorDraftService`).

## Qué se pide

1. `git fetch origin` y trabaja **sobre la rama del PR** (`encargo/2026-11-05-tu-ia-registra-en-yala`), no sobre una rama nueva: trae `origin/2.3` con un merge (no rebase: la rama ya está publicada) y resuelve los conflictos.
2. Qué hacer: conservar lo que sigue haciendo falta (la herramienta `apuntar_movimiento`, las vueltas OAuth de ChatGPT y Grok, el texto del permiso y la fuente «Tu IA» `.aiConnector` en la Bandeja) y cambiar el transporte a la cola común con un `source` propio, retirando la cola paralela. Si al medirlo la D9 no cubre algo que este PR necesita, eso es una decisión de diseño: pregúntala con `preguntar-bot` y no la tomes sola. NO despliegues el gateway ni el conector en producción; staging solo si el encargo de despliegue ya lo autoriza.
   Pasa `/gate` entero (build ×2, unit, XCUITest de las áreas tocadas, validación del índice). Sin gate no hay commit.
3. Push a la misma rama. No abras PR nuevo: el PR ya existe y ya tiene el auto-merge activado (compruébalo con `gh pr view 818 --json state,mergeable,autoMergeRequest`; si no lo tiene, `gh pr merge 818 --auto --merge`).
4. **Espera a que tu PR quede `MERGED`** antes de cerrar (excepción a la regla de no esperar el CI, a propósito: este PR ya se quedó una vez colgado por no hacerlo). Mira cada 5 min con `gh pr view 818 --json state,mergeStateStatus` y escribe avance; si vuelve a `DIRTY` porque otro PR entró antes, repite 1-3. Tope: 90 min o dos vueltas; si se pasa, déjalo en cola y dilo en «Necesita de ti».
5. Al quedar `MERGED`: mueve sus cards (o9b0 (Tu IA registra en Yala: Claude y ChatGPT crean borradores en la Bandeja)) de `blocked` a `in qa` con `tablero mover <id> --a "in qa"` y un `tablero comentar` que diga que ya está en 2.3. Añade al cuerpo del PR un bloque «Desbloqueo del 14-nov» con qué se resolvió y cómo se probó.

## Simulador

Tienes permiso para un **segundo simulador en la Max** (tope 2) si el primero lo usa otra sesión, o para el **iPhone 14 por Device MCP**. En la Mini, uno.

## Qué NO hay que tocar

- Nada fuera de los ficheros de este PR salvo lo mínimo para que compile y pase el gate con lo nuevo de 2.3.
- Ninguna funcionalidad nueva ni mejora adyacente: solo resolver y verificar.
- CloudKit Production, el gateway o el conector de producción, y los otros PR abiertos.

## Cómo se sabe que está bien

`/gate` en verde sobre el merge, el PR `818` en `MERGED` (o en cola con la razón dicha si se pasó el tope), y sus cards en `in qa`.

## Paso 0 (auto-contestado, sesión nocturna)

- **Transporte:** lo que apunta la IA entra en `mail_drafts` (la cola común de la D9) con `source: "ai"`, la cuenta y la
  subcategoría por `account_ref`/`subcategory_ref` (como la web) y además `account_name`, `subcategory_name` y `client`.
  Se retiran la tabla `connector_drafts`, las rutas `/connector/drafts(+ack)`, `ConnectorDraftDTO` y `AIConnectorDraftService`.
- **La clase RPC `ConnectorDrafts` se queda** como única puerta del conector (service binding): ahora escribe en la cola
  común. Darle al conector el D1 entero (como la web) reabriría lo que el ADR del PR descartó: alcanzaría entitlements y correo.
- **Techos:** 50 al día en `connector_quota` (migración `0004_connector_quota.sql`, sustituye a la 0004 del PR, que nunca se
  desplegó); 100 en cola contados en `mail_drafts` con `source = 'ai'`.
- **Recogida en el iPhone:** una sola, `BankEmailDraftService`. La app no sabe si hay una IA conectada, así que además de
  «correo preparado o web en 30 días» pregunta a la cola como mucho cada 2 minutos (la cadencia de la decisión P5 del lote 1
  de la web, que pregunta a la web cada 2 min). Asumido sin preguntar: equivale en carga a P5.
- **Al asentarse el import:** se reintenta la recogida solo si la última se saltó por el import (antes, la del PR corría en
  cada asentamiento).
