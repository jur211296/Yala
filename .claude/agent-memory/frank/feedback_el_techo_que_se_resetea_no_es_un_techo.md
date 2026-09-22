---
name: el-techo-que-se-resetea-no-es-un-techo
description: Antes de implementar un tope, enumera quién lo resetea y a quién muerde — si un camino legítimo de UI lo reinicia no acota a nadie, y si el que sí muerde es el usuario legítimo, se retira en vez de apuntalarse
metadata:
  type: feedback
---

Un tope se juzga por **dos** preguntas, y las dos se miden antes de escribirlo: **¿quién lo
resetea?** y **¿a quién le muerde de verdad?** Si la primera tiene una respuesta barata desde la UI,
no acota a nadie; si la segunda es el usuario legítimo, hace daño. Con las dos en contra, **se
retira: no se apuntala**.

**Why:** el 2026-09-21, en `leaving-and-reentering-restore-renews-the-hard-cap`, implementé un techo
para la cadena de re-anclas de la ventana de sesión del restore (600 s, con una cifra publicada de
1200). La review lo tumbó midiendo sus dos mitades, y las dos eran fatales:

1. **No acotaba.** El verbo que limpiaba la cadena (`noteRestoreFinished`) es alcanzable desde la UI
   con el trabajo todavía en curso: «Empezar desde cero» → confirmar → en la puerta de descarte,
   «Volver» → volver a entrar. **Tres toques, y la puerta no había borrado nada.** Por debajo había
   un baseline que ningún techo toca: el estado vive en memoria a propósito, así que **relanzar la
   app estrena todo**.
2. **Y sí bloqueaba al dueño legítimo, de forma permanente.** Agotado el techo, quien volvía con su
   descarga viva no podía re-anclar (techo) ni estrenar (el reloj seguía puesto): heredaba un reloj
   caducado y se llevaba el bloqueo sobre su propia cuenta **para el resto del proceso**.

**How to apply:**

- **Enumera los reseteadores antes de escribir el tope.** `grep` de quién pone a `nil` el estado del
  que cuelga, y para cada uno: ¿lo dispara la UI?, ¿con cuántos toques?, ¿pasa por una pantalla que
  desincentive?
- **Busca el baseline irreductible.** Si relanzar la app, cerrar sesión o reinstalar ya estrenan
  todo, ningún tope interno puede prometer un número frente a alguien decidido. Eso no invalida el
  trabajo: cambia lo que el criterio puede pedir —«que deje de ser gratis» en vez de «que sea
  imposible»— y hay que escribirlo así.
- **Recorre el tope agotado con el usuario legítimo delante**, no solo con el adversario. La
  pregunta es «cuando el tope muerde, ¿quién está al otro lado?» y «¿se recupera solo, o se queda
  así el resto del proceso?».
- **Si las dos salen mal, el resultado del ticket es un ticket**: lo medido va entero a uno nuevo con
  los caminos posibles sin decidir, y el que se entrega dice qué criterios cierra y cuáles no. Es
  mejor entrega que un mecanismo que da sensación de techo.
- **Ojo con el test que lo "prueba".** El mío recorría un ciclo que nunca pasaba por el verbo que
  reseteaba el tope, así que medía *un* ciclo y no *el* ciclo del ticket. Un tope se testea por su
  camino de reset, no solo por su camino de agotamiento.

Relacionado: [[antes-de-poner-techo-mide-que-la-espera-existe]], [[prefiere-lo-limpio-a-lo-defensivo]],
[[una-frase-de-alcance-se-cuenta-por-llamadores]], [[mi-arreglo-cumple-una-premisa-que-era-falsa]].
