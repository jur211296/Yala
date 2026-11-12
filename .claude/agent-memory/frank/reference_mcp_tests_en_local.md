---
name: mcp-tests-en-local
description: Un calculador compartido (CashFlow, presupuestos) cambia también Yala IA y rompe el golden del conector mcp/; sus tests corren en local con npm ci --prefer-offline
metadata:
  type: reference
---

Tocar `CashFlowCalculator` o `BudgetsViewModel.calculateSpending` cambia las cifras de Yala IA (el builder del chat
los usa) y pone rojo `MCPAppParityGoldenTests`, aunque no toques nada del chat. El arreglo es portar la regla a
`mcp/src/logic/` y regenerar el golden desde la app: `TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1` delante del
`xcodebuild test-without-building -only-testing:YalaTests/MCPAppParityGoldenTests`, y después `npx vitest run` en `mcp/`.

**Why:** medido el 2026-10-23 (encargo de cifras de 2.2): 14 cifras del golden cambiaron por el movimiento sin
categoría. Ningún worktree trae `mcp/node_modules`, y daba la impresión de que no se podía verificar en local.

**How to apply:** `cd mcp && npm ci --prefer-offline --no-audit --no-fund` funciona desde la caché de npm (sin red) en
~1 min; luego `npm run typecheck` y `npx vitest run`. `node_modules` está ignorado. Desplegar el conector es de Jürgen.
