Yala
# Correos del banco: guía para principiantes y poder volver a pasos anteriores
---
toca: Yala/App/Views/Settings/BankEmailForwardingView.swift,Yala/App/DesignSystem/StepGuide.swift,Yala/Utils/L10n+CorreosBancoGuia.swift,Yala/Resources/es-419.lproj/CorreosBancoGuia.strings,Yala/Resources/es.lproj/CorreosBancoGuia.strings,Yala/Resources/es-AR.lproj/CorreosBancoGuia.strings,Yala/Resources/es-ES.lproj/CorreosBancoGuia.strings,Yala/Resources/en.lproj/CorreosBancoGuia.strings,Yala/Resources/en-GB.lproj/CorreosBancoGuia.strings,Yala/Resources/pt-BR.lproj/CorreosBancoGuia.strings,Yala/Resources/pt-PT.lproj/CorreosBancoGuia.strings,Yala/Resources/pt.lproj/CorreosBancoGuia.strings,Yala/Resources/fr.lproj/CorreosBancoGuia.strings,Yala/Resources/de.lproj/CorreosBancoGuia.strings,Yala/Resources/it.lproj/CorreosBancoGuia.strings,Yala/Resources/ja.lproj/CorreosBancoGuia.strings,Yala/Resources/nl.lproj/CorreosBancoGuia.strings,Yala/Resources/pl.lproj/CorreosBancoGuia.strings,Yala/Resources/zh-Hans.lproj/CorreosBancoGuia.strings,YalaTests/CorreosDelBancoGuia/,tickets/backlog/2026-11-23-correos-del-banco-claridad-y-volver.md,tickets/done/2026-11-23-correos-del-banco-claridad-y-volver.md
esfuerzo: medium
cierre: cierra-sola
---

Pedido de Jürgen (23-nov, pruebas de Yala 2.3 en iPhone sobre «Correos del banco» / «Reenviar desde Gmail»).

## Problemas reportados por Jürgen
1. **Claridad para principiantes («for dummies»):** la guía de reenvío desde correo necesita explicaciones súper claras y paso a paso para alguien que nunca configuró un reenvío ni un filtro en Gmail (o en los demás proveedores que soporte `BankEmailForwardingView`): dónde entrar exactamente, qué botón tocar y qué va a ver en cada paso.
2. **No deja volver a un paso anterior:** si el usuario toca un botón por casualidad y avanza (por ejemplo llega al paso 3 de 5 sin haber terminado el paso 1 o el 2), los pasos completados quedan cerrados con un check y no puede volver atrás para reabrirlos, copiar de nuevo la dirección o completar lo que faltaba.

## Qué se pide
1. Permitir volver libremente a cualquier paso anterior en `StepGuide` / `BankEmailForwardingView`:
   - Tocar un paso ya completado debe reabrirlo/seleccionarlo de inmediato (con indicación visual clara de que se puede tocar o botón «Paso anterior» cuando corresponda).
   - Revisar que otros usos de `StepGuide` en la app no se rompan con esta mejora (y se beneficien si aplica).
2. Reescribir y enriquecer las instrucciones de cada paso en `BankEmailForwardingView` (para Gmail y los demás proveedores soportados) en lenguaje cotidiano y ultra claro para principiantes, dejando además siempre accesible copiar la dirección `@yalainbox.com` sin tener que pelearse con los pasos.
3. Usar la tabla dedicada `CorreosBancoGuia.strings` (todos los idiomas del proyecto; español neutro latinoamericano, nunca español de España) para evitar chocar con `Localizable.strings`.
4. Agregar pruebas unitarias en `YalaTests/CorreosDelBancoGuia/` cubriendo la navegación hacia atrás/reapertura de pasos anteriores en el estado de la guía.

## Pruebas, entorno y cierre
- Base: `origin/2.3`.
- Antes de usar simulador, comprueba si el iPhone 14 conectado a la Mini vía DeviceMCP está libre (no lo des por ocupado sin comprobarlo). Si corres en la Max y necesitas simulador, tienes permiso explícito para usar un segundo simulador (tope 2 en la Max; en la Mini tope 1).
- En la Mini, respeta el pipeline serial y limpia DerivedData propio y cachés de XcodeBuildMCP de worktrees ya retirados sin preguntar.
- Guarda capturas de antes y después en `capturas/` del worktree (pasos claros y demostrando volver a un paso anterior).
- Abre un PR sin firma de IA contra `2.3` con auto-merge activado y espera a que el PR entre de verdad en `2.3` antes de `/cerrar-total` (si tras ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo).

## Paso 0 — decisiones (resueltas en autónomo, nocturno)

1. **Volver a un paso = rebobinar.** Tocar un paso hecho lo deja activo otra vez y los de después vuelven a pendientes
   (`StepGuideProgress.reopen`). Así se mantiene el invariante «los hechos son siempre los primeros» y el «Paso N de M»
   no miente. Alternativa descartada: «mirar» un paso sin deshacer los siguientes (dos estados y otro foco).
2. **Cómo se ve:** cada paso hecho lleva un enlace «Volver a este paso» bajo su título, y la fila entera se toca. No se
   añade un botón «Paso anterior» aparte: con el enlace en cada paso hecho sobraba.
3. **Vale para las tres guías** (Apple Pay, Face ID, correos): está en `YalaStepGuide`.
4. **Copiar la dirección siempre a mano:** botón «Copiar dirección» en la cabecera de la guía, debajo de la dirección
   (`StepGuideHeader.accessory`, opcional; las otras guías no lo usan).
5. **Mismos pasos** (Gmail 5, Outlook e iCloud 3): se reescriben los textos con subpasos numerados, la ruta en Safari,
   cómo encontrar la dirección del banco y qué NO marcar. No se añaden pasos: cambiarían el progreso guardado.
6. **Textos en `CorreosBancoGuia.strings`** (16 idiomas), incluidos los dos de «Volver a este paso». Las claves viejas
   `bankEmail.*` de `Localizable.strings` quedan sin uso y no se tocan (ese fichero está fuera del encargo).
7. **es-ES:** mismo texto neutro, con los nombres de botón de Gmail/iCloud en España («Añadir…»); es-AR en voseo, como
   las demás tablas.
