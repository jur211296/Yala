---
id: groups-educational-second-button-reads-as-go-to-groups
status: done
priority: medium
area: groups
created: 2026-10-20
updated: 2026-10-22
source: punto extra de Jürgen (QA 2026-10-20), card «UX 2.2 · Último paso del educativo de Grupos: ¿qué hace el segundo botón junto a «Aceptar y continuar»?»
---

# El segundo botón del último paso del educativo de Grupos se leía como el mismo destino

## Qué pasaba

En el paso del consentimiento, «Aceptar y continuar» y «Ir a Grupos» parecían ir al mismo sitio. «Ir a Grupos» sale
sin aceptar y deja en la pestaña, que vuelve a pedir lo mismo.

## Cerrado (2026-10-22) — decisión B de Jürgen

El segundo botón se llama «Ahora no» (`action.notNow`, ya traducida en los 16 idiomas) y hace lo mismo que antes: sale
sin aceptar. Solo en el paso del consentimiento; con el consentimiento ya dado el cierre sigue siendo el de la cuenta.
Test: `GroupsEducationalUITests/test_educational_consentStep_secondaryButtonSaysNotNow`.
