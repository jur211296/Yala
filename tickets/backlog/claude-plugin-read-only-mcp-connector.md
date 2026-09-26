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

Hay exploración hecha, sin código: `docs/exploracion/plugin-claude-mcp.md`. Recoge las herramientas,
el encaje con OAuth y RLS, el paralelismo con la cola A, los requisitos del portal de Anthropic y las
fases.

## Lo que espera de Jürgen antes de construir

Las cuatro decisiones de §6 del documento:

1. Gratis o Pro.
2. Si vale un conector solo para usuarios en modo nube.
3. Cuándo empezar.
4. Cambiar «suscripciones sin usar» por «recurrentes a revisar».

## Primer paso cuando se desbloquee

La fase 0, un spike en staging de 1-2 días. Cierra los NO VERIFICADO del documento, y el más
importante es si un token OAuth de Supabase puede quedar de verdad en solo lectura.

## Dependencias

- Modo nube estable en producción, con el sign-in real verificado.
- `session-redesign-web-and-store-copy`: la política de privacidad todavía dice que no hay servidores
  propios.
- `ci-no-corre-la-suite-del-gateway`: el MCP necesitará su suite en CI.
