---
id: 2026-11-24-bandeja-red-al-aprobar-mas-menos-un-dia
status: done
priority: medium
area: "inbox, duplicates"
created: 2026-11-24
updated: 2026-11-24
source: "propuesta «Bandeja sin duplicados entre fuentes», lote 0 (docs/propuestas/bandeja-sin-duplicados/README.md §5)"
---

# Bandeja: al aprobar, el aviso de duplicado mira ±1 día y nombra el gemelo

Escenario E2 de la propuesta (medido el 24-nov): un pago de Apple Pay a las 23:50 del 15 y el correo del banco fechado el
16 por el mismo importe se guardaban los dos al aprobar en lote, porque `InboxDuplicateCheck` solo miraba el mismo día de
calendario. Y el aviso decía «Ya existe un registro parecido» sin decir cuál.

Decisión de Jürgen (24-nov, 14:30 Lima): «vamos con todo lo recomendado»; el lote 0 entra en 2.3.

## Hecho cuando

- El posible duplicado mira el día anterior, el mismo y el siguiente; misma cuenta o sin cuenta, mismo signo, misma moneda
  e importe ±0,01.
- Dos compras iguales de la misma fuente que manda cada pago una vez (Apple Pay, correo del banco) no se marcan entre sí
  (E8).
- El aviso nombra el gemelo: comercio (o subcategoría) · importe · fecha, en los 16 idiomas.
- Pruebas de E2, del cruce de medianoche al revés y de E8.

## Resolución (2026-11-24)

- `InboxDuplicateCheck.findDuplicate` busca en la ventana `[inicio(d−1), inicio(d+2))` con signo, moneda de la cuenta del
  borrador, importe ±0,01 y cuenta igual o vacía; con varios candidatos elige el más cercano en el tiempo. Recibe la fuente
  del borrador y descarta un registro aprobado desde un borrador de la misma fuente si esa fuente es `applePay` o
  `emailAlert`. La IA, la web, el aviso del banco (comparte `automation` con la web), Siri, la voz y lo manual siguen
  avisando entre sí (E5 se conserva).
- El aviso de deslizar y el del borrador abierto leen el gemelo al detectarlo y dicen «Ya hay uno parecido: Wong · S/ 89.90
  · 15 oct. ¿Guardarlo de todas formas?» (clave `inbox.duplicateWarningNamed`). Título y botones sin cambios. El lote sigue
  diciendo cuántos retuvo.
- Pruebas: `YalaTests/BandejaRedMasMenosUnDia/` (17 casos) y el control de `InboxDuplicateCheckTests` pasa a «dos días» y
  «dos céntimos», que eran justo lo que la regla nueva cambia. XCUITest: `InboxDuplicateCheckUITests` (afirma que el aviso
  nombra el gemelo) y `BandejaRecurrenteDuplicadoUITests`, en verde.
- Grupos y cuentas compartidas, sin tocar.

## Fuera

- El iPhone 14 estaba ocupado (otra app lo espejaba); el flujo se probó en el simulador, como pide el encargo.
- Los lotes 1-5 de la propuesta (emparejador, unir al llegar, planificados, conector de IA) van a 2.4.
