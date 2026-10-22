---
name: disena-en-lienzo-antes-de-construir
description: Cuando Jürgen no tiene diseño pensado, quiere 3-4 propuestas visuales en un lienzo y elegir con AskUserQuestion; el alcance crece por mensajes a media vuelta — parar código, rediseñar, partir en entregas
metadata:
  type: feedback
---

**Un encargo de UI con una cita vaga («más espacio, clic abre sheet…») acaba siendo una sesión de diseño: se le
enseñan 3-4 propuestas en un lienzo (Artifact tipo Design, artboards de iPhone) y elige con AskUserQuestion.** No se
construye la interpretación propia de la cita esperando acertar.

**Why:** el 2026-10-03 (`panel-accounts-redesign`) contesté el Paso 0 con preguntas cerradas, él eligió y empecé a
construir; a media vuelta escribió «no tengo un diseño específico pensado… quiero que me diseñes tres o cuatro
propuestas». Tras verlas fue afinando por mensajes sueltos (color entre dos variantes, «las píldoras pueden ser
infinitas», filtrar por varias cuentas, favoritos/colecciones, «no estoy 100 % convencido de nada de cuentas») hasta
ampliar a todo el área. Aprobó con «me agrada» y «Aprobado, dale». Valoró: maquetas con los MISMOS datos de ejemplo
en todas para compararlas, y que le dijera qué era decisión suya (archivadas en el total) frente a lo técnico.

**How to apply:**
- Si la cita no dice cómo se ve, propuestas en lienzo ANTES de código. Mismos datos en todas las variantes.
- Cuando el alcance crece, **parar el código** (dejarlo sin commitear), rediseñar el área entera, y partir en
  entregas con ticket cada una; la primera va en el PR de la sesión.
- Sus «estoy entre A2 y A3» admiten una síntesis con sentido (A2 normal, A3 al filtrar): decidirla, decirla en una
  línea y seguir, sin otra pregunta.
- Lo que una maqueta afirma (copy) se mide antes de ponerlo: «no suman al total» resultó falso para archivadas.
- Ver también [[sesion-de-rediseno]].
