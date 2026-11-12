---
esfuerzo: high
---
# Separar «Vaciar datos» (borra el contenido, mantiene cuenta y sesión, queda en el Panel vacío) de «Eliminar cuenta» (borra todo, cierra sesión y lleva al Welcome), en nube e iCloud privado

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `vaciar-datos-mantiene-cuenta` · Sesión cola **S27i** · al cerrar → **S27j** (auditoría del import).
Card: `tablero ver tablero-vaciar-datos-mantiene-la-cuenta-y-no-lle-zvdt`.

## Contexto
Decisión de Jürgen (2026-10-29 08:27 Lima): «Vaciar datos» ya NO lleva al Welcome. Ahora que existe Cerrar sesión, son dos acciones distintas, cada una con su propia confirmación:
- **Vaciar datos**: borra todo el contenido (registros, cuentas, presupuestos, pagos planificados, etiquetas, categorías propias, borradores, etc.), **mantiene la cuenta y la sesión**, y deja al usuario en el **Panel vacío**, con un aviso corto para crear su primera cuenta.
- **Eliminar cuenta**: borra los datos y la cuenta, cierra la sesión y lleva al **Welcome**. Debe cumplir App Store Guideline 5.1.1(v) (ver `qa/cloud/README.md` ~l.925: borrado iniciado dentro de la app, sin pasos fuera, revocación del token de Sign in with Apple, confirmación clara).
Tiene que funcionar en **modo nube** y en **iCloud privado**.

Antecedentes que no hay que duplicar:
- **S12h / PR #659** (card `pet5`, done): re-claim del alta propia, «Crear categorías» con grupos, aviso de grupos al eliminar cuenta. Dejó la pregunta «Vaciar → Welcome».
- **Card `l9rw`** (done): el 28-oct Jürgen decidió «Vaciar → onboarding (Paso 9)». **Queda superada** por esta decisión: ni onboarding ni Welcome tras Vaciar.
- **PR #678 / S22** (card `rd7z`): hoja de **la cuenta financiera** eliminada (mover o borrar movimientos). Es otra cosa: no la toques salvo que choque.
- Lote 20 (PR #534) y lote decidido 04 (cuenta, cerrar sesión, solo grupos): fijaron las confirmaciones de Vaciar y Eliminar cuenta («Esto es definitivo»). Respeta su copy y sus seams.
- Reglas de vaciado y señal remota en `.claude/rules/swiftdata-cloudkit.md` («Vaciar datos», `DataWipeService`, `performLocalWipeForRemoteSync`). Tickets de backlog relacionados (no se arreglan aquí salvo que el cambio los toque): `restore-beacon-outlives-account-deletion`, `account-deletion-canary-never-arrives`, `local-wipes-other-than-sign-out-do-not-look-at-an-in-flight-migration`.

## Qué se pide
1. Card a in progress con `--agente frank` al empezar.
2. Mapear hoy, sobre `origin/2.2`, qué hacen Vaciar y Eliminar cuenta en cada modo (nube / iCloud privado / solo grupos): qué borran, adónde navegan, qué pasa con la sesión, los grupos, la señal a otros dispositivos, widget/Siri/recordatorios.
3. **Vaciar datos**: borra todo el contenido en local y en su almacén (servidor en nube, zona CloudKit en iCloud privado, propagado a otros dispositivos con la señal existente); conserva sesión, cuenta, ajustes de cuenta y grupos según la regla actual; termina en el **Panel vacío** (no onboarding, no Welcome) con un aviso corto y localizado (16 idiomas) para crear la primera cuenta. Que el Panel no quede roto ni pida «Reabre Yala».
4. **Eliminar cuenta**: borra datos y cuenta (servidor + local), revoca Sign in with Apple / Google como hoy, cierra la sesión y lleva al **Welcome** limpio, sin migración fantasma ni «hay datos en otra cuenta». En iCloud privado sin cuenta de Yala, decide con el mapa del punto 2 si la fila aplica; si hay duda de producto, AskUserQuestion de día.
5. Cada acción con **su propia confirmación**; ninguna reutiliza el texto de la otra.
6. **Tests**: unitarios de la lógica de destino y de lo que se borra/conserva por modo, y **un XCUITest de cada camino** (Vaciar → Panel vacío con sesión; Eliminar cuenta → Welcome), con los seams existentes (`-uitest-fake-backend-session`, etc.). Actualiza `qa/coverage-index.json`.
7. **Review adversarial** del diff antes del PR (borrado de datos: buscar restos, borrados de más, señales a otros dispositivos, carreras con migración en curso). Lo que no quepa: ticket + card en backlog.
8. Un solo PR a 2.2 en auto-merge. Al cerrar, card a in qa (device-QA de Jürgen en nube e iCloud privado) o done.

## Qué NO tocar
- La hoja de la cuenta financiera eliminada de #678 y la lógica de crash/borrado de la Bandeja (S27h) más allá de lo que pida esto.
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala.

## Reglas de Mini
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; no toques las de un worktree vivo; haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

## Cómo se sabe que está bien
- Vaciar en nube y en iCloud privado: todo el contenido desaparece (también en otro dispositivo), la sesión y la cuenta siguen, y se queda en el Panel vacío con el aviso.
- Eliminar cuenta: cuenta borrada en servidor, sesión cerrada, Welcome limpio; cumple 5.1.1(v).
- Unit + XCUITest de los dos caminos en verde; review adversarial hecha; PR a 2.2.

/cerrar-total

## Paso 0

**Mapa medido sobre `origin/2.2` (1f7ee6d23).**

| Celda | Vaciar datos hoy | Eliminar cuenta hoy |
|---|---|---|
| C · iCloud privado sin cuenta de Yala | borra filas + preferencias, señal KV a los dispositivos del Apple ID, aterriza en el **onboarding** (`WipeLanding.personalOnboarding`) | la fila no existe (`shouldShow(hasSession:)`): no hay cuenta que borrar |
| D · iCloud privado + cuenta de Yala de grupos | igual que C, grupos intactos | borra la cuenta en servidor, revoca SIWA/Google, cierra la sesión de Yala; lo personal se queda (`closeLocalGroupsOnly`, decisión L20-10) y pide reabrir |
| E · nube | borra filas + preferencias (el motor sube los borrados a la cuenta, sin señal KV), **onboarding** | borra cuenta + datos en servidor, revoca, cierra sesión; cambio en caliente al **Welcome** (`attemptSignOutSwap`) o cover de reabrir si montó con espejo |
| F · solo grupos | perfil + preferencias; se queda en la shell de grupos | como E: Welcome |

El otro dispositivo (C/D): la señal `lastWipeTimestamp` lo vacía con corte por fecha y, como el origen no terminaba el onboarding, lo mandaba también al onboarding con sus preferencias reseteadas.

**Decisiones de Jürgen (2026-10-29, ~10:20 Lima, AskUserQuestion):**
1. Vaciar conserva **ajustes y recordatorios** (nombre, divisa, tema, idioma, avisos): el corte de «Empezar de cero» (`keepsPersonSettings`), con categorías de serie resembradas.
2. Eliminar cuenta en **D se queda en Yala** con lo personal (L20-10 sigue). C, E y F sin cambios de destino: C no tiene fila; E y F ya acaban en el Welcome.
3. Aviso tras Vaciar: «Listo, empezaste de cero. Crea tu primera cuenta para registrar.»

**Asumido (técnico):**
- Aterrizaje nuevo `WipeLanding.panel` para C/D/E; F conserva `groupsShell`.
- Los avisos del sistema se cancelan y se reprograman los recordatorios que quedan (`rescheduleSurvivingReminders`): con los avisos conservados, los de pagos y presupuestos borrados seguirían programados.
- Receptor (iCloud privado): el origen apunta `lastOnboardingTimestamp` (hora de la señal + 1 ms) ANTES que la señal y en el mismo `synchronize`, así el otro dispositivo entra por la rama «el parque ya siguió» (`skipOnboarding`): corte con `fleetStartedOver`, se queda en la app y, desde ahora, conserva también sus ajustes y recordatorios (si los borrara, el borrado de los recordatorios viajaría por el espejo al origen). Su aviso pasa de «Datos restaurados» a uno que dice que se vació desde otro dispositivo.
- Confirmaciones: ya son distintas (hoja «¿Vaciar tus datos?» + «¿Seguro? Esto es definitivo.» / hoja «¿Eliminar tu cuenta de Yala?» + «Esto es definitivo»); no se tocan (lote 20 y lote 04).
- XCUITest de Eliminar cuenta: hace falta un seam que complete el borrado sin red (`-uitest-fake-account-deletion`), en la celda F (la E no tiene seam de `storageMode == .cloud`).
