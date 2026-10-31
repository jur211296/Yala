---
esfuerzo: high
release: no
---
# Editar cuenta de doble línea: un saldo inicial por moneda, renombrar arrastra las líneas y la hoja abre a pantalla completa

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `editar-cuenta-doble-linea` · Sesión cola **S30** · al cerrar → **S31** (`formularios-modelo-borrado`).

## Contexto
En una cuenta con líneas PEN y USD (p. ej. BCP Débito), Editar cuenta muestra un solo campo de saldo inicial. Jürgen (2026-10-30): si la cuenta tiene más de una línea, Editar cuenta muestra un selector de moneda (segmented control, como en otras vistas) y cada línea tiene sus propios campos (saldo inicial, etc.); desde ahí se puede eliminar una línea u otra.
Bug extra en la misma pantalla: al renombrar la cuenta principal, sus líneas conservan el nombre viejo (`AccountCardLogic.lineName` arma «<nombre> · USD» solo al crear la línea). Caso real: la cuenta se llama «BCP Débito» y su línea sigue «BCP Débito Soles · USD».
Y la hoja de Editar cuenta abre en detent medium; Jürgen la quiere siempre a pantalla completa. Dónde (origin/2.2): `Yala/App/Views/Accounts/AccountFormView.swift` — `selectedDetent = .medium` (~L49), `sheetDetents` (~L54), `.yalaSheetDetents` (~L183); se presenta desde `PanelSheetsModifier.swift` (~L53) y `AccountDetailSheet.swift` (~L143). El mismo formulario sirve para crear y editar (`accountToEdit`).

Cards:
- `tablero ver tablero-editar-cuenta-de-doble-linea-un-saldo-in-ewjs`
- `tablero ver tablero-editar-cuenta-abre-siempre-a-pantalla-co-mfxf`

## Qué se pide
1. Editar cuenta multi-divisa: segmented control por moneda; cada línea guarda su saldo inicial y sus datos; eliminar una línea con confirmación, sin dejar la cuenta sin líneas; se sincroniza.
2. Renombrar la cuenta principal renombra sus líneas (respetando nombres únicos) y una migración arregla las líneas existentes cuyo prefijo ya no coincide.
3. Editar cuenta abre directo a pantalla completa (desde Panel y desde el detalle). Crear cuenta: decide la opción conservadora (solo editar a large si crear no se ve afectado) y anótalo en el PR.
4. Tests unitarios + XCUITest del caso; capturas antes/después en `capturas/` del worktree.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Otras pantallas de cuentas fuera de Editar cuenta y la lógica de nombres de línea. Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (decisiones, auto-contestadas en modo autónomo)

1. **Dónde va el selector de moneda.** Solo al editar una cuenta principal con al menos una línea viva. Va encima del
   bloque del saldo: un segmento por divisa (la de la cuenta primero, luego sus líneas). Nombre, tipo, color y tarjeta
   siguen siendo de la cuenta entera: el selector solo cambia el bloque del saldo.
2. **Qué edita cada línea.** Su saldo inicial (con signo), que se guarda con el «Guardar» del formulario, en el mismo
   guardado que la principal. «Editar el saldo» con corrección por diferencia sigue siendo de la principal: en la
   línea el campo es el saldo de partida (lo conservador: no inventa un segundo flujo de corrección).
3. **Eliminar una línea.** Botón en el segmento de la línea. Vacía: confirmación corta. Con movimientos, programados,
   favoritos o borradores: la hoja de siempre de «¿Qué hacemos con lo que hay dentro?», que ya pregunta y no borra
   nada sin elección. La cuenta principal no se ofrece desde aquí («Eliminar cuenta» sigue donde estaba), así que la
   tarjeta nunca se queda sin líneas. Tras eliminar, el formulario sigue abierto en la divisa de la cuenta.
4. **Renombrar arrastra las líneas.** Solo las líneas cuyo nombre empieza por «<nombre viejo> · »: un nombre que la
   persona personalizó sin ese patrón no se toca. Nombre nuevo con `AccountCardLogic.lineName` (único).
5. **Migración.** Pasada idempotente en cada arranque, tras la quiescencia del import (molde Live Balance, sin flag
   de una vez: una línea que llega tarde por sync también se arregla). Renombra solo una línea válida cuyo nombre tiene
   la forma «X · <su divisa>[ N]» con X distinto del nombre de su principal **y prefijo de él o al revés, por palabras**
   («BCP Débito Soles» bajo «BCP Débito»). Así no pisa una línea renombrada a mano ni una cuenta vinculada con su propio
   nombre (lo cazó la review). Un cambio de nombre sin esa relación («Visa» → «Amex») no se repara: desde ahora lo
   arrastra renombrar la tarjeta.
6. **Pantalla completa.** Editar abre en `.large` y sin `.medium` (desde Panel, detalle y Ajustes: es el mismo
   formulario). Crear no cambia: sigue a media altura (opción conservadora).
