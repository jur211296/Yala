---
name: grupos-avisa-sin-attest
description: PR #176 — la pestaña Grupos ya dice sola que este teléfono no sincroniza. Cerrado en `done`, sin device-QA; deja el hermano personal sin hacer.
metadata:
  type: project
---

**La pestaña Grupos avisa mientras el veredicto de App Attest sea terminal** (PR #176, mergeado a `2.1` el
2026-09-15). Decisión de Jürgen del 15-sep, opción 1.

**Why:** cerraba el último silencio de la familia del attest. El #173 dio el veredicto terminal y el #175 la
salida honesta del cierre en la nube, pero quien solo editaba gastos no se enteraba nunca: el aviso llegaba
al intentar cerrar sesión, desasociar o salir del grupo.

**How to apply:**

- **Está en `done`, no en `qa`.** El aviso es visual y determinista, y sus cuatro casos XCUITest lo cubren en
  simulador: no hay nada que exija un dispositivo real. Si alguien pregunta por device-QA de esto, la
  respuesta es que no hace falta y por qué.
- **Lo que queda vivo son tres residuales escritos en el ticket**, no huecos olvidados: el cruce de las 24 h
  con la app abierta (espera al siguiente gesto), el veredicto sin el testigo del ciclo (se cura solo con el
  primer 200) y «usa otro teléfono» cuando la caída es de Apple.
- **El hermano personal sigue sin hacer:** `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`. La
  nube personal solo emite su canario, sin nada visible. Tiene el molde entero aquí.
- **La review adversarial cazó tres cosas mías y una era el bug del ticket vivo** — está en
  [[dos-getters-que-parecen-sinonimos]]. Si vuelve a tocarse esta zona, esa es la lectura previa.

Relacionado: [[el-seam-que-usa-el-camino-de-produccion]] · [[el-consumidor-lee-una-copia]] ·
[[el-telefono-sin-attest-veredicto-y-salida]].
