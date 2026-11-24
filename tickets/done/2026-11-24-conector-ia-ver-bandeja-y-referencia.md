---
id: 2026-11-24-conector-ia-ver-bandeja-y-referencia
status: done
area: "conector de IA, gateway, bandeja"
created: 2026-11-24
updated: 2026-11-24
source: "Jürgen, 24-nov (14:30 Lima): «sobre la propuesta para separar duplicados de distintas fuentes, vamos con todo lo recomendado». Lote 5 de docs/propuestas/bandeja-sin-duplicados/README.md"
---

# Conector de IA: ver la Bandeja, referencia y aviso de posible duplicado

## Qué se pidió
Que la IA conectada a Yala pueda ver lo que ya está pendiente, que el mismo origen (un correo) no deje dos
borradores, y que antes de apuntar algo que ya está en Yala la IA pregunte.

## Qué se entregó (solo servidor)
- **`ver_bandeja`** (conector): los pendientes de la Bandeja, con las columnas que ya ve Yala web y sin el texto
  original, y lo que espera en la cola del gateway (correo, web, IA). Sin Grupos.
- **`referencia`** en `apuntar_movimiento`: la misma en la misma cuenta no crea un segundo borrador ni gasta cupo;
  responde `ya_apuntado`. Se guarda solo su SHA-256, 90 días (`connector_refs`, migración D1 `0007`).
- **Aviso al encolar**: el gateway compara con la cola, los pendientes y lo guardado de ±3 días con la regla de la
  propuesta y devuelve `posible_duplicado` sin crear nada; con `forzar` se crea. Dos de la misma fuente nunca casan.
- Sin opciones, el gateway se comporta como antes: el conector de producción de hoy no cambia.

## Cómo se probó
- Gateway: `test/connector.match.test.ts` (la regla) y `test/connector.dedup.test.ts` (E5, E4, E6, E9, carrera de dos
  llamadas, techo, caducidad, lectura de la cola) sobre D1 real; suite entera verde.
- Conector: `test/verBandeja.test.ts` y `writeTool.test.ts`; suite entera verde.
- Staging, llamada real del conector: `mcp/test/e2e/bandeja.e2e.test.ts` 4/4 (E5 `ya_apuntado`, E6
  `posible_duplicado` contra un movimiento guardado y luego `forzar`, `ver_bandeja` con lo apuntado).

## Qué falta
- **Producción**: migración `0007`, gateway y conector desde 2.3, en ese orden (`mcp/RUNBOOK-produccion.md`, «Lote 5»).
- Otra divisa no se compara en el gateway (no tiene tipos de cambio): queda para el emparejador de la app (lote 1).
