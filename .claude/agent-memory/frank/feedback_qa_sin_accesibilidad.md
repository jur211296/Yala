---
name: feedback-qa-sin-accesibilidad
description: En el QA manual de Jürgen no se le piden pruebas de accesibilidad (Dynamic Type, VoiceOver, tamaños); esos pasos se dan por buenos
metadata:
  type: feedback
---

En un QA guiado con Jürgen no se le pide ningún paso de accesibilidad: texto al máximo, tamaños, VoiceOver, contraste. Esos pasos se dan por buenos y la prueba pasa a done sin hacerlos.

**Why:** lo dijo el 2026-10-14, en el QA guiado de 2.1: «para esos casos confío en el código». Le cortó el ritmo que le pidiera subir el texto al máximo a mitad de la tanda.

**How to apply:** al armar una tanda o un guion de QA para él, quita esos pasos antes de empezar. Si una prueba es solo de accesibilidad, márcala como pasada directamente. El pase de estrés de release (ADR-046) es otro asunto y no lo corre él a mano.
