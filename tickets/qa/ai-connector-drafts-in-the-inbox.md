---
id: ai-connector-drafts-in-the-inbox
status: qa
priority: high
area: cloud, mcp, inbox
created: 2026-11-05
updated: 2026-11-05
source: encargo 2026-11-05-tu-ia-registra-en-yala (card «Tu IA registra en Yala», decisión de Jürgen del 21-oct)
---

# Tu IA registra en Yala: Claude, ChatGPT y Grok dejan borradores en la Bandeja

## Qué cambia para el usuario

Con Yala conectado a su IA, la persona dice «apunta 25 soles de almuerzo» y, al abrir Yala, tiene el movimiento en la
Bandeja con la etiqueta «Tu IA» y la IA que lo apuntó («Claude») como evidencia. Si la IA nombró cuenta y categoría,
sale listo para guardar de un toque; si no, la Bandeja las pide. Nada cuenta hasta confirmarlo, y la IA no puede
cambiar ni borrar nada.

## Qué se hizo

- **Conector (`mcp/`):** herramienta `apuntar_movimiento` (`src/writeTool.ts`). Valida, resuelve la cuenta y la
  subcategoría por nombre contra las de la persona (error con opciones si no existe o es ambigua) y encola en el
  gateway por un service binding. La sesión de Supabase sigue siendo de solo lectura. Sin el binding, la herramienta no
  se ofrece. La pantalla de permiso lo dice. Vueltas OAuth de ChatGPT en la lista; las demás, por
  `EXTRA_REDIRECT_URIS`, y una vuelta rechazada queda en el log para fijarla (Grok). La herramienta solo se ofrece a
  conexiones cuyo permiso lo decía (`GrantProps.drafts`): quien conectó como solo lectura tiene que reconectar.
- **Gateway:** cola `connector_drafts` (migración 0004), clase RPC `ConnectorDrafts` (sin ruta pública), rutas
  `GET /connector/drafts` y `POST /connector/drafts/ack` con App Attest, 50 al día y 100 en cola por cuenta, y el
  borrado de cuenta la vacía.
- **App:** `AIConnectorDraftService` los recoge al volver a primer plano (con la nube y sesión) y crea el borrador
  `.aiConnector` («Tu IA», 16 idiomas). Mismo cliente que el correo del banco (`BankEmailClient`). Si otro aparato de
  la persona ya lo creó y le llegó por el sync, no lo duplica (mismo instante de llegada, importe y nota).
- **Guía para conectar cada IA:** `mcp/CONECTAR-TU-IA.md`. La guía dentro de la app se difiere al deploy de
  producción del conector (decisión de Jürgen, 5-nov): hoy no hay dominio ni URL que enseñar.

## Verificado

- Conector: `npm test` (247), con el flujo MCP entero contra un Supabase falso: el almuerzo llega a la cola con cuenta
  y subcategoría resueltas, ninguna salida a Supabase que no sea GET, ChatGPT entra y sus primas no, Grok se rechaza y
  se anota. Dos mutantes (vuelta de ChatGPT y filtro de ingreso) caen.
- Gateway: `npm test` (connector.test.ts, 24 casos): validación, techos, cola por cuenta, encolar sin ruta, borrado.
- App: `AIConnectorDraftTests` — el almuerzo resuelto sale listo para guardar (`InboxSaveReadyLogic.ready`), cuenta en
  otra divisa o subcategoría del otro lado no se ponen, los dos métodos llevan App Attest.
- **No** se desplegó nada: ni staging ni producción (los Workers los despliega Dan, decisión del 5-nov).

## QA (staging, cuando Dan despliegue)

1. Gateway de staging: `cd gateway && npm run migrate:staging && npm run deploy:staging`. Luego el conector:
   `cd mcp && npm run deploy:staging` (en ese orden).
2. En el iPhone con **Yala Dev** y una cuenta de la nube de staging, abrir Yala una vez.
3. En Claude (o ChatGPT con modo desarrollador), conectar `https://yala-mcp-staging.misty-surf-6866.workers.dev/mcp`
   con la misma cuenta. La pantalla de permiso dice «quiere usar tus datos de Yala» y «podrá apuntar».
4. Pedir: «apunta 25 soles de almuerzo en Restaurantes con mi cuenta BCP» (con nombres que existan en esa cuenta).
5. Volver a Yala (mandarla al fondo y abrirla). En la Bandeja: «Almuerzo», −25, etiqueta «Tu IA», cuenta y
   subcategoría puestas. Deslizar para guardar: entra en Registros.
6. Pedir «apunta 10 soles de taxi» sin cuenta: el borrador sale pidiendo cuenta y categoría.
7. Grok: añadir el conector en grok.com/connectors. Esperado: «Esta aplicación no está autorizada…». Copiar la vuelta
   del log (`npx wrangler tail | grep vuelta_no_permitida`), ponerla en `EXTRA_REDIRECT_URIS`, desplegar y repetir.

## Fuera de alcance

- Guía en la app (con el deploy de producción).
- Ver qué IA está conectada y desconectarla desde Ajustes: `claude-mcp-connected-apps-in-the-app`.
- Deduplicar si la IA repite la misma llamada: no hay clave de idempotencia; cada llamada es un borrador.
- Dos aparatos que traen la cola a la vez, antes de que el sync lleve el borrador del uno al otro, crean dos.
