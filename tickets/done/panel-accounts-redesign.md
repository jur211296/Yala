---
id: panel-accounts-redesign
status: done
created: 2026-05-13
updated: 2026-10-03
source: YalaWiki/Ideas/Rediseño cuentas en Panel.md
---


# Rediseño de las cuentas en el Panel: tarjetas grandes, vista de cuenta y filtro en la toolbar

## La idea
>mas espacio. Clic abre sheet. Editar dentro e sheet. Añadir filtro a toolbar. 

## Por que importa
>

## Notas
-

migrated from YalaWiki Ideas/Rediseño cuentas en Panel.md @ 1934e8ad

## En iPad (heredado de `cola-b-redesigns-must-hold-up-at-ipad-width`, 2026-10-03)

El detalle de cuenta, pensado para poder ir en la columna de detalle de un lista-detalle en iPad: sin asumir que es una
hoja ni que ocupa la pantalla entera, con ancho legible (`DS.Adaptive.readableWidth`) y el margen adaptativo. Si es una
`List` con márgenes propios, el margen se cuenta desde la columna de lista (`.claude/rules/swiftui-ds.md`, «Una `List`
con `contentMargins` propios…»). Capturar en `YalaLane-Adapt-iPad-mini` y `-iPad-Pro-13`, y en iPhone en
`YalaLane-Adapt-iPhone-SE` y `-ProMax` con texto por defecto y AX5. Nada decide por tipo de aparato ni por orientación.

## Lo que se hizo (2026-10-03)

La cita se resolvió con Jürgen en la sesión, sobre un lienzo de propuestas
(https://claude.ai/artifact/LvWp7bj43PJY1S2Rin9Cu3, páginas «Propuestas del Panel» y «Rediseño de cuentas»). Es la
**primera entrega** del rediseño de cuentas; las siguientes son `accounts-settings-list-redesign`,
`account-form-redesign` y `account-collections`.

- **«Más espacio»**: carrusel de tarjetas grandes (una entera y la siguiente asomando, 80 % del ancho con techo de
  320 pt), blancas con el color de la cuenta en el icono y **teñidas de ese color cuando la cuenta está en el
  filtro**. Sin ruedita de editar. Encima del importe, qué es: «Saldo», «Por pagar» (tarjeta de crédito con deuda) o
  «Gastado · período» (modo solo gastos); en otra moneda, debajo, el equivalente «≈» en la principal.
- **«Clic abre sheet»**: tocar la tarjeta abre la **vista de la cuenta** (`AccountDetailSheet`). A media altura:
  saldo, qué entró y qué salió en el período del Panel y la curva del saldo; al subirla, en qué se fue el gasto, los
  últimos movimientos y «Filtrar por esta cuenta».
- **«Editar dentro del sheet»**: «Editar» en la barra de esa vista abre el formulario de cuenta encima.
- **«Filtro en la toolbar»**: botón de filtros en el Panel con la hoja de Estadísticas e Informes; deja filtrar por
  **varias cuentas** a la vez, cosa que el Panel no permitía.
- Pedido en la sesión: fuera la frase de IA de «Tus finanzas» y su botón, y con ellos toda la generación de ese
  mensaje (ya no se enseñaba en ningún sitio). «Tus finanzas» conserva el nombre, la salud y el plegado.

Supuestos y decisiones en el Paso 0 del encargo (`encargos/lanzados/2026-10-03-panel-accounts-redesign.md`). iPad:
no se armó lista-detalle; la vista de cuenta va a ancho legible y su tamaño lo decide la ventana.

