---
name: el-mutante-que-sobrevive-puede-sobrar
description: Un mutante vivo tiene DOS respuestas —falta un test, o sobra el código— y elegir la primera por defecto añade red a una línea que no hace nada
metadata:
  type: feedback
---

Cuando un mutante sobrevive, la pregunta no es «¿qué test me falta?» sino **«¿cambia el
comportamiento observable?»**. Si no lo cambia, el mutante es equivalente y **lo que sobra es el
código**: añadirle un test es fijar una línea inerte.

**Why:** el 2026-09-17, en `reverse-before-mount-stays-stuck-with-an-expired-session`, dos mutantes de
la primera tanda salieron verdes y **cada uno pedía una respuesta distinta**:

- **Uno era test que falta.** El drain que colapsa `.sessionExpired` en `.transient` sobrevivía porque
  todos mis casos usaban el FAKE del runner y **no había ni un test del executor real** para
  `reverseDrainOnce`. Lo escribí, con su control en la dirección contraria (un 5xx y un 403 siguen
  siendo red), y el mutante cayó.
- **El otro era código que sobra.** Tenía un `noteReverseSessionExpiry(nil)` en el outcome «claim
  aceptado», y quitarlo no cambiaba nada: desde ahí **toda continuación pasa por otro escritor**, así
  que ningún test podía cazarlo — es el vecino cumpliendo el tramo. La respuesta correcta no fue
  añadir una aserción: fue **quitar las doce líneas repartidas** y dejar un borrador único al entrar
  en `drive()`. El diseño salió más simple *por* el mutante que sobrevivió.

**How to apply:** ante un mutante vivo, escribe la frase «con este cambio, la persona ve ___». Si la
respuesta es «lo mismo», no escribas el test: borra la línea y vuelve a correr la tanda. Si el mutante
está en un fichero que tus tests solo tocan a través de un fake, el hueco es de cobertura y el test va
en el nivel real, no en el fake.

Corolario del mismo día: al centralizar el borrado, el anti-repetición manual del canario se quedó sin
poder funcionar (comparaba contra un valor que el propio `drive()` acababa de borrar). La salida no
fue un segundo testigo —que tampoco podría cazar ningún test— sino `MetricsService.canaryOnce`, que ya
dedupea por proceso. **Cuando una defensa necesita un testigo que ningún test puede ver, busca si el
repo ya tiene el mecanismo.**

Ver también [[feedback_el_tramo_sin_acotar_lo_cumple_el_vecino]] y [[feedback_la_asercion_que_no_puede_fallar]].
