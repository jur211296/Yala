---
name: axe-primer-toque-y-mazo-en-un-paso
description: Simulador de Yala con axe — el primer toque por coordenadas tras lanzar se pierde; tocar por --id y comprobar. Y el mazo de Primeros pasos se arranca en el paso N con -uitest-setup-deck-at.
metadata:
  type: reference
---

Medido el 2026-11-12 (lote 05 de la bienvenida 2.3, iPhone 17 Pro iOS 27.2): tras `simctl launch` con semilla, el primer
`axe tap -x -y` sobre el mazo no hizo nada dos veces seguidas; el segundo sí. `axe tap --id <accessibilityIdentifier>`
entró a la primera. **Cómo aplicarlo:** conduce por `--id` y verifica con `axe describe-ui` que la pantalla cambió antes
de capturar; un `--id` de algo bajo el pliegue «toca» fuera de pantalla sin error: desliza antes.

Para capturar los pasos 6, 7 y el final sin recorrer los cinco primeros: `-uitest-show-setup-deck -uitest-setup-deck-at
<n>` (8 = mazo completo, dispara la oferta) con `-uitest-fresh-install`, más `-uitest-fake-prices eligible` y
`-uitest-fake-purchase` para la oferta. Ver [[ax-loaded-timeout-se-cura-reiniciando]].
