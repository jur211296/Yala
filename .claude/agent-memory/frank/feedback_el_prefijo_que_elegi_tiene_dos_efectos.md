---
name: el-prefijo-que-elegi-tiene-dos-efectos
description: Elegir un prefijo de key por su exclusión de UN barrido la excluye de TODOS — incluida la purga entre corridas de XCUITest; y un seam de uitest que escribe esa key envenena el simulador para siempre
metadata:
  type: feedback
---

**Al elegir el prefijo de una clave de `UserDefaults` por lo que la EXCLUYE de un barrido, mide de
qué OTROS barridos la excluye a la vez.** Una exclusión es una propiedad global de la clave, no una
decisión local del caso que tenías en mente.

**Why:** el 2026-09-12, en `PrivateSessionMark` (el eje 1 del rediseño de sesiones), elegí el prefijo
`cloudSync.` **a propósito**, porque `DataWipeService.removeUserPreferenceKeys` lo excluye y yo
quería que la marca sobreviviera a «Vaciar datos» — vaciar no cambia quién eres. Correcto en esa
dirección, y en la otra dejó la clave **fuera del único barrido que la limpia entre corridas de
XCUITest**. El seam `-uitest-group-invite` la escribía en el dominio persistente, nada la borraba
jamás, y la corrida siguiente —más el arranque MANUAL de Yala Dev en ese simulador— arrancaba
creyendo que no hay sesión privada. El test que debía cazarlo,
`UITestSeamPersistenceIsolationTests`, lleva en el mensaje de una de sus cinco claves prohibidas la
frase exacta que describía mi caso («no la borra ni el reset de uitest ni el wipe, que excluye
`cloudSync.*` a propósito») — y pasó verde, porque su lista es de claves NOMBRADAS y la mía no estaba.

**How to apply:**

1. Al añadir una clave con un prefijo que algún barrido excluye, recorre **los tres** barridos del
   repo antes de dar el nombre por bueno: `removeUserPreferenceKeys` (el wipe y el sign-out),
   el bloque de `-uitest-reset` en `AppBootstrapper`, y `performSignOutWipeIfArmed`.
2. Si un **seam de `-uitest-*`** escribe esa clave, o va por `UITestEphemeralDefaults` (dominio
   volátil) o se repone en el bloque de reset, al lado de su gemela `onboardingMode`. No hay
   tercera opción: el molde está escrito en la cabecera de `UITestEphemeralDefaults`.
3. Añade la clave a la red que corresponda. Una lista de claves **nombradas** solo protege lo que
   está dentro: que el escáner exista no significa que te cubra.

**El corolario general, que es el que se repite:** una decisión de diseño tomada mirando un solo
consumidor suele tener un segundo efecto en el consumidor que no miraste. Aquí fueron dos en el
mismo PR — este prefijo, y el default de la lectura, que era conservador para ocho consumidores y
peligroso para el noveno ([[feedback_el_default_seguro_no_es_el_mismo_para_todos]]).

Relacionado: [[feedback_el_testigo_global_miente_en_el_host_de_test]] ·
[[feedback_review_adversarial_caza_lo_mio]]
