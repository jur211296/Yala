---
id: 2026-11-17-comparativa-simple-variacion-color
status: done
priority: medium
area: "reports, comparativa"
created: 2026-11-17
updated: 2026-11-18
source: "Pedido de Jürgen del 17-nov (20:48 Lima), captura de Reportes › Comparativa en su iPhone"
---

# Comparativa más simple y visual: % de variación e indicador de color por fila

Cada fila de la Comparativa (Ingresos, Gastos, cada categoría) enseñaba el monto actual y debajo, en gris, «en 1–17 de
oct. S/ X». El cambio iba en un chip pequeño, índigo o rosa, con el signo pegado al número. Costaba ver de un vistazo si
ibas mejor o peor que antes.

## Variantes

- **A · Dos líneas por celda (elegida).** Nombre · monto actual con el anterior debajo, pequeño y sin «en …» · marca de
  cambio con flecha y color. La cabecera nombra los dos períodos una vez, también en dos líneas. En ventana ancha (iPad,
  Duo abierto) el anterior pasa a su propia columna.
- **B · Cuatro columnas también en iPhone.** En 402 pt el nombre se quedaba con ~50 pt; en el SE no cabe. Solo sirve en
  ventana ancha, y ahí es lo que hace A.
- **C · Barras por fila.** Lo más visual, pero cada fila mide el doble y la tabla deja de leerse como tabla.

## Hecho

- Marca de cambio (`ComparisonChangeBadge`, lógica en `ComparisonChange`): ▲/▼ y el porcentaje sin signo; verde si el
  cambio favorece (más ingresos, menos gasto, más «Te quedó»), rosa de marca si no; gris por debajo del 1 %; «igual» si
  redondea a 0 %; «nuevo» sin dato anterior; «—» sin nada ni antes ni ahora. Más de 999 % se escribe «> 999 %».
- La fila apilada (nombre arriba, cifras debajo) entra desde XXL: a XXL la tabla partía «Trans-porte» por sílabas.
- VoiceOver: «Gastos, S/ 7,206.00, bajó 3.3% frente a setiembre, antes S/ 7,451.00». Textos en `ComparativaSimple.strings`
  de los 16 idiomas.
- «Te quedó» usa la misma marca (`NetFlowSummaryView`, fuera del `toca:` del encargo, una pieza).

## Decidido sin consultar

- Verde = `groupOwedAmount`, rojo = `groupOweAmount` (el rosa de marca que Jürgen eligió como rojo el 3-nov).
- Sin barra de magnitud: la marca de color ya da el escaneo.
- «Mostrar variaciones» apagado sigue escondiendo la marca.

Fuera: Flujo de caja.
