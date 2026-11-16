---
name: recorrido-con-artifact-y-veredicto
description: En un recorrido de QA, Jürgen revisa por escenario en un artifact con capturas numeradas y veredicto sí/no + nota; lo pide actualizado mientras se prueba
metadata:
  type: feedback
---

El 13-nov pidió «todos los escenarios, paso a paso en capturas o en un artifact». Funcionó así: un artifact con una tira de
capturas numeradas por escenario, «Ojo» en rosa donde hay algo que mirar y, al pie, «¿Es el flujo que esperas?» sí/no + nota
guardado en la db del artifact. Contestó por número de paso («7 - grave», «3 - corregir») y pidió que lo siguiera
actualizando mientras probaba para revisar en paralelo. También pidió card por hallazgo sobre la marcha.

**Why:** revisa desde el móvil y por número de captura; el veredicto en la db se lee sin pasar por el chat.

**How to apply:** en QA guiados o recorridos, publica el artifact tras cada escenario (no al final), numera los pasos,
y lee los veredictos con `ArtifactData list veredictos`; mapea su «N -» al paso N del escenario antes de tocar cards.
Sus notas a veces son preguntas («¿esto está bien, no?») o quedan cortadas: contéstalas o pregúntalas, no las conviertas
en card. Ver [[propuestas-como-artifact-visual]], [[capturas-en-el-chat-antes-de-preguntar]].
