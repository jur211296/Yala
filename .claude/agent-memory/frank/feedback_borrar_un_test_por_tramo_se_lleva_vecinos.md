---
name: borrar-un-test-por-tramo-se-lleva-vecinos
description: Borrar un test caduco recortando un TRAMO entre dos anclas se lleva por delante a sus vecinos, y la suite sigue verde — el único que lo nota es el mutante que aquel test cazaba.
metadata:
  type: feedback
---

Cuando un rediseño deja un test sin sentido, lo quito recortando **desde un ancla hasta la siguiente**.
Ese tramo casi nunca contiene solo lo que quiero borrar.

**Why:** el 2026-09-17, al mover el consumo del arm fuera de `AppBootstrapper`, el test
`theBootstrapConsumesTheArmBeforeAnythingReadsTheSession` dejó de tener objeto. Lo borré cortando entre
dos comentarios `///`, y en ese tramo vivía también `theHandoverWriterArmsAfterTheDeletion` —el único que
fijaba que el arm del relevo va **después** de la transacción de borrado—. La suite siguió verde (44
casos, todos pasando) y el conteo no cantó porque el número bajó por el borrado deliberado.

Lo destapó **el mutante**: `M5_arma_antes_del_borrado` salió `exit=0` sin un solo cazador, en una tanda
donde todos los demás caían. Un mutante que ayer moría y hoy vive es el aviso de que se cayó su test.

**How to apply:**

- Al borrar un test, bórralo **por su nombre**, no por un tramo entre anclas. Si hay que recortar un
  rango, imprime primero lo que va dentro (`sed -n 'ini,finp'`) y léelo.
- **Cuenta los casos antes y después y cuadra la resta**: «quito 1 test» tiene que dar exactamente −1. Si
  da −2, falta uno.
- **Y la red que de verdad lo caza es la tabla de mutantes**, que por eso se conserva de una tanda a la
  siguiente en vez de escribirse de cero: un mutante que antes moría y ahora sobrevive no significa que el
  código haya cambiado, significa que su test ya no está.
- El reflejo al ver un `exit=0` aislado en una tanda: **primero busca el test por nombre**
  (`grep -c 'func <nombre>' YalaTests/`), antes de ponerte a razonar sobre la lógica.

Relacionado: [[el-termino-nuevo-desarma-el-test-viejo]] (el mismo daño por otra vía: el test sobrevive
pero deja de discriminar) y [[revertir-sin-commit-destruye]].
