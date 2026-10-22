---
name: el-guion-se-adapta-al-estado-del-telefono
description: En el QA guiado, cada paso de la tanda se re-deriva del estado real del iPhone tras las pruebas anteriores antes de dárselo a Jürgen; nunca se copia el guion tal cual.
metadata:
  type: feedback
---

Antes de dar cada paso del QA guiado, lo adapto a lo que las pruebas anteriores dejaron en el teléfono y en
staging. No le paso el guion de la tanda tal cual.

**Why:** el 19-oct (QA guiado 2.1, TF17) di los pasos de la tanda literales y Jürgen vio pantallas que el guion no
anunciaba: el faro de iCloud de vb1f desvió «Es mi primera vez» a «Entra a tu cuenta», «¿Cómo te llamas?» no tenía
salida atrás, un «iCloud ya disponible: reabre» de una instalación limpia, un consentimiento repetido ya conocido.
Dijo: «me hace parecer que están pasando cosas que no deberían». Cada sorpresa le cuesta confianza y tiempo, y lo hace
dudar de si es bug.

**How to apply:** antes de cada prueba, repasa qué dejaron las anteriores (faro/KV de iCloud, Keychain, sesión,
cuentas de staging, datos en iCloud) y mide lo que puedas (prefs, store, staging). Reescribe el paso con lo que va a
ver de verdad, anticipa las pantallas intermedias esperables y dile cuáles son normales. Comprueba en el código que
cada botón que nombras existe en esa pantalla. Relacionado: [[el-guion-de-qa-tiene-que-distinguir-builds]].
