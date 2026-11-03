---
name: un-fotograma-se-aisla-con-variantes-por-argumento
description: Para un salto de 2-20 fotogramas, un solo build con variantes por `-zzVn YES` y un medidor de desplazamiento sobre el vídeo; razonar fallaba
metadata:
  type: feedback
---

Un salto visual de pocos fotogramas (el «44 pt» de la primera entrada a Grupos, 2026-11-02) no se aísla razonando: las
dos hipótesis del ticket (carga, buscador) y las mías (split, `.large`, toolbar, avisos, márgenes) eran falsas. Lo que lo
encontró en una hora: **un solo build con cada sospechoso apagable por argumento de lanzamiento** (`zzUnless("zzV3") {
$0.toolbar {…} }` leyendo `UserDefaults`), un conductor XCUITest que pasa la variante por `TEST_RUNNER_ZZVARIANT`, y un
script que mide el desplazamiento vertical por correlación de perfiles de filas entre el primer fotograma y el estable
(validado antes contra un caso conocido: 44 y 0). La causa salió en la sexta variante (`onScrollVisibilityChange`).

**Why:** cada rebuild cuesta 2-10 min en la Mini; con variantes en un binario, cada hipótesis cuesta una grabación de 25 s.
Y el control (otra página sin el problema, Registros) fue lo que acotó la lista de sospechosos.

**How to apply:** ante un «se mueve / asoma un instante», graba antes de tocar, valida el medidor con un caso con y otro
sin, compara con una página hermana que no lo hace y monta las variantes en un build. Retira los `zz` antes del gate
(`grep -rn "zz\|ZZ" Yala`). Relacionado: [[instrumentar-gana-a-razonar]], [[el-control-que-no-recorre-el-camino-no-descarta]].
Y la review adversarial del diff, aun pequeño, cazó tres defectos reales (shell de solo grupos con la selección en
Panel; `disablesAnimations` que viaja a los `onChange`): pídela aunque el cambio parezca de pulido.
