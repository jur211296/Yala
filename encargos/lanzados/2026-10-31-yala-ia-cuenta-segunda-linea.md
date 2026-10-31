---
esfuerzo: medium
release: no
---
# Yala IA: se puede volver a cambiar la cuenta tras elegir una segunda línea

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `yala-ia-cuenta-segunda-linea` · Sesión cola **S35a** · al cerrar → **S35b** (`sheets-detent-glass`).

## Contexto
Jürgen (2026-10-30): en Yala IA pide un registro, en la tarjeta propuesta cambia la cuenta a la segunda línea (USD) de una cuenta de doble línea (ej. BCP Débito · USD) y después ya no le deja volver a cambiar la cuenta.

Cards:
- `tablero ver tablero-yala-ia-tras-elegir-la-segunda-linea-de-y1z6`

## Qué se pide
1. Reproduce en simulador con una cuenta de doble línea, escribe un test que falle y arregla la causa raíz.
2. Revisa el mismo selector con cuentas de doble línea en Nuevo registro, edición de registro y Nuevo gasto de Grupos.
3. Capturas en `capturas/`.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
El resto de Yala IA. Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Causa (medida por lectura, se confirma con test rojo):** al elegir la línea USD, `updateDraft` pone la divisa del borrador en USD. Al volver a tocar la tarjeta, `cardAccount` la enruta con esa divisa y devuelve la misma línea USD: el borrador no cambia y parece que el selector no responde.
2. **Regla del arreglo (la conservadora):** si la cuenta tocada es la cabeza de la MISMA tarjeta en la que ya está el borrador, se respeta tal cual (la principal). Desde otra tarjeta o sin cuenta, sigue el enrutado por divisa de la decisión 6. Sin campo nuevo en el borrador ni cambios de UI.
3. **Nuevo registro / edición:** tienen las pastillas de divisa de la tarjeta y su selector enruta por `viewModel.currencyCode`. Se mide en simulador; solo se toca si reproduce el mismo bloqueo.
4. **Gasto de Grupos:** el selector va con `currencyFilter` (lista plana, sin enrutado). Se revisa en simulador; no se espera cambio.
5. **Tests:** unit en `AccountCardCaptureTests` (rojo antes, verde después) + XCUITest con el seed `tarjeta-dos-lineas` y `-uitest-chat-draft`.
