# CI: que las tandas de UI del QA programado compilen dentro del tope de 25 minutos
toca: .github/workflows (QA programado), scripts de CI; no código de la app

Máquina: Max, después de que cierre la sesión de widgets (widgets-estados-y-restos-lote).
Rama base: 2.2. Un solo PR contra 2.2, un solo cierre.

Card: «CI: las tandas de UI del QA programado no compilan dentro del tope de 25 minutos». Hoy pasó dos veces: 4 de las 8 tandas de UI se cortaron en «Build for testing» y no corrieron sus tests. Run: https://github.com/jur211296/Yala/actions/runs/41865831610

1. Mide en qué se va el tiempo de compilación de cada tanda (caché de DerivedData o SPM, runner, si cada tanda recompila todo).
2. Arregla la causa (por ejemplo, compilar una vez y compartir el build entre tandas, o mejorar la caché). Sube el tope solo si sigue haciendo falta.
3. Lanza el QA a mano con workflow_dispatch y verifica que las 8 tandas compilan a tiempo y corren sus tests.

Mueve la card con `tablero`: en curso al empezar e in qa al cerrar.
Si algo bloquea o cambia el resultado, pregunta con `preguntar-bot`; no asumas.
El cierre trae la sección «Saltado o asumido sin preguntar».
Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido antes de decidir: 12 nocturnas (24-oct → 4-nov). El «Build for testing» de cada tanda va de 11 a
25+ min según el runner, siempre en frío (sin caché de DerivedData ni de SPM). El 4-nov, intento 2: 4 de
8 tandas cortadas a los 25. El log de una cortada seguía compilando `YalaTests` (~260 000 líneas) al
llegar al tope: las tandas de UI compilan los unit sin usarlos.

1. **¿Caché o build compartido?** Build compartido: un job `ui-build` compila una vez y sube
   `.ddp/Build/Products` como artefacto; las tandas lo bajan y corren `test-without-building`. Una caché
   de DerivedData sigue pagando ocho builds incrementales y su acierto depende de la clave; el artefacto
   quita los ocho.
2. **¿Qué compila ese build?** El scheme entero, como hasta ahora. Se probó `-only-testing:YalaUITests`
   para no compilar `YalaTests` y la medida local lo descartó: `build-for-testing` lo compila igual (1 018
   compilaciones de `YalaTests` con el flag). Dejarlo fuera pediría un scheme o test plan propio: queda
   anotado como mejora, no se hace aquí.
3. **¿El job `tests` comparte ese build?** No. Es el check requerido de los PR y no puede esperar a un
   job que solo corre de noche.
4. **Tope del `ui-build`:** 40 min de paso, como el build del job `tests` (máximo verde medido 28,6). El
   tope de 25 de las tandas desaparece con el paso.
5. **Si el `ui-build` falla:** las tandas quedan `skipped`, sus `ui_N` llegan vacías y el aviso ya dice
   «la suite NO llegó a correr». No se añade otro canal.
6. **Subir el tope:** no hace falta; se decide con la corrida de verificación.
7. **Verificación:** `workflow_dispatch` de `qa.yml` sobre la rama del encargo, antes de abrir el PR.
