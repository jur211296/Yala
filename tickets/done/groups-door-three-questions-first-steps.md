---
id: groups-door-three-questions-first-steps
status: done
priority: medium
area: "welcome, onboarding, setup-checklist, tutorials"
created: 2026-11-13
updated: 2026-11-13
card: tablero-puerta-de-grupos-tres-cosas-que-conviene-8z4t
source: "recorrido de la bienvenida en el iPhone 14 (13-nov), E01, E03, E13 y E14"
---

# Puerta de Grupos, las tres preguntas completas al recuperar datos y Primeros pasos en el iPhone 14

Tres cards del recorrido del 13-nov (`docs/qa/recorrido-bienvenida-2026-11-13/`):

- `tablero-puerta-de-grupos-tres-cosas-que-conviene-8z4t` (E13).
- `tablero-quien-recupera-sus-datos-no-pasa-por-las-ptuf` (E01 y E03).
- `tablero-primeros-pasos-en-el-iphone-14-la-hoja-c-hara` (E14).

## Hecho cuando

- «¡Hola de nuevo!» desde la puerta de Grupos no ofrece iCloud, y «tres cosas que conviene saber» tiene un solo diseño y
  un solo momento.
- Quien recupera sus datos responde las tres preguntas enteras, no a medias (nota de Jürgen en la card).
- En un iPhone 14 los 7 pasos se ven enteros y se abre cualquiera tocándolo, no se apilan guías, el paso 7 se puede
  leer y el tutorial de la Bandeja tiene tantos puntos como pasos dice.

## Resolución (2026-11-13)

1. **Puerta de Grupos.** `WelcomeAccountChoiceLogic.existingChooserOrder`: desde la puerta (marca
   `WelcomeGroupsDoorLanding` u origen `.groupsChooser`) quita «Restaurar desde iCloud» y la nota del faro, que habla
   de la cuenta personal del Apple ID y no del último acceso del teléfono; y sin iCloud, el subtítulo que lo nombraba. Sin entradas a una cuenta, se queda lo que había.
2. **Un solo momento para el consentimiento.** Apple y Google de «¡Hola de nuevo!», y la vuelta de la puerta de la
   entrada con otra cuenta, van por el acceso único (`.unified`) de la vitrina: firman y el consentimiento va dentro de
   «¿Cargamos tus datos…?» / «Vamos a crear tu cuenta». Sin cuenta sale «Vamos a crear tu cuenta» (con App Attest) o
   «No encontramos una cuenta» (sin él), como en la vitrina.
3. **Tres preguntas enteras.** `WelcomeConversationView` ya no recibe el resumen restaurado: propone el nombre del
   proveedor si lo hay y la moneda de la región, como a cualquiera. El resumen completo sigue yendo directo a la app.
4. **«Ver los 7 pasos».** Abre en `.large`; cada paso sin hacer es un botón que, al cerrarse la hoja, abre su flujo por
   el mismo camino que el mazo (`SetupStepsListLogic`).
5. **Guías apiladas.** `PlaceGuideCenter.start` retira la tarjeta «Este es tu resumen» del Panel (como su X).
6. **Paso 7.** `TutorialStoryPage` acepta la duración por parte; «Anota sin abrir Yala» va a 6 s.
7. **Puntos de los tutoriales.** `TutorialProgressDots`: un punto por paso, sin portada ni final.

Tests: `YalaTests/GroupsDoorAndFirstSteps/` (cinco suites) y
`Bienvenida23BaseUITests#test_stepsList_opensAStepThatIsNotTheNextOne`; actualizados los que fijaban lo viejo
(`UXAudit22Lote6LogicTests`, `WelcomeChooserUITests`, `WelcomeAccountExistsUITests`).

## Fuera

- «¡Primeros pasos completos!» aunque se omitan pasos: Jürgen lo deja así.
- La biblioteca de Tutoriales no tiene uno del correo (función nueva, sin decidir).
- La nota de Gmail del minitutorial del correo queda bajo «Listo» hasta desplazar en un iPhone 14 (se lee al desplazar).
