---
id: more-tab-missing-profile-button
status: done
priority: medium
area: "more, navigation, ux"
created: 2026-09-17
updated: 2026-10-03
source: "UX Jürgen 2026-09-17 (bugs de experiencia sin ticket)"
---

# En la tab Más falta el botón de perfil arriba a la derecha (junto a preferencias)

## Qué quiere el usuario

En la tab **Más**, arriba a la derecha, además del botón de preferencias, mostrar también el de **perfil**, igual que cuando estás en el **Panel**.

## Por qué

Hoy el perfil solo es evidente desde Panel; en Más hay que buscarlo. Misma chrome = menos fricción.

## Pista

Reusar el control de perfil del Panel en la barra de Más (trailing), sin duplicar lógica de sesión/cuenta.

## En iPad (heredado de `cola-b-redesigns-must-hold-up-at-ipad-width`, 2026-10-03)

En ventana ancha Más deja de ser una pantalla: sus páginas van en la barra lateral. No invertir en rediseñar Más como
pantalla para el iPad; lo que se haga aquí es para la barra de pestañas del iPhone (ancho compacto).

## Resultado (2026-10-03)

- En Más, arriba a la derecha, sale el avatar de Perfil junto a Personalizar, en el mismo orden que el Panel
  (preferencias y luego el avatar). Abre el mismo Perfil. Es el `ProfileToolbarItem` de siempre, con la hoja de
  Perfil que Más ya tenía para su tarjeta: sin lógica nueva de sesión ni de cuenta.
- En la shell de solo grupos el avatar también se ve (Personalizar no): Grupos ya lo enseña sin condición.
- La tarjeta «Perfil» de Herramientas se queda; quitarla sería rediseñar Más.
- Test: `ProfileSettingsUITests#test_moreTabShowsProfileButtonNextToEditor` (existe, va a la derecha del editor,
  abre el Perfil). Mutante sin el avatar: rojo en la aserción del avatar.
