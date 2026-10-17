# Volver a iCloud con una cuenta nacida en la nube mezcla datos viejos que había en ese iCloud (card 4nt6)

## Card
`tablero-volver-a-icloud-con-una-cuenta-nacida-en-4nt6` (high, versión 2.1, asignada a frank). Léela entera con `tablero ver tablero-volver-a-icloud-con-una-cuenta-nacida-en-4nt6`.

## Contexto (copiado de la card)
QA guiado del 15-oct, C3 + A2 en el iPhone de QA. Cuenta nacida en la nube con Google A; «Volver a iCloud» terminó bien con 25 movimientos. Tras vaciar y re-importar la copia local (A2), el store tiene 34: los 25 + 9 gastos de grupo del 18-jul en la cuenta «Grupos PEN», creados en este teléfono el 14-oct 22:12 por la adopción de OTRA cuenta de Yala (la Apple de Jürgen en staging). Vivían en la zona de CloudKit de este Apple ID y el espejo los bajó. Medido copiando YalaModel-Dev.store del iPhone. QA 1 y QA 2 NO resucitaron. La premisa del código (CloudSyncFlags, doc de bornCloud: «a un born-cloud no le aplica: nunca tuvo zona») vale para la cuenta, no para el iCloud del teléfono. El aviso dice «No perderás nada» y no avisa de que se sumará lo que ya hubiera.

Nota de Jürgen 12:10: los ve en la Bandeja como gastos de grupo, y en Grupos la app lo manda al onboarding (la cuenta de Google es nueva). O sea: llegan filas de grupo huérfanas, sin grupo que las explique.

## Decisión de Jürgen (2026-10-15): opción A
Si el iCloud del teléfono ya tiene datos de Yala, avisar ANTES de la vuelta y dejar elegir (sumarlos o empezar sin ellos); el aviso deja de decir solo «No perderás nada».

Hecha cuando: Volver a iCloud sobre un iCloud con datos previos no los suma sin que la persona lo sepa; test + QA (simulador al máximo; device-QA solo si sí o sí hace falta).

Tickets relacionados para leer (no mezclar arreglos salvo que sea el mismo productor): tickets/backlog/born-cloud-sign-up-over-mirror-imported-rows-skips-the-corpus-check.md, reverse-exit-leaves-a-partial-copy-in-icloud.md. Atención también a las filas de grupo huérfanas (gastos de grupo sin grupo): si «sumarlos» trae filas de grupo de otra cuenta, decide y documenta qué se hace con ellas.

## Rama y PR
- Base `origin/2.1`. Antes de abrir el PR: `git fetch origin && git rebase origin/2.1`. No esperes el CI del PR anterior (#515, i1o5, puede estar en cola); solo rebase.
- PR a 2.1 con auto-merge cuando esté verde.

## Pipeline serial de simulador (regla de la Mini: 1 simulador a la vez)
1. Al empezar: limpiar simuladores muertos/sobrantes (`xcrun simctl delete unavailable`, apagar los que no sean tuyos si no hay otra sesión usándolos: mira `tmux ls`).
2. Compilar con `xcodebuild -jobs 2` SIN ningún simulador iniciado.
3. Iniciar 1 solo simulador, probar (tests + capturas).
4. Al terminar: apagar y borrar el simulador que creaste, y limpiar el DerivedData (.ddp) de ESTE worktree.

## QA
Pruébalo sola al máximo con simulador, tests unitarios/UI y capturas antes/después, siguiendo el criterio de /barrido-qa. Solo lo que sí o sí pide un iPhone real (CloudKit real con un Apple ID con datos previos) queda para Jürgen con un guion corto (≤10 pasos): en ese caso la card pasa a «in qa» asignada a jurgen con el guion en la nota. Si no hace falta iPhone, la card pasa a «done» con evidencia (PR, tests, capturas).

## Tickets y cards
Todo ticket nuevo que crees debe tener su card en el tablero (1:1, o una card existente que lo cubra y con cuyo cierre se cierre el ticket). Crea con `tablero crear --proyecto yala ... --version 2.1 --asignado frank --cierre cierra-sola`. Si el arreglo no tiene ticket propio, puedes crearlo y enlazarlo a esta card.

## Cierre
CIERRA SOLA: al terminar, /cerrar-total sin esperar a Jürgen (no requiere validación urgente). No le escribas a nadie.

## Qué NO tocar
- No mezclar con el lote 17 ni con otros tickets de la reversa salvo mismo productor.
- No tocar nada de salud, clinicas-dentales-bi ni sus sesiones tmux.

## Paso 0

Medido antes de decidir:

- La vuelta a iCloud monta el espejo sobre la zona de CloudKit del Apple ID (`reverseFreezeBackend → reverseMountMirror`, `.mountMirrorAndRelaunch`) y no mira antes qué hay en ella.
- La sonda que ya existe (`ICloudPersonalCorpusProbe.probe`) **no sirve tal cual**: excluye los movimientos puenteados de grupos, que son justo las 9 filas del QA. Y no distingue lo ajeno de lo que el espejo de ESTE store ya conoce (una vuelta anterior a medias deja la copia propia en iCloud: ticket `reverse-exit-leaves-a-partial-copy-in-icloud`).
- Los borradores `.groupExpense` no se pueden rechazar ni borrar desde la Bandeja (`blocksInboxDismissal`), y el barredor de huérfanas solo mira zonas del canal backend: las filas de grupo ajenas que se suman se quedan para siempre.

Decisiones (autónomo, asumidas):

1. **Quién pasa por el aviso:** solo la vuelta de un dispositivo nacido en la nube (`isBornCloud`). En una cuenta migrada la zona es su propio corpus y la vuelta está construida sobre él (el mapa de coordenadas, la reconciliación). El caso de registros ajenos en la zona de una cuenta migrada queda anotado como hallazgo.
2. **Qué cuenta como «datos previos»:** los registros de la zona del espejo de los tipos del canal personal (menos tipos de cambio) cuyo `recordName` NO está en los metadatos del espejo del store local (`ANSCKRECORDMETADATA`). Lo que el espejo local ya conoce no se suma: se reconcilia como la misma fila.
3. **Sin respuesta no se sigue:** si no se puede preguntar a iCloud (red, CloudKit, plazo, store ilegible) la vuelta no empieza y sale «No pudimos revisar tu iCloud» con «Reintentar». **Sin cuenta de iCloud tampoco** (cambiado tras la review): la vuelta se quedaría esperando a que la persona abra iCloud y el espejo sumaría entonces sin preguntar; sale «Abre iCloud en este iPhone».
4. **El aviso** es un diálogo colgado de la raíz de la pantalla, molde de los que ya hay: cifras (movimientos, cuentas, presupuestos, movimientos de grupos), «Sumarlos a mis datos» → el «¿Seguro?» de siempre, y «Empezar sin ellos» → confirmación destructiva.
5. **«Empezar sin ellos» borra de iCloud solo los registros ajenos**, uno a uno y por páginas, no la zona: borrar la zona con metadatos locales del espejo podría hacer que el espejo purgue el store local al remontar. Se borra al confirmar, tras comprobar que la vuelta puede empezar, y ANTES de empezarla; si el borrado falla, la vuelta no empieza.
6. **Filas de grupo ajenas al sumar:** se suman tal cual. No se borran de iCloud porque pueden ser las de otro dispositivo con ese Apple ID que sí tiene esos grupos, y borrarlas se las quitaría a él (incluidas transacciones reales aprobadas). El aviso las cuenta aparte y dice que llegan sin su grupo. Que luego no se puedan quitar de la Bandeja va a un ticket propio con card.
7. **QA:** sin CloudKit en el simulador, el aviso se prueba con seams de XCUITest que fingen la ENTRADA (modo nube nacido aquí y la respuesta de la sonda), unit tests de la lógica pura y del lector de metadatos, y capturas antes/después. El borrado real contra CloudKit queda para device-QA de Jürgen.
