---
id: 2026-11-25-esto-lei-moneda-descripcion-sin-hueco
status: done
priority: medium
area: "voice-image, esto-lei"
created: 2026-11-25
updated: 2026-11-25
card: tablero-esto-lei-moneda-editable-descripcion-con-oefq
source: "Jürgen, 25-nov-2026, tras probar la hoja en su iPhone"
---

# Esto leí: moneda editable, descripción con más peso y sin hueco arriba

## Qué pidió Jürgen (25-nov, 8:04 Lima)

Tras probar la hoja «Esto leí» en su iPhone («está muchísimo mejor esta vista»), tres ajustes a la tarjeta de un
registro (`VoiceDraftReviewCard`):

1. **Moneda editable.** Tocar «S/» abre las mismas monedas que Nuevo registro. Elegir una moneda acota el chip de
   cuenta a las cuentas de esa moneda.
2. **Más peso a la descripción.** «Claro» se veía fina y gris clara.
3. **Quitar el hueco de arriba a la izquierda**, que dejaba «Ver todo» arriba a la derecha.

## Qué se hizo

**Un registro** (`VoiceDraftReviewCard`):
1. **Moneda.** La cápsula ofrece las monedas de las cuentas, con la lógica de Nuevo registro (`AmountCurrencyMenuLogic` vía `EstoLeiCurrencyChoice`). Elegir una moneda pone la cuenta que la tiene y se guarda al momento. El selector de cuenta recibe `currencyScope` (`ChatDraftFieldSheet`, opcional): solo las cuentas de esa moneda, o todas con su aviso si no hay ninguna.
2. **Descripción.** `headline` en el color del texto, también en el editor en línea. El monto sigue mandando.
3. **Hueco.** «Ver todo» es un chevron a la derecha, centrado en vertical, toque de 44 pt, mismo id y etiqueta. Sin relleno superior extra. La fila de chips va a todo el ancho.
4. El chip de cuenta dice «Cuenta» (no se corta); VoiceOver oye «Selecciona cuenta».

**Varios** (pedido por Jürgen en vivo): la fila desplegada es la misma tarjeta (`EstoLeiCardStyle.row`), centrada, con check y chevron a media altura, borde índigo y despliegue animado. Un toque en cualquier parte de una fila cerrada la despliega. Un registro incompleto no cuenta como marcado: check vacío y apagado; al completarlo se marca solo. «Guardar» guarda solo lo marcado de verdad (antes un incompleto cortaba el guardado a la mitad). Si la hoja se queda a media altura, fondo de cristal.

**«S/ ▾» centrada con el monto** en las siete pantallas que la llevan.

## Pruebas

- Unitarias: `YalaTests/EstoLeiAjustesCard/EstoLeiAjustesCardTests.swift` (nueva) y `MultiDraftReviewLogicTests` (regla del check).
- Interfaz: `MultiDraftReviewUITests` y `EstoLeiRecorridoUITests` actualizadas; corridas con las de foto, voz y cuenta sola.
- iPhone 14: antes y después en el artifact https://claude.ai/artifact/NdSGfyh67rfrCjBkC8Rk1R

## Fuera

- La espera del esqueleto del Panel al entrar: card en el tablero.
- Por qué la hoja de varios a veces no sube sola a grande: no se reprodujo.
