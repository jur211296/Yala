# Investigar: tras un ajuste de cuenta, el mes nuevo no entra en disponible ni en el widget

## Contexto
Correo a admin@yala-app.pe el 2026-10-02, asunto «Yala (E) - Contacta con nosotros: Error». Jürgen pidió lanzar la investigación. El ticket local (sin commitear, repo público) está en tickets/backlog/adjustment-hides-new-month-activity-from-available-and-widget.md del árbol principal y NO viaja al worktree: este encargo es la fuente.

Una persona registró un ajuste de cuenta el mes pasado. Las transacciones del 1 de octubre sí aparecen en la lista de transacciones, pero no en «disponible del mes» (ni ingresos ni gastos) y tampoco en el widget.
App reportada: Yala v2.0.4 (2), iOS 26.3.1, iPhone, tema Traslúcido, locale es-CO.
No pegues el correo de la persona en el repo (es público).

## Que se pide
Investigación, no arreglo.
- Reproducir: ajuste en el mes anterior + movimientos el día 1 del mes siguiente. ¿«Disponible del mes» y el widget ignoran esos movimientos mientras la lista sí los muestra?
- Ver si el corte de mes, la moneda del ajuste, o el locale es-CO cambian el resultado.
- Si se reproduce: dejar medido el mecanismo y un ticket de arreglo aparte. Cola A solo si hay riesgo real de saldo mentiroso. No abras el PR de arreglo en esta sesión.
- Si no se reproduce: anotar qué faltó del reporte.

Pipeline Mini serial (norma 2026-10-02): limpiar sims muertos; xcodebuild -jobs 2 SIN sim booteado; boot 1 sim; tests; apagar y limpiar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests. Máximo 1 simulador.

## Que NO hay que tocar
- No cambiar la app ni abrir PR de arreglo hasta haber medido. Si hace falta un PR, que sea solo de la investigación medida (test que documenta el hallazgo), no un fix.
- No contestar el correo.
- No commitear el correo ni datos personales.
- No lanzar otra sesión.

## Como se sabe que esta bien
Queda dicho si el caso se reproduce o no, con la medida (lista sí / disponible y widget no, o el resultado real). Cierre autónomo con /cerrar-total. Al cerrar: apagar sim, borrar data de ese device, y si el worktree ya no hace falta quitarlo. No dejar Devices apagados ni worktrees acumulados. Si creas un secreto en el Llavero, no lo dejes solo ahí: anótalo para que Frank lo meta en 1Password (vault Yala; nunca keys de firma en Shared with Grok Bot).

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Dónde se mide.** Test unitario que siembra el caso como lo crea la app (`InitialBalanceService`, movimientos con categoría y subcategoría) y lo pasa por las mismas llamadas que alimentan cada superficie: `HeroBucketsCalculator` para «Disponible» del Panel y `WidgetDataCache.buildPeriodSummary` para el widget. *Por qué:* las dos leen `Date.now` y el escenario «día 1 del mes en curso» se reproduce cualquier día con fechas relativas; un XCUITest no añade nada que el cálculo no diga, y cuesta un simulador más.
2. **Variables cruzadas.** Tipo de ajuste (por registro al alza, por registro a la baja, cambio de saldo inicial), hora del día 1 (medianoche exacta, que es lo que deja el selector de fecha, y 09:00) y moneda de la cuenta (COP, USD). El locale es-CO solo cambia el texto de la nota del ajuste; la zona horaria del simulador es Lima, UTC−5, el mismo desfase que Bogotá.
3. **Qué se entrega.** PR con el test (documenta la medida, no arregla) y el ticket movido a `tickets/done/` con el resultado. Si se reproduce, ticket de arreglo aparte en `backlog`, sin fix.
4. **Código de v2.0.4.** Se compara el código del tag `v2.0.4` con el de `2.1` en las rutas que importan; el test corre sobre `2.1`.
5. **Simulador.** Uno solo (iPhone 17 Pro), arrancado tras compilar, apagado y con datos borrados al cerrar.
