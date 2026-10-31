---
id: account-edit-multi-currency-lines
status: qa
priority: high
area: account-lines
created: 2026-10-30
updated: 2026-10-31
source: tablero-editar-cuenta-de-doble-linea-un-saldo-in-ewjs
---
# Editar cuenta de doble línea: un saldo inicial por moneda, renombrar arrastra las líneas y la hoja abre a pantalla completa

Encargo S30 (cards `ewjs` y `mfxf`). Implementado el 2026-10-31; lo que pide el iPhone es ver la reparación del nombre
sobre los datos reales (BCP Débito) y el saldo de una línea en un teléfono con sincronización.

## Qué cambió

- Editar cuenta abre a pantalla completa (Panel, ficha de la cuenta y Ajustes). Crear sigue a media altura.
- Una cuenta con líneas enseña un selector por divisa. En una línea se edita su saldo inicial y se elimina la línea
  (vacía: confirmación; con registros: la hoja de «¿Qué hacemos con lo que hay dentro?»).
- Renombrar la cuenta renombra las líneas que empiezan por «<nombre viejo> · ».
- Al arrancar, una reparación renombra las líneas que se quedaron con el nombre viejo, solo si el nombre viejo y el de
  hoy son uno prefijo del otro («BCP Débito Soles» → «BCP Débito»).

Cubierto en el simulador: `YalaTests/AccountEditMultiCurrencyTests` y `YalaUITests/AccountEditMultiCurrencyUITests`.

## Guion de device-QA (Yala Dev, tu iPhone con tus datos)

1. Instala el build de `2.2` que trae este cambio en Yala Dev y ábrelo. Espera a que el Panel cargue del todo.
2. Ve a **Ajustes › Cuentas**. Debajo de «BCP Débito», la línea debe llamarse **«BCP Débito · USD»** (antes:
   «BCP Débito Soles · USD»). Si no cambió, cierra Yala del todo y ábrela otra vez: la reparación corre al arrancar,
   cuando termina de bajar iCloud.
3. Vuelve al Panel, toca la tarjeta de **BCP Débito** y luego **Editar**. La hoja debe abrir **a pantalla completa**,
   sin pasar por media altura.
4. Baja hasta el selector **🇵🇪 PEN | 🇺🇸 USD** y toca **USD**. Sale «Balance inicial» de la línea en dólares.
   Escribe el saldo con el que empezó (o déjalo como está) y toca **✓**.
5. Abre otra vez Editar y toca **USD**: el saldo escrito sigue ahí. En la ficha de BCP Débito, el saldo en dólares
   refleja el cambio.
6. Opcional, si tienes otro dispositivo con Yala Dev: comprueba que el nombre de la línea y su saldo llegan allí.

**No hace falta probar «Eliminar la línea»** con tus datos: borra de verdad y está cubierto en el simulador.
