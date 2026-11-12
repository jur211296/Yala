---
esfuerzo: high
---
# Welcome solo-grupos: C2 (cerrar el formulario del primer grupo te deja dentro)

**Card:** `tablero-welcome-solo-grupos-c2-cerrar-el-formula-ycke` · Yala 2.2 · high · cierre cierra-sola  
**Decisión Jürgen 24-oct:** C2 en sesión aparte de A+B. **No es C** (entrar a Grupos sin crear ni enlace): no implementes C.

## Fuentes
- Estudio § C2: `~/Claude/entregas/Yala--estudio-welcome-onboarding-solo-grupos/2026-10-24-welcome-caminos-solo-grupos.md`
- Card hermana A+B: `tablero-welcome-solo-grupos-a-b-copy-salida-en-p-jyhh` (preferible rebase encima de su PR/merge si ya existe).

## Qué se pide (variante C2 del estudio)
Hoy, en el camino Welcome → crear mi primer grupo, **cerrar el `GroupFormView`** (paso 3a) **vuelve al Welcome** (hallazgo H6).

**C2:** mantener los dos caminos (crear / me invitaron). Solo cambiar el `onDismiss` del formulario del primer grupo:
1. Si ya hay nombre escrito → completar el alta con ese nombre y **aterrizar en Grupos vacío** (dentro de la app), no en el Welcome.
2. Si el nombre está vacío → preguntar en una línea (no echar al Welcome).
3. No abras un flujo «solo grupos abierto» tipo Splitwise (eso sería C).

## QA completo autónomo (pedido Jürgen 24-oct)
- Sim: Welcome → Dividir gastos / crear primer grupo → rellenar algo → cerrar formulario → quedas en Grupos, no Welcome. Caso nombre vacío. Camino «me invitaron» no se rompe.
- Tests/XCUITest del Welcome/alta afectados en verde.
- Capturas antes/después.
- **Card a `done` tú** si el QA en sim basta. **Solo `in qa` + jurgen** si necesita device/decisión suya; nota con guion.

## Qué NO hay que tocar
- Copy A/B (otra card), C entero, marketing/, sin deploy.

## Base y Mini
- `origin/2.2`, PR a **2.2**. Si A+B ya tiene PR/merge, rebase encima.
- Pipeline serial Mini; `nice -n 10 xcodebuild -jobs 2`; un sim; cleanup al cerrar; `/cerrar-total`.

## Cómo se sabe que está bien
Cerrar el form del primer grupo deja dentro en Grupos; tests verdes; capturas; PR; card done (o in qa solo si Jürgen es imprescindible).

## Contexto adicional (actualizado 2026-10-24 14:15 Lima)
- A+B ya cerró: **PR #620** (https://github.com/jur211296/Yala/pull/620) está en cola de auto-merge a `2.2`. Arranca sobre `origin/2.2`. Justo antes del gate, mira si #620 sigue en CI: si sigue, espera a que entre y rebasa una sola vez con el simulador apagado; si su CI falla, no esperes, rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
- A+B dejó en backlog un caso menor del «Volver» (`welcome-groups-back-forgets-first-time-after-invite-screen`). No es de este encargo, no lo arregles aquí.
- No toques el cambio del scheme que hay sin commitear en el árbol principal `~/Yala` (no es tuyo).

## Limpieza Mini (sin preguntar)
Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo. Al cerrar: apaga y borra el simulador que usaste, quita el worktree si el PR ya no lo necesita. Si algo falla, dilo en el cierre.

## QA mínimo (regla Jürgen 2026-10-24)
Prueba lo indispensable en el simulador para este camino; si hay test del flujo completo y el sim lo replica bien, confía en el código y las pruebas.

Cierra con /cerrar-total.

## Paso 0 (Frank, 2026-10-24 — auto-contestado, MODO lanzado)

1. **«El nombre» es el de la persona** («Tu nombre en el grupo»), porque es lo único que pide el alta. El nombre del
   grupo no se usa al cerrar: cerrar no crea el grupo. *Asumido.*
2. **Nombre vacío → una alerta de una línea** «¿Cómo te llamas?» con un campo y dos salidas: «Continuar» (apagado
   sin nombre) completa el alta y entra en Grupos; «Cancelar» deja el formulario como estaba. *Asumido; el copy, con
   BRAND-VOICE.*
3. **Sin canal de grupos (`route != .backend`) se queda lo de antes** (vuelta al elector): sin canal el alta no se
   escribe (C4), y entrar a un Grupos que no puede crear nada sería otro callejón. *Asumido.*
4. **Un solo sitio llama al alta** dentro del formulario (los source-scan cuentan ×1): guardar y cerrar comparten una
   función. El respaldo del `onDismiss` de `ContentView` (UIKit tumbando el cover) no cambia.
5. **Capturas:** el «antes» sale del XCUITest nuevo con el arreglo revertido (rojo) y el «después» del mismo test en
   verde. Un build por pasada, tras el rebase.
6. **Base:** #620 (A+B) toca `L10n.swift`, los 16 `Localizable.strings`, `WelcomeChooserUITests` y el índice: rebase
   una vez antes del build; si sigue sin entrar, encima de su rama.
