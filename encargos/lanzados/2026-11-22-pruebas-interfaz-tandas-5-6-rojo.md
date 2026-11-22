Yala
# Pruebas de interfaz: encontrar por qué fallan las tandas 5 y 6 en la CI de 2.3 y arreglarlas
---
toca: YalaUITests/,.github/workflows/,tickets/backlog/2026-11-22-pruebas-interfaz-tandas-5-6-rojo.md,tickets/done/2026-11-22-pruebas-interfaz-tandas-5-6-rojo.md
esfuerzo: medium
cierre: cierra-sola
---

Jürgen pidió el 22-nov (10:01 Lima, decisión registrada) revisar la causa. En la CI de 2.3 las tandas 5 y 6 de YalaUITests están en rojo. El run general sigue en verde porque la interfaz es solo informativa a propósito, así que no frena merges. Log: https://github.com/jur211296/Yala/actions/runs/44991989046 (commit b27dcc08).

## Qué hacer
1. Lee el log y separa cada prueba que falla: fallo real de la app, prueba desactualizada por un cambio de UI que ya entró, o inestabilidad del runner.
2. Reprodúcelas en local con el script que elige qué pruebas correr (solo en el gate local; no agregues jobs pagos de CI).
3. Arregla las pruebas desactualizadas o inestables en `YalaUITests/`. Si alguna destapa un bug real de la app, NO lo arregles aquí: anótalo en el cierre con su evidencia y la propuesta de encargo.
4. No cambies que la interfaz sea informativa en la CI.

## Criterios de aceptación
- Las tandas 5 y 6 pasan en local y en la CI de tu PR, o queda explicado por qué una sigue roja y qué la arregla.
- PR a 2.3 con auto-merge.

## Cómo trabajar
- iPhone 14 conectado a la Mini vía DeviceMCP: verifica de verdad si está libre antes de usarlo. En la Max puedes usar un segundo simulador además del de otra sesión. No uses `-derivedDataPath /tmp/claude-*`.
- Commits y PR sin firma de IA. No te saltes hooks. Termina con /cerrar-total cuando el PR haya entrado.

## Paso 0 — decisiones (resueltas en semi, sin preguntar: ninguna es de producto)

1. **¿Qué falla?** Medido en el log del run del 22-nov: tanda 5, `PersonalToGroupConversionUITests` (2 casos, 3/3),
   `PanelSectionsConfigResetUITests` (3/3) y `FlujoCrearPlanUITests.test_armado…` (1/2, pasó al reintento); tanda 6,
   `FirstExpensePracticeAlertUITests` (superó los 10 min). En local (iOS 27.2) los 5 pasan a la primera.
2. **¿Regresión o inestabilidad?** Inestabilidad: en la nocturna del 21-nov los dos primeros ya fallaban y pasaban al
   reintento. Ninguna prueba destapa un bug de la app.
3. **Arreglo:** en las pruebas, no en la app ni en el CI. Toques con el elemento quieto (el toque frenaba la inercia del
   deslizamiento), arrastre lento con pausa y un reintento, plazos de 5 → 15 s (cada lectura cuesta 1-3 s en el runner).
4. **Tanda 6:** no se toca la prueba. El cuelgue es del runner (XCUITest espera 60 s por gesto a que acaben las
   animaciones; le pasó también a dos casos de `ExternalEntryForeignSheetUITests`, que pasaron en 7 min). Se explica en
   el cierre con la propuesta de encargo.
5. **Verificación en CI:** el CI de un PR no corre la UI (solo la nocturna o un lanzamiento manual). No se lanza una
   corrida manual (14 tandas, «no agregues jobs pagos»): la prueba en CI es la nocturna de esta noche sobre 2.3.
