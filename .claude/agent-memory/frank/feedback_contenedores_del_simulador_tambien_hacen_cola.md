---
name: contenedores-del-simulador-tambien-hacen-cola
description: Borrar o escribir ficheros en los contenedores del simulador (Preferences, tmp, App Group) también espera turno con sim-lock, no solo el xcodebuild
metadata:
  type: feedback
---

No toques el simulador NI SUS CONTENEDORES mientras otra sesión lo esté usando: espera tu turno.

**Why:** el 2026-11-04 hice una limpieza única (borrar `.plist` y directorios de `tmp/` con UUID en los contenedores de
Yala y Yala Dev) con `sim-lock.sh --estado` diciendo TOMADO por la sesión de la bienvenida, que corría XCUITest de
Yala Dev. Jürgen tuvo que avisarle de que un rojo raro de esa hora podía ser mío. Lo leí como «son solo ficheros, no
es un xcodebuild», y el lock protege el simulador entero, no el proceso.

**How to apply:** cualquier `rm`/`plistlib`/limpieza dentro de `CoreSimulator/Devices/<udid>/data` va envuelto en
`bash qa/scripts/sim-lock.sh -- bash <script>`, igual que un test. Leer (medir) sin escribir sí vale fuera de turno.
Relacionado: [[el-carril-espera-a-cola-a]], [[simulador-ajeno-parado-se-pregunta]].
