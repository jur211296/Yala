---
name: una-key-nueva-esta-ausente-en-todo-el-parque
description: Una key que NACE con mi cambio está ausente en todos los teléfonos del parque, así que «no hay marca» significa «primera vez que corre este código», no «app recién instalada» — y confundirlos aplica el efecto a todo el mundo el día del update.
metadata:
  type: feedback
---

Cuando introduzco una marca de `UserDefaults` para distinguir un estado, **su ausencia no significa lo
que quiero que signifique**: significa «este código nunca ha corrido aquí». Y eso es cierto en **todos**
los dispositivos el día en que se publica.

**Why:** el 2026-09-17, en `previous-person-cloud-session-survives-fresh-start-and-reinstall`, escribí
`cloudSync.installSeen` para detectar «primer arranque tras instalar» —el caso del teléfono que cambió de
dueño— y armar el retiro de la sesión en la nube. La key nace con ese cambio. En cada iPhone que ya tenía
Yala está ausente ⇒ **la primera actualización habría armado el retiro para el parque entero y cerrado la
sesión de todos los usuarios de la nube.** El unit test pasaba, el build pasaba, el diseño era correcto
para la población que yo tenía en la cabeza; lo que estaba mal era el significado de la ausencia.

Lo cacé yo leyendo un ticket hermano que decía «la marca ya se habrá escrito en esos teléfonos cuando
alguien lea este ticket» — una frase sobre OTRO one-shot que me hizo mirar el mío.

**How to apply:**

- Al introducir una marca, escribe la frase **«en el parque de hoy esta key vale ___»**. Si la respuesta
  es «ausente», la ausencia no puede ser el disparador por sí sola: hace falta una segunda señal que
  distinga «instalación nueva» de «primera vez que corre esto».
- La segunda señal se elige por **durabilidad**, y se prefiere la que sobrevive a los barridos: aquí
  fueron el archivo del store personal (`SwiftDataConfiguration.personalStoreFileExists()`) y
  `reviewFirstLaunchDate`, que `DataWipeService.removeUserPreferenceKeys` no nombra porque `review*` es
  una exclusión deliberada. `hasCompletedOnboarding` es respaldo, no principal: el relevo lo borra.
- **Elige la dirección del fallo por el tamaño de la población, no por la del bug.** No disparar deja el
  bug vivo en unos pocos teléfonos; disparar de más alcanza a todo el mundo. Por eso las evidencias van
  en `||` y ante la duda no se arma. Escríbelo en el docblock: es la decisión, no el detalle.
- Y el caso se pinnea con un test cuyo nombre lo diga (`anUpdateOverALiveInstall_armsNothing_…`) más su
  mutante: quitar el guard tiene que ponerlo rojo.
- Corolario para el device-QA: **el paso que decide si se puede publicar es «actualizar encima sin
  borrar», no «reinstalar»**. La reinstalación es el caso que quieres arreglar; la actualización es el
  que puedes romper.

Relacionado: [[un-gate-derivado-de-una-ausencia-falla-abierto]] (la marca va POSITIVA) y
[[el-default-seguro-no-es-el-mismo-para-todos]].
