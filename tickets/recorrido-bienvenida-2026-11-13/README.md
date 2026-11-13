# Recorrido de la bienvenida con Jürgen — iPhone 14, 13-nov-2026

Sesión manual en la Max. Se verifica, no se programa: cada hallazgo es un ticket en esta carpeta y sus
capturas van a `docs/qa/recorrido-bienvenida-2026-11-13/`.

**Build probada:** Yala Dev (Debug-Dev) compilada de `origin/2.3` en `dc13428f5` más las ramas de los dos
arreglos aún en cola de merge: «Usar otra cuenta» (PR 953) y «Tras ¡Tu cuenta está lista!, Empezar lleva al
Panel» (PR 954). Instalada por cable tras desinstalar Yala y Yala Dev, para partir de cero.

## Flujos

| # | Flujo | Estado | Hallazgos |
|---|---|---|---|
| 0a | Tras «Ya está tu cuenta», directo al Panel | pendiente | |
| 0b | Entrar con otra cuenta de Google o Apple | pendiente | |
| 1 | Welcome (pantalla inicial) | pendiente | |
| 2 | Entrar con Google | pendiente | |
| 3 | Entrar con Apple | pendiente | |
| 4 | Entrar con iCloud privado | pendiente | |
| 5 | «Empezar de cero» | pendiente | |
| 6 | «Dividir con amigos» | pendiente | |
| 7 | Pasos iniciales y minitutoriales | pendiente | |
| 8 | Minitutorial del correo | pendiente | |
| 9 | Bandeja | pendiente | |
| 10 | Modo nube | pendiente | |

## Matriz de escenarios (pedida por Jürgen, 13-nov 14:05)

Cuentas: Google «antigua» = la de staging con grupos; Google «nueva» = una 2.ª cuenta suya, nunca usada en Yala Dev.
Apple «nueva» = su Apple tras «Eliminar cuenta» en Yala. El iCloud del iPhone 14 se puede vaciar (lo aprobó).

| # | iCloud del teléfono | Entrada | Después | Estado |
|---|---|---|---|---|
| E01 | con datos | iCloud privado | Cerrar sesión | pendiente |
| E02 | sin datos | iCloud privado | Vaciar datos | pendiente |
| E03 | con datos | Google antigua | Cerrar sesión | pendiente |
| E04 | con datos | Google nueva | Vaciar datos | pendiente |
| E05 | sin datos | Google antigua | — | pendiente |
| E06 | sin datos | Google nueva | Eliminar cuenta | pendiente |
| E07 | con datos | Apple antigua | Cerrar sesión | pendiente |
| E08 | con datos | Apple nueva (tras eliminar) | Vaciar datos | pendiente |
| E09 | sin datos | Apple antigua | — | pendiente |
| E10 | sin datos | Apple nueva | Eliminar cuenta | pendiente |
| E11 | — | Otra cuenta de Google / de Apple | — | pendiente |
| E12 | — | Empezar de cero · Dividir con amigos · pasos y minitutoriales · Bandeja | — | pendiente |

**13-nov 14:10 — pausa:** la sesión de la Mini («adopt a medias») usó el mismo iPhone 14 por red: reinstaló su build
y mató un adopt a mitad. Las capturas tomadas sobre ese estado se descartaron. Jürgen: primero la Mini; se retoma
cuando suelte el teléfono.

## Notas de Jürgen, por flujo

_(se llenan en vivo)_
