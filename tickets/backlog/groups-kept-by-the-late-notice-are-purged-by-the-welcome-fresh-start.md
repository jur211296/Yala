---
id: groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start
status: backlog
priority: low
area: "onboarding, groups"
created: 2026-09-27
source: "review adversarial de `late-notice-of-a-welcome-private-session-purges-groups-joined-later` (2026-09-27, lente «después del borrado»); inferido por lectura, NO reproducido"
---

# Los grupos que el aviso tardío conserva se pierden si luego cancelo el onboarding y empiezo de cero en el Welcome

## El síntoma, en lenguaje de usuario

Contesto «Empezar de cero» en «Encontramos datos tuyos en iCloud». Mis grupos se quedan y vuelvo al onboarding
personal. Si ahí toco «Cancelar», vuelvo al Welcome; si elijo «Es mi primera vez → privado», me sale el aviso de «hay
datos en este teléfono» y, si confirmo, se borran también mis grupos, su sesión y el dominio queda sellado.

## Lo medido (2026-09-27, leyendo código)

- Tras el aviso, `hasShownWelcomeChooser` sigue en `true` y la persona entra directa al onboarding
  (`ContentView.presentNextOnboardingScreen`). El «Cancelar» del paso 1 lo baja y la manda al Hero.
- `startFreshPrivateOnboarding` cuenta los grupos (`hasLocalDataNow` → `SplitGroup`) y enseña el alert del handover,
  cuyo copy es el de «aquí empieza otro usuario». Su borrado purga y sella lo que el aviso acababa de conservar.
- Las puertas de organizador e invitación también ven esos grupos como datos del teléfono (`.returnsToNeutral`).
- Existe igual desde #280 para quien activó Yala completo; desde este ticket le pasa también a quien empezó en el
  Welcome privado.

## Qué hay que decidir

Si volver al Welcome desde el onboarding tras el aviso tardío debe ofrecer el camino de «misma persona» (conservar los
grupos) o si el alert del handover es lo correcto porque quien vuelve al Welcome puede ser otra persona.

## Criterios de aceptación

- [ ] La persona que acaba de conservar sus grupos en el aviso no los pierde por cancelar el onboarding y volver a
      elegir privado, o lo hace con un copy que se lo diga.

## Relacionados

- [[late-notice-of-a-welcome-private-session-purges-groups-joined-later]]
- [[activation-private-gate-leaves-a-late-notice-that-purges-groups]]
