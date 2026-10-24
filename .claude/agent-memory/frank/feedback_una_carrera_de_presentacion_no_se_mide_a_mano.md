---
name: una-carrera-de-presentacion-no-se-mide-a-mano
description: Un bug de hoja que no aparece depende del ritmo: a mano (axe, toques lentos) gana la carrera; el XCUITest la pierde. Mídelo con sonda NSLog + log stream durante el XCUITest.
metadata:
  type: feedback
---

Una hoja que «no se reabre» tras una reconstrucción se mide con el XCUITest, no conduciendo a mano. El 2026-10-24
(card 6d71, idioma → Ajustes) la conducción con `axe` y pausas de 2 s salió bien las dos veces; el XCUITest, que toca
sin pausas, cayó 2 de 3. La causa salió de una sonda `NSLog` (profundidad de `presentedViewController` cada 100 ms) y
`simctl spawn … log stream` filtrando también `already presenting` / `while a presentation`: el aviso de UIKit es el
veredicto.

**Why:** a mano casi me llevo un «no se reproduce» sobre un bug medido 2 de 2 en el barrido.

**How to apply:** ante un rojo de presentación intermitente, (1) sonda + log stream y XCUITest con
`-test-iterations 3`; (2) `continueAfterFailure = true` temporal si quieres ver qué pasa después del primer rojo; (3)
tras un rojo, iOS 27 cuelga el desmontaje de `xcodebuild` ~10 min: corta tu propia corrida exploratoria por PID, nunca
por nombre. Las corridas VERDES no dejan vídeo en el xcresult: el «después» se captura a mano.
Relacionado: [[ver-un-fallo-de-xcuitest-en-video]], [[instrumentar-gana-a-razonar]].
