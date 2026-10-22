---
id: import-completed-alert-is-sometimes-lost
status: qa
priority: low
area: import
created: 2026-10-19
updated: 2026-10-22
source: QA guiado 2026-10-19 (A · C1), card «Al terminar de importar un archivo no sale «Importación completada»»
---

# Al terminar de importar un archivo no siempre sale «Importación completada»

## Qué pasaba

Tras importar en un iPhone real, la hoja se cerraba y a veces no salía ningún aviso (el 20-oct sí salió). Perfil pedía
el aviso 200 ms después de cerrar la hoja (`try? await Task.sleep`): si la animación de cierre duraba más, SwiftUI
descartaba el `.alert`. Sin aviso no se sabe si funcionó, cuántos entraron, ni si falló.

## Hecho (2026-10-22)

El resultado se guarda y el aviso se pide en el `onDismiss` de la hoja, cuando ya se fue (`importResultAwaitingDismiss`
en `ProfileView`). Sin retardo fijo y sin el `try?`. Test de cableado: `ImportAccountChoiceAndResultTests`.

## Device-QA (iPhone de QA, build con este cambio)

1. Perfil › «Importar archivo» › elige `movimientos-qa-1500.csv` › elige una cuenta › «Importar».
2. La hoja se cierra y sale «Importación completada» con la cifra. Repítelo dos veces más (borra los importados entre
   medias o usa otro archivo): tiene que salir las tres.
3. Comprueba que la lista de cuentas del importador ya no ofrece «Grupos PEN».
