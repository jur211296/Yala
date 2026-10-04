# panel-accounts-redesign — evidencia (2026-10-03)

Simulador `YalaLane-Adapt-iPhone-ProMax` (iOS 27.0), modo oscuro, seed `realista`, scheme `Yala Dev`.

| Captura | Qué se ve |
|---|---|
| `01-carrusel` | Tarjeta grande con «Saldo», importe y «≈ S/» en la cuenta en dólares; asoma la siguiente. |
| `02-vista-media-altura` | Tocar la tarjeta abre la vista: saldo, Entró / Salió, curva, primeros movimientos; «Editar» en la barra. |
| `03-vista-ampliada` | Subida: últimos movimientos y «Filtrar por esta cuenta». |
| `04-filtro-dos-cuentas` | Tras aplicar la hoja de filtros con dos cuentas: las dos tarjetas teñidas, chip «Ahorros USD +1», punto en el botón. |

Las capturas 02 y 03 son de antes de dos arreglos de la curva que entraron en el mismo PR: el eje con más de medio año
enseña mes y año (ahí aún sale «1 ene.» dos veces), y la curva empieza en el primer movimiento de la cuenta (ahí aún
arranca con una línea plana). Lo fijan los tests de `AccountDetailCalculatorTests`.

No capturado: iPhone SE, AX5 e iPad. El rediseño de la vista de cuenta en iPad (columna de detalle) no se construyó; su
tamaño lo decide la ventana (`yalaSheetDetents`).
