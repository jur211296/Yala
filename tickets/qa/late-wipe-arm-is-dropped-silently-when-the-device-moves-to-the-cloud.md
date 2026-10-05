---
id: late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud
status: qa
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-27
updated: 2026-10-04
qa-status: needs-testing
source: "review adversarial de `private-gate-back-from-found-keeps-a-resumed-arm` (2026-09-27, lente del arranque); leído en código, la ventana NO reproducida"
---

# Un borrado de iCloud pendiente se olvida sin avisar si el dispositivo pasa a la nube

## El síntoma, en lenguaje de usuario

Pido borrar mis datos viejos de iCloud desde el aviso «Encontramos datos tuyos». El borrado no llega a empezar (iCloud
sigue bajando datos) y la app lo reintentará en el próximo arranque. Antes de eso me paso a la nube desde Ajustes. Mis
datos viejos suben a mi cuenta de la nube, y el borrado que pedí desaparece sin que nadie me lo diga. iCloud sigue lleno.

## Lo medido (2026-09-27, leyendo código)

- `performICloudCorpusWipe` no borra mientras el import del espejo está en vuelo, y lo devuelve como fallo `.untouched`.
  El arranque deja el arm puesto para reintentar (`ContentView.runLateICloudMirrorCheck`).
- Ni la migración a la nube (`MigrationWorkExecutor`) ni el adopt miran el arm.
- Desde `private-gate-back-from-found-keeps-a-resumed-arm`, un arranque en `.cloud` retira el arm sin borrar ni preguntar
  (`lateWipeLaunch` → `.retireInCloud`). Antes lo reanudaba con `.handover` sobre los datos de la cuenta de la nube, que era
  peor: esto es el residual, no una regresión.

## Qué hay que decidir

1. ¿La migración a la nube se bloquea o avisa con un borrado de iCloud pendiente?
2. ¿O el arranque en la nube avisa («Tenías un borrado de iCloud pendiente») en vez de retirarlo en silencio?

## Decidido (Jürgen, 2026-10-04)

Opción A, literal: «Avisar o bloquear en la migración. No tragarse el borrado de iCloud pendiente en silencio al pasar a
la nube». Dentro de A, de noche, se eligió **avisar con elección** y no un bloqueo duro: el borrado puede quedarse
atascado días (el espejo importando, iCloud sin red) y bloquear le quitaría la nube a la persona sin salida.

## Lo que cambia para el usuario

1. **En Ajustes → ¿Dónde viven tus datos?**, si pidió «Empezar de cero» y el borrado no terminó (armado o a medias),
   tocar «Activar la nube» o «Activar en este dispositivo» abre antes que nada un diálogo: «Tienes un borrado sin
   terminar», con «Activar la nube sin borrar» y «Ahora no». «Ahora no» deja todo como estaba.
2. **«Activar la nube sin borrar» no borra ni retira nada todavía**: apunta que la persona renuncia al borrado *si* el
   iPhone llega a la nube. Si la migración vuelve a iCloud (canceló Apple/Google, la cuenta no vale, «Cancelar la
   activación»…), el borrado sigue pendiente y la próxima vez se vuelve a preguntar.
3. **Mientras la migración está en vuelo**, el arranque en iCloud no reanuda el borrado ni pregunta por él: borrar en
   mitad de la subida se llevaría lo que se está subiendo.
4. **Al arrancar en la nube**, el borrado se retira (terminarlo se llevaría los datos de la cuenta). Si la persona ya lo
   eligió en Ajustes, en silencio; si llegó por otra puerta (el Welcome, la activación de Yala completo, una carrera),
   se le cuenta una vez: «Un borrado no llegó a terminar», con un solo botón. La marca del aviso se apunta antes de
   retirar y la hoja la consume al montar, así que un kill entre medias no lo pierde.

Copy en los 16 locales (`storage.pendingICloudWipe.*`, `welcome.privateICloud.cancelledInCloud*`).

**Corregido en la review adversarial (tres lentes, 2026-10-04):** la primera versión retiraba el borrado al arrancar la
migración y lo perdía en silencio en cada salida previa al cutover; «Esperar» con rol de cancelar no se pintaba en el
diálogo anclado de iOS 26; la activación de Yala completo a la nube seguía retirándolo sin contarlo; y el copy prometía
un reintento que «a medias» no hace.

## Criterios de aceptación

- [x] Quien pidió borrar su iCloud privado y pasa a la nube se entera de que ese borrado no se hizo. (Código y tests;
  falta verlo en un iPhone real, guion abajo.)

## Device-QA (iPhone real, build `Yala Dev` desde Xcode)

Hace falta un iPhone porque el atasco del borrado sale del espejo de CloudKit, que el simulador no tiene. El diálogo de
Ajustes ya está cubierto en simulador (`PendingICloudWipeMigrationUITests`); esto mira el estado real.

**Montaje**
1. iPhone con sesión de iCloud y datos viejos de Yala Dev en iCloud.
2. Instala `Yala Dev` desde Xcode en el iPhone (scheme `Yala Dev`, el que tiene la nube encendida).
3. Elige privado con iCloud apagado en el Welcome, haz el onboarding y crea un gasto. Luego enciende iCloud para Yala y
   vuelve a abrir la app: sale «Encontramos datos tuyos».

**A · la puerta de Ajustes**
1. En «Encontramos datos tuyos» toca borrar, confirma y, mientras dice «Borrando…», mata la app desde el selector.
2. Pon el modo avión y vuelve a abrir Yala (la reanudación falla sin tocar nada y el borrado queda pendiente).
3. Quita el modo avión. Ve a Perfil → ¿Dónde viven tus datos? → «Activar la nube».
4. **Esperado**: sale «Tienes un borrado sin terminar» antes del consentimiento. Toca «Ahora no»: no se abre nada más.
5. Vuelve a tocar «Activar la nube» → «Activar la nube sin borrar» → en la hoja de Apple/Google, **cancela**.
6. Cierra y vuelve a abrir Yala. **Esperado**: el borrado sigue pendiente (vuelve a intentarlo o a preguntar, como
   antes), y «Activar la nube» vuelve a enseñar el diálogo.
7. Repite «Activar la nube sin borrar», completa la migración y relanza cuando lo pida.
8. **Esperado**: en el arranque en la nube NO sale «Un borrado no llegó a terminar» (ya lo elegiste).

**B · la red del arranque** — sin montaje manual fiable. Llegar a la nube con un borrado pendiente por otra puerta
(el Welcome, la activación de Yala completo) no se provoca a mano sin herramientas de depuración, así que lo cubren los
tests de lógica y cableado (`PendingICloudWipeCloudTests`). Si alguna vez lo ves: sale una sola vez «Un borrado no llegó a terminar», con «Entendido» y sin botón de borrar, y al relanzar ya no sale.

Si el paso A.2 no deja el borrado pendiente (la reanudación termina igual), apúntalo en el ticket: es el atasco que el
ticket describe y no se pudo provocar a mano.

## Relacionados

- [[private-gate-back-from-found-keeps-a-resumed-arm]]
- [[late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed]]
