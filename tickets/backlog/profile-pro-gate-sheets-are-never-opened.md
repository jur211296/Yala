---
id: profile-pro-gate-sheets-are-never-opened
status: backlog
priority: very-low
area: profile
created: 2026-11-07
updated: 2026-11-07
source: hallazgo de «Mejoras necesarias 2.3 · Formulario: monedas claras y salida manual disponible»
---
# Perfil cuelga tres muros de Pro que nada abre

`ProfileView` declara `showUpgradeForVoice`, `showUpgradeForImage` y `showUpgradeForInsights` (líneas 58-60 en `origin/2.3`
del 2026-11-07) y cuelga una `.sheet` de cada uno (líneas 1504-1512), pero ningún código los pone a `true`: medido con
`grep`, las únicas apariciones son la declaración y la hoja.

Por qué importa poco: no se ve nada roto. Por qué se apunta: el encargo de V3 («Apuntarlo a mano» en el muro de voz y
foto) recorrió todos los muros de voz y foto, y estos dos no se cablearon porque no se pueden abrir. Si algún día se
reactivan, tienen que pasar la salida manual (`proUpgradeSheet(…, onManualEntry:)`), o el muro volverá a prometer «Apuntar a
mano sigue gratis» sin botón; lo fija `ProGateManualEntryWiringTests`, que hoy no los mira.

Qué hacer: borrar los tres estados y sus hojas, o cablearlos con `proUpgradeSheet` si hay un sitio de Perfil que deba
abrirlos.
