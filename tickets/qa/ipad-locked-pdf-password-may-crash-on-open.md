---
id: ipad-locked-pdf-password-may-crash-on-open
status: qa
priority: medium
area: "image-entry, pdf, ipad"
created: 2026-10-12
updated: 2026-10-12
source: tablero tablero-receiptdropuitests-test-lockedpdf-falla-pbwh (hallazgo del PR #464)
---

# En iPad, abrir un PDF con contraseña puede cerrar Yala al pulsar «Abrir»

## Qué se vio (simulador, no en un iPad real)

El 2026-10-12, en el iPad Pro 11 (M5) con iOS 27.0, `ReceiptDropUITests.test_lockedPDF_asksForThePassword_andReadsEveryPage`
falló 2 de 5 corridas. Una fue un **cierre de la app**: UIKit aborta (`-[UIFocusSystem _focusEnvironmentWillDisappear:]`)
cuando la hoja cambia de fase tras «Abrir» con el campo de contraseña todavía enfocado. El `.ips` está en
`~/Claude/entregas/Yala-2026-10-12-receiptdrop-aviso-tope-staticText/`. En la otra, soltar el PDF no abrió la hoja.

No se sabe si es del simulador o de la app. Si pasa en un iPad real, es un bug de producto: quien lee su estado de cuenta
protegido pierde la lectura y ve la app cerrarse.

## Device-QA (Jürgen, en el iPad)

Montaje: un PDF de 2 o 3 páginas con contraseña. En el Mac: Vista Previa › Archivo › Exportar › «Cifrar» con una
contraseña, y pásalo al iPad por AirDrop a Archivos.

1. En el iPad, Yala a pantalla completa. Panel › imagen › **Archivo** › elige el PDF. Sale el campo de contraseña con el
   teclado arriba.
2. Escribe la contraseña y pulsa **Abrir** sin cerrar el teclado. **Bien:** «Página 1 de N…» y luego los movimientos.
   **Mal:** Yala se cierra.
3. Repite los pasos 1 y 2 cinco veces. Una vez, pulsa «Abrir» con el teclado físico o el «Intro» del teclado en pantalla.
4. Con Archivos y Yala en Split View, **arrastra** el PDF sobre Yala y repite el paso 2. **Bien:** se abre la hoja y pide
   la contraseña.
5. Si Yala se cierra alguna vez: Ajustes del iPad › Privacidad › Análisis › Datos de análisis › el informe `Yala-…` más
   reciente. Pásaselo a Frank.

**Resultado:**
- 0 cierres en 6 intentos → el fallo es del simulador. Este ticket pasa a `done` y la card sigue con Frank como test
  intermitente.
- Algún cierre → bug de producto: este ticket vuelve a `backlog` con prioridad `high` y el informe.
