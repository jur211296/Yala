# Auditoría UX 2.2 · lote 1: implementar las 8 L1UI elegidas por Jürgen

> **ALCANCE ESTRICTO:** solo L1UI-1…8 (onboarding / primera vez). Si ves algo fuera, anótalo en una línea y no lo toques.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: ANTES de tu primer commit, `git fetch origin && git reset --keep origin/2.2` (comprueba `git log origin/2.2..HEAD` vacío) y abre el PR contra **2.2**.

## Fuentes
- La variante elegida está en la nota de cada card (último párrafo, «2026-10-13 tarde: Jürgen eligió…»): `tablero ver <id>`.
- Página de variantes: ~/Claude/propuestas/auditoria-ux-2.2/variantes-L1UI.html. PR #489 (docs, en 2.2).
- Maqueta de referencia: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-1-variantes/maqueta-L1UI-variantes.patch (flag `-mockv 2` = rellenos sólidos, `-mockv 1` = rosa de marca). Úsala como guía visual; la implementación final no debe depender de flags de maqueta.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Qué implementar (variante elegida)
| Card | Item | Variante |
|---|---|---|
| jyoj | L1UI-1 · selección | 2 · Rellenos sólidos: tarjeta elegida en índigo profundo, texto blanco, icono en pastilla blanca, check blanco. Componente compartido (propósito, «¿Dónde está tu dinero?», saldo, categorías). |
| nzcq | L1UI-2 · «Calculemos» | 2 · Rellenos sólidos: «¿No sabes tu saldo? Toca aquí y te ayudamos a calcularlo» en rosa sólido #D6006B con texto blanco (contraste ≥4,5:1). |
| ln0i | L1UI-3 · calculadora Todo junto | 2 · Signos en círculos sólidos (índigo suma, rojo resta), total en ficha índigo con la cuenta debajo, «Usar este saldo» fijo abajo. |
| uwqq | L1UI-4 · calculadora tarjeta | 2 · Una cifra «Debes» en ficha índigo, «Línea − Disponible» debajo y el consejo nuevo. |
| 4lhx | L1UI-5 · campo del saldo | 2 · «Ej. 1500» como placeholder y «Escribe tu saldo (o 0) para seguir» en pastilla dentro del campo; desaparece al escribir. |
| m9la | L1UI-6 · progreso | 2 · «Paso N de 7» en pastilla de cristal bajo los puntos, cifras de ancho fijo con transición numérica. |
| jb1f | L1UI-7 · movimiento | 1 · Rosa de marca: el resumen entra por partes (título, lista, privacidad) y cierra con confeti rosa e índigo. Respeta «Reducir movimiento» (solo fundido). |
| rzjy | L1UI-8 · nombre de cuenta | 1 · «Mi dinero <Divisa>» para «Todo junto»; «Gastos <Divisa>» se queda en «Solo anotar mis gastos». |

## Reglas duras
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests: unit de la lógica nueva (nombres de cuenta, signos de la calculadora), XCUITest con -only-testing donde aplique, /gate.
- Capturas antes/después de CADA item (L1UI-1…8) en ~/Claude/entregas/<sesión>/capturas/, enlazadas en el PR.
- Mueve cada card a in qa (assignee jurgen) con nota del PR al cerrar.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy. Cierra con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Base:** la rama ya está en `origin/2.2` (`git log origin/2.2..HEAD` vacío). PR contra `2.2`.
2. **Colores:** índigo profundo `#3D36B3` y rosa profundo `#D6006B` (los de la maqueta, AA con texto blanco) pasan a
   ser `Color.onboardingSelectedFill` / `Color.onboardingEmphasisFill` en el DS de color, no `MockUI`. Rojo de resta:
   `DS.Semantic.errorForeground` si da AA en círculo; si no, `#E5484D` de la maqueta.
3. **L1UI-1:** la selección rellena índigo en los dos fondos (`.heroFlow` y `.themedPanel`): el blanco sobre índigo
   lee igual en ambos. El check entra con escalado (fundido con «Reducir movimiento»). Se añade el rasgo
   `.isSelected` de VoiceOver: es lo mismo que el check dice a la vista.
4. **L1UI-2:** copy nueva en claves nuevas (`onboarding.balanceGuided.title/subtitle`); `accountBalanceLearnMore`
   sigue en crear cuenta y en el título de la hoja simple, que no son de este lote. Elegida, check blanco con glifo rosa.
5. **L1UI-3:** el total y la fórmula salen de UNA lista de términos con signo (`BalanceCalculatorTermsLogic`), testeada;
   el total deja de ser una suma escrita aparte. «Usar este saldo» fijo abajo solo en la variante «Todo junto».
6. **L1UI-4:** «Debes» en ficha índigo también en el modo directo de la tarjeta (sin fórmula): es la misma tarjeta y
   dejar una cifra roja ahí reabre el problema. El consejo nuevo sustituye el valor de `onboarding.calc.creditCard.tip`
   (solo lo usa esta pantalla).
7. **L1UI-5:** la pastilla es blanco al 14 % (la de la maqueta que vio Jürgen), no blanco sólido: la regla dura veta
   el contraste en blanco sólido. Placeholder «Ej. 1500» localizado.
8. **L1UI-6:** «Paso N de M» con el total REAL de pasos (`effectiveTotalSteps`), no un 7 fijo: con «solo gastos» o
   prefill de iCloud son menos. Número en negrita vía markdown en la clave.
9. **L1UI-7:** solo el resumen (lo elegido). Entrada por partes 80 ms + 16 pt con muelle; con «Reducir movimiento»
   solo fundido y sin confeti (`ConfettiView` ya lo apaga). `ConfettiView` gana un `colors:` con el default de hoy.
10. **L1UI-8:** nombre sugerido en lógica pura (`OnboardingAccountNameLogic`) con test; clave nueva
    `onboarding.accountName.allTogether` = «Mi dinero %@».
11. **Capturas:** XCUITest de captura sin commitear, mismo recorrido antes y después, en
    `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-1-implementar-L1UI/capturas/`.
