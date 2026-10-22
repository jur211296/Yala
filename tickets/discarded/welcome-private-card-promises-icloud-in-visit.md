---
id: welcome-private-card-promises-icloud-in-visit
status: discarded
priority: low
area: modo-nube
created: 2026-09-07
updated: 2026-09-09
---

# La card «privacidad total» promete tu iCloud, y en visita no hay ninguno

Why: Discarded 2026-09-09. Superado por el ADR 2026-09-09 «Sesiones — dos ejes» (docs/DECISIONS.md): la sesión de visita (M1) se retira del modelo. La card se lee siempre en un móvil cuyo iCloud es el de quien elige.

## El síntoma, en lenguaje de usuario

Estoy usando Yala con mi cuenta en el móvil de otra persona. Llego al segundo nivel de «Es mi
primera vez» y leo la card que voy a elegir:

> **Tu cuenta en tu iCloud privado**
> Tus datos viven en los dispositivos Apple de tu Apple ID y **se sincronizan por tu iCloud
> privado**. Nadie más puede leerlos, ni siquiera nosotros.

**Nada de eso pasa aquí.** El Apple ID de este teléfono no es el mío, y mis datos no van a
sincronizarse a ningún sitio.

## Lo medido (2026-09-07, sobre `ed82e044` + el commit de `welcome-privacy-branch-has-no-secondary-door`)

El store de la sesión secundaria se monta con **`cloudKitDatabase: .none`**
(`SwiftDataConfiguration.swift:1188`, rama `secondarySessionActive`): no se espeja a ninguna
CloudKit, ni a la del dueño ni a la de la visita. La segunda frase de `welcome.new.privateBody` es
por tanto falsa en ese estado. La tercera («nadie más puede leerlos») sigue siendo cierta.

## Por qué es LOW y no se arregló de paso

**Hoy esa card casi nunca se lee.** En producción el sub-chooser de «Soy nuevo» no se muestra: el
percent remoto de la elección nube está en 0, así que `handleNewBranch` hace bypass directo a
`.privateAccount` y el usuario nunca ve las dos cards. La superficie por la que sí pasa todo el
mundo —la pantalla de aviso de sesión secundaria— ya dice el hecho verdadero desde el 2026-09-07
(«se guarda solo para ti y solo en este dispositivo»).

**Deja de ser LOW en cuanto el percent suba de 0.** Ese es el disparador; no hay otro.

## Las salidas

1. **Variar el cuerpo de la card en sesión secundaria** — la card ya conoce su contexto, y sería
   una condición más en `WelcomeNewChooserView`. Contra: una card con dos cuerpos es una card que
   hay que mantener dos veces, y el copy de la nube tendría el mismo problema.
2. **No mostrar el sub-chooser en sesión secundaria** y forzar el bypass a la rama privada. Es más
   simple y coherente con que el alta born-cloud en visita tampoco tiene mucho sentido (el slot
   secundario ya está ocupado por quien está de visita), pero **quita una elección** y eso es
   decisión de producto, no de implementación.
3. **Nada, y se declara**: la pantalla de aviso ya corrige el hecho una pantalla después.

## Criterio de hecho

- [ ] Con el percent de la elección nube > 0 y una sesión secundaria viva, nada de lo que el
      usuario lee antes de elegir contradice lo que va a pasar.

## Relacionados

- [[welcome-privacy-branch-has-no-secondary-door]] — de ahí salió esta medición
- [[welcome-copy-blames-owner]] — el precedente de copy que afirma algo que no es cierto para quien lo lee
