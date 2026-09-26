---
id: claude-plugin-read-only-mcp-connector
status: backlog
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-plugin-claude-mcp-exploracion; diferido #22 de docs/modo-nube/MODO-NUBE-DIFERIDOS.md
---

# Plugin de Yala para Claude: que Claude lea tus finanzas de la nube, sin poder tocarlas

## Qué cambia para el usuario

Quien tiene Yala en modo nube conecta Yala a Claude con su cuenta de Apple o Google, y puede
preguntarle «¿cuánto llevo gastado este mes?», «¿cómo voy con el presupuesto?» o «¿qué pago cada mes?».
Claude lee sus saldos, movimientos, categorías, presupuestos y pagos recurrentes. No puede escribir
nada, y el usuario puede revocar el acceso cuando quiera.

## Estado

**Fase 0 hecha en staging** (2026-09-26, encargo `2026-09-26-plugin-claude-mcp-fase0-spike`):

- Claude Code se conectó al conector de staging, se autenticó por OAuth y respondió con los datos reales del
  usuario de prueba. Otro usuario no ve esos datos.
- `mcp/`: Worker `yala-mcp-staging` con las seis herramientas de solo lectura, la pantalla de consentimiento,
  49 tests unitarios en el CI (job `mcp`) y 17 e2e contra staging.
- Staging: rol `yala_mcp_reader` y su hook (`qa/cloud/mcp0_01_readonly_role.sql`), y el servidor OAuth encendido
  (`tickets/done/claude-mcp-activate-oauth-in-staging.md`).
- `mcp/plugin/`: borrador del plugin con tres skills, entre ellas `recurrentes-a-revisar`. Sin publicar.
- Lo aprendido y lo que falta: §7 de `docs/exploracion/plugin-claude-mcp.md`.

**Bloqueo para la fase 1:** el token de Claude no puede escribir en las finanzas, pero GoTrue le deja cambiar la
cuenta de inicio de sesión (`claude-mcp-oauth-token-can-change-the-account`).

## Decisiones de Jürgen (2026-09-26)

1. Gratis por defecto. Queda un punto de extensión (`plan` en cada herramienta) para marcar alguna como Pro.
2. Vale que solo sirva a usuarios en modo nube.
3. Producción espera a que la nube esté estable, tras 2.1. La fase 0 va ya, solo en staging.
4. «Suscripciones sin usar» pasa a «recurrentes a revisar».

## Residuales

- `claude-mcp-oauth-token-can-change-the-account` — el token de Claude puede cambiar la cuenta vía GoTrue. Bloquea la fase 1.
- `claude-mcp-numbers-match-the-app` — golden vectors desde Swift, gastos de grupo, tasa del día, zona horaria.
- `claude-mcp-consent-with-apple-and-google` — iniciar sesión con Apple o Google en la pantalla de permiso.
- `budget-interval-counts-next-period-midnight` — bug de la app encontrado al portar los presupuestos.

## Dependencias

- Modo nube estable en producción, con el sign-in real verificado.
- `session-redesign-web-and-store-copy`: la política de privacidad todavía dice que no hay servidores
  propios.
- `ci-no-corre-la-suite-del-gateway`: el MCP necesitará su suite en CI.
