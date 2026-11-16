---
toca: YalaUITests/BalanceCalculatorReopenUITests.swift, Yala/App/Views/Shared/BalanceCalculatorSheet.swift, Yala/App/Views/Accounts/, Yala/App/Views/Onboarding/, Yala/App/Logic/BalanceCalculatorInputLogic.swift
release: no
---
Yala
# Calculadora del saldo: «Editar» no aparece al volver a abrirla (test de UI en rojo en 2.2)

En el QA programado de 2.2 de hoy (run https://github.com/jur211296/Yala/actions/runs/42677093033, tanda 1 de UI), `BalanceCalculatorReopenUITests.test_reopeningTheCalculator_keepsAThousandsBalance` falló 3/3 (BalanceCalculatorReopenUITests.swift:74): no apareció «Editar» bajo «Calcúlalo conmigo» al reabrir la calculadora del saldo. Jürgen quiere resolverlo antes de la subida de 2.2 a TestFlight y App Store.

## Qué hacer
1. Desde `origin/2.2` al día, reproduce el test en simulador. Mide primero contra la versión publicada (1.0 / App Store) y en la app 2.2 a mano: ¿es un bug real de la app o el test quedó desactualizado?
2. Si es bug de la app: corrígelo con el cambio mínimo; la cobertura va en el propio test de UI `BalanceCalculatorReopenUITests` (no toques `YalaTests/`, lo está usando otra sesión). La vista está en `Yala/App/Views/Shared/BalanceCalculatorSheet.swift` (usada desde Cuentas y Onboarding).
3. Si es el test: ajústalo a la UI actual sin debilitar lo que verifica (el saldo con miles se conserva al reabrir y «Editar» está disponible).
4. Corre ese test varias veces y la tanda de UI afectada. El flake de `AppLanguageSettingsReturnUITests` no es de este encargo; solo anótalo si lo ves.
5. PR contra 2.2, sin firma de IA. Si CI queda verde y está completo, mergéalo.
6. Crea o actualiza la card en el tablero (versión 2.2) y déjala en done con la evidencia al mergear.

## Límites
- No toques TestFlight, marketing/ ni 1.0. Hay otra sesión de Yala en la Mini (foto de perfil, Perfil, Sentry y `YalaTests/`): no toques sus archivos.
- En la Max puedes usar un segundo simulador si el primero está ocupado por otra sesión (tope 2 en la Max), o el iPhone 14 conectado por DeviceMCP.
- Lo menor y reversible lo decides tú y lo anotas en «Decidido sin consultar».

## Cierre
Modo semiautónomo. Si está completo y mergeado, cierra con `/cerrar-total`. Si aparece algo vital, pregúntalo y espera con la sesión viva.

## Paso 0 — decisiones

> Modo semi. Nodos menores y reversibles: resueltos por Frank con su recomendación; se discuten en el PR.

Hechos medidos antes de decidir: el caso pasaba en la nocturna hasta el 5-nov y cae 3/3 desde el 8-nov.
Reproducido en local (iPhone 17 Pro, iOS 27.2). El vídeo del fallo enseña que, con el teclado abierto,
la tarjeta «Calcúlalo conmigo» queda debajo de la barra de «Siguiente» (paso a `safeAreaBar` del
5-nov). XCUITest toca el centro de la tarjeta, el toque cae en «Siguiente» y el onboarding salta al paso 6.
En 1.0 el paso usa `safeAreaInset` y el test no existe.

**D1 · ¿Bug de la app o test desactualizado?** → Test desactualizado.
Por qué: una persona ve «Siguiente» encima de la tarjeta y cierra el teclado arrastrando, o toca la
franja visible; con el inset de antes la tarjeta también quedaba tapada (por el teclado). La app hace lo
que decidió Jürgen el 5-nov. Alternativa descartada: tocar `OnboardingView` (zona de otra sesión, y sin
bug que arreglar).

**D2 · ¿Cómo llega el test a la tarjeta?** → Cierra el teclado arrastrando el paso hacia abajo y espera
a que no haya teclado; luego toca la tarjeta. Por qué: es el gesto humano (el teclado decimal no tiene
«Aceptar») y no relaja ninguna aserción. Alternativa descartada: tocar por coordenadas la franja visible
(frágil por tamaño de pantalla).

**D3 · ¿Se toca algo más?** → No. Ni `YalaTests/` ni la vista. El resto de rojos de la corrida
(AppLanguageSettingsReturn, AccountEditMultiCurrency, CashFlowPlan, PaywallInboxAlertRouting) pasaron
al reintentar: se anotan, no se persiguen.
