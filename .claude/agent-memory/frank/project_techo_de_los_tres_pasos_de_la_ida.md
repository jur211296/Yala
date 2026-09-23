---
name: techo-de-los-tres-pasos-de-la-ida
description: PR del 2026-09-22 — claim (22 %), identidad (35 %) y cutover pendiente (80 %) con techo 15 min/72 h, «Cancelar» y texto por motivo; la review cazó el adopt en el claim y la marca que se saltaba «Empezar desde cero».
metadata:
  type: project
---

Ticket `forward-migration-steps-have-no-ceiling-and-no-exit`, a `qa` con guion de regresión (el 22 % no se puede aparcar
a mano y el 80 % solo con suerte). Jürgen contestó las cuatro preguntas del Paso 0 con la recomendada en un gesto,
incluida la de cerrar en el mismo PR la trampa del claim sin respuesta.

**Why:** los tres pasos cortaban sin evento; es el mismo bug-class que #212 cerró para la subida.

**How to apply:**

- **El claim del ADOPT sigue sin techo**, a propósito: salir ahí era un callejón. Espera en
  `adopt-claim-stays-parked-with-no-ceiling`; necesita otra salida (volver a un sitio desde el que entrar en la cuenta).
- **La identidad cuyo `save()` falla** deja el contexto compartido sucio y su salida no llega a disco: añadido a
  `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved`, que ya tenía la misma decisión pendiente (el alcance de un
  `rollback()` sobre el `mainContext`). No lo decidí por mi cuenta: puede tirar cambios sin guardar de la persona.
- El `xcodebuild` de los unit tests se cuelga minutos en el cierre tras un fallo también en el iPhone 17 Pro 26.5: el
  script de mutantes tiene que cortar el proceso al leer `Test run with`, o 22 mutantes son horas.

Relacionado: [[project_techo_de_la_subida_del_snapshot]], [[feedback_mi_salida_nueva_es_un_camino_muerto]],
[[feedback_fundir_una_entrada_nueva_hereda_sus_excepciones]].
