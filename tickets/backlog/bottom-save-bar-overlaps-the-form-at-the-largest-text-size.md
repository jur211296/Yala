---
id: bottom-save-bar-overlaps-the-form-at-the-largest-text-size
status: backlog
priority: high
area: "a11y, design-system, iphone"
created: 2026-11-05
updated: 2026-11-05
source: "barrido final de QA 2.2 (2026-11-05), card tablero-con-el-texto-al-maximo-la-zona-fija-de-g-3nos"
---

# Con el texto al máximo, la zona fija de «Guardar» pisa el formulario

## Qué le pasa al usuario

Con el texto en los tamaños de accesibilidad, los botones fijos de abajo quedan encima del contenido que se desplaza y
los dos textos se leen uno sobre otro:

- **Nuevo registro**: «Para guardar, falta el monto, la cuenta y la categoría» y «Guardar» sobre «Escribe ! y elige la
  categoría sin salir de aquí» y «¿Cuánto gastaste?».
- **Nuevo gasto de Grupos**: «Guardar» sobre «y dividido en partes iguales».
- **Onboarding, paso 1**: «Siguiente» sobre el subtítulo.

Medido en el simulador (iPhone 17 Pro y 17e, iOS 27.2, oscuro, AX5). A tamaño normal no pasa en el iPhone, **pero sí en el
iPhone Duo cerrado** (678 pt de alto): ahí el «Siguiente» del onboarding pisa la ayuda «Puede ser tu nombre…» con el texto
de siempre, en claro y oscuro.

## Por qué

Los tres usan `.safeAreaInset(edge: .bottom)` sin fondo (`NewTransactionView.SaveAreaPlacement`,
`GroupExpenseFormView`, `OnboardingView`). El inset reserva el sitio al final del scroll, pero mientras se desplaza el
contenido pasa por debajo y se ve.

## Propuesta

`safeAreaBar(edge: .bottom)` (iOS 26), que ya usa `YalaStepGuide`: mismo sitio y el difuminado nativo del borde del
scroll debajo de la barra. Cambia el aspecto (el borde se difumina), por eso no entró en el PR del barrido. Revisar con
la misma vara los otros 18 `safeAreaInset(edge: .bottom)` de `Yala/App` (medido con grep el 2026-11-05: 21 en total).

## Evidencia

`/Users/max-jur/Claude/worktrees/_capturas/barrido-qa-2-2-final/iphone17pro/oscuro-ax5/08-nuevo-registro.png`, `08b-nuevo-registro-abajo.png`, `07e-gasto-compartido.png`;
`/Users/max-jur/Claude/worktrees/_capturas/barrido-qa-2-2-final/iphone17e/oscuro-ax5/08-nuevo-registro.png`, `19-onboarding-nombre.png`;
`/Users/max-jur/Claude/worktrees/_capturas/barrido-qa-2-2-final/duo-cerrado/oscuro-normal/19-onboarding-nombre.png`, `/Users/max-jur/Claude/worktrees/_capturas/barrido-qa-2-2-final/duo-cerrado/oscuro-ax5/08-nuevo-registro.png`.

## Hecho cuando

A AX5 en el iPhone 17e ningún texto queda debajo de «Guardar»/«Siguiente» sin difuminar, y a tamaño normal las tres
pantallas se ven igual (diff de píxeles).
