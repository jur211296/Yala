Yala
# CI: el script del simulador vuelve a encontrar un destino válido en el runner
---
toca: qa/scripts/ci-simulador.sh, qa/scripts/ci-simulador-test.sh, .github/workflows/qa.yml, tickets/done/2026-11-16-ci-simulador-runner.md
esfuerzo: medium
cierre: cierra-sola
---

## Qué pasa
La rama 2.3 está en rojo. El job `tests` del workflow `qa.yml` falla en «Build for testing» (exit 70) y la suite no llega a correr. `qa/scripts/ci-simulador.sh` crea un iPhone 17 Pro con iOS 27.0, pero xcodebuild con el esquema Yala Dev solo ve simuladores con iOS 27.1 y 27.2 (iPhone 17, 17e, 18 Pro…), y no hay ningún iPhone 17 Pro. Es la imagen nueva del runner, no una regresión de la app.
- Runs: https://github.com/jur211296/Yala/actions/runs/43807611829 y https://github.com/jur211296/Yala/actions/runs/43811798736 (PR «Registros: el calendario se pliega a la semana del día», con el auto-merge bloqueado).
- Antecedente: `encargos/lanzados/2026-10-23-ci-simulador-ios-27-1.md` (el mismo tipo de problema con iOS 27.1).
- Card del tablero: «La rama 2.3 está en rojo: tests no encontró el simulador». Ciérrala al terminar.

## Qué hacer
1. Que el script elija el runtime y el modelo **según lo que el esquema realmente ve** (por ejemplo, `xcodebuild -showdestinations` o el runtime más nuevo disponible con un iPhone compatible), en lugar de fijar versión y modelo. Si no hay destino válido, que falle con un mensaje claro que liste lo que sí ve.
2. Actualiza o suma casos en `qa/scripts/ci-simulador-test.sh`.
3. Comprueba en CI que `tests` vuelve a verde en 2.3 y que el PR del calendario puede mergearse. Si sigue rojo por tests reales de producto, no los toques: anótalo en el cierre y crea una card aparte.

## Reglas
- No cambies código de la app ni tests de producto. Solo el script, su test y, si hace falta, `qa.yml`.
- PR a 2.3, sin firma de IA. Sin entregable visual: basta el run verde enlazado en el cierre.
- Cierre según el modo fijado al arrancar: si está completo y el modo lo permite, `/cerrar-total`. En nocturno, lo vital va a checkpoint con card para Jürgen, sin mergear lo incompleto.
- En el cierre van «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en autónomo, modo semi)

1. **¿Causa?** Medida: la imagen `xcode-27-arm64` 20261112.0361.1 trae el mismo runtime iOS 27.0
   (24A434) y el mismo Xcode 27.1, pero xcodebuild no ofrece el 27.0 como destino. Los runs verdes
   cayeron en la 20261104. El rojo es intermitente según la imagen que toque.
2. **¿Filtrar antes por lo que lista xcodebuild o validar después?** Después: `-showdestinations`
   solo lista devices existentes, y en la imagen buena el iPhone 17 Pro del 27.0 se crea en el
   script. Filtrar antes lo descartaría también ahí.
3. **¿Si no lo ve?** Excluir ese runtime y repetir la búsqueda con el orden de siempre. En el job
   `tests` (tolerante) acaba en el 27.2 con aviso. En `ui` (estricto) falla con el motivo.
4. **¿Si `-showdestinations` falla?** Avisar y seguir: el build es la prueba siguiente.
5. **¿Modelo?** Se mantiene el iPhone 17 Pro (el 27.2 lo admite); no se cambia a otro modelo.
6. **¿Subir Xcode del CI a 27.2?** No: va con la release (regla `ci-qa.md`). Queda en «Encontrado».
