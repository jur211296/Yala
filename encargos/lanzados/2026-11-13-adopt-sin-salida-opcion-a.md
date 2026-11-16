Yala
# Adopt sin salida: «Empezar de cero» deja el teléfono como recién instalado y el adopt no arranca sobre la nube
---
card: tablero-espera-decision-adopt-sin-salida-en-un-t-c99u
toca: Yala/, YalaTests/, tickets/
esfuerzo: medium
cierre: cierra-sola
---

Continuación enlazada al checkpoint nocturno del lote de fallos altos. Jürgen eligió la opción A el 13-nov a las 06:11, en el comentario de la card.

Punto de partida: la rama `encargo/2026-11-12-fallos-altos-exito-grupos-adopt` (PR en borrador https://github.com/jur211296/Yala/pull/948). El checkpoint está en `~/Claude/flota/checkpoints/01M79JQ8KQJVDRMN0T62KV2V4W/` en la Mini (manifiesto.json, contexto.md, transcript.jsonl): léelo primero. Los fallos 1 (hoja de éxito vacía) y 2 (patas de grupo) ya están resueltos y verificados en esa rama. No los rehagas.

Qué se pide:
1. Implementa la opción A del ticket `tickets/backlog/adopt-over-a-device-already-in-cloud-mode-has-no-exit.md`. «Empezar de cero» del Welcome deja el teléfono como recién instalado (el modo local queda escrito como corresponde y no sigue en .cloud), y el adopt nunca arranca sobre un teléfono que ya está en modo nube.
2. Agrega tests que caigan sin el arreglo. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.
3. Mueve el ticket a done, saca el PR de borrador, actualiza su descripción con los tres fallos y mergéalo contra 2.3 si CI pasa. Solo 2.3: la rama 2.2 está cerrada y no se toca.

Reglas: commits y PR sin firma de IA. Si otra sesión usa el simulador, puedes abrir un segundo simulador o usar el iPhone 14 por DeviceMCP. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`; si queda algo vital, sigue la regla del modo de la sesión.

## Paso 0 — decisiones (resueltas en semi, sin consultar: todas menores y dentro de la opción A)

Medido sobre la rama del PR borrador (`69ba1eada`).

1. **Por dónde vuelve el teléfono a recién instalado.** Por el borrado de «Cerrar sesión» (`armSignOutWipe` →
   `performSignOutWipeIfArmed`), no escribiendo `.icloud` en caliente: con el modo en iCloud sobre el archivo de la época
   nube, el espejo reproduciría su History hacia iCloud (hallazgo 3 de `qa/cloud`). Se consuma en caliente con el cambio
   de contenedor si el montaje lo admite y, si no, «reabre Yala». Molde: el cierre local tras borrar la cuenta en la nube.
2. **Dónde se engancha.** En las tres salidas del Welcome que, tras «Empezar de cero», abrían el onboarding privado:
   `startFreshPrivateOnboarding` (sin datos), el relanzamiento del espejo con destino `.privateOnboarding` y el alert de
   datos existentes. Después del borrado y la subida de grupos de siempre, que no se tocan.
3. **A dónde aterriza.** Al Welcome de un teléfono recién instalado, sin destino pendiente: es lo que hace «Cerrar sesión»
   y lo que dice la opción A. La persona vuelve a elegir.
4. **El store de Grupos no se marca para borrar**: el relevo ya purgó sus filas, y con los grupos que el aviso tardío
   conservó para esa misma persona sería el daño que esa decisión evitó.
5. **El cinturón.** En la entrada a una cuenta del Welcome, antes del guard cross-cuenta: modo `.cloud` sin el sello de
   esta cuenta ⇒ la pantalla de bloqueo existente (vuelve al elector), sin copy nuevo. Con el sello sigue como hoy (es su
   corpus). Canario `adoptOverCloudRefused`.
6. **Tests:** lógica pura + scan del cableado (molde `InboxSwipeSuccessSheetWiringTests`); la reproducción entera pide
   Google y backend, que el simulador no firma. Pruebas de interfaz: las del Welcome que tocan «Empezar de cero».
