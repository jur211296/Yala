---
id: secondary-visit-data-lost-on-signout-unannounced
status: discarded
priority: medium
area: modo-nube
created: 2026-09-07
updated: 2026-09-09
---

# La visita apunta sus gastos en un móvil prestado, y al salir se los lleva el wipe

Why: Discarded 2026-09-09. Superado por el ADR 2026-09-09 «Sesiones — dos ejes» (docs/DECISIONS.md): la sesión de visita (M1) se retira del modelo. La «visita» que crea una sesión privada en un móvil ajeno deja de ser un recorrido: la sesión privada es del Apple ID del teléfono.

## El síntoma, en lenguaje de usuario

Uso Yala con mi cuenta en el móvil de un amigo. Elijo «Es mi primera vez → privacidad total»,
completo el onboarding, creo mi cuenta y apunto unos gastos. Cuando cierro mi sesión de invitada,
**todo eso desaparece** — y en ningún momento se me dijo que iba a pasar.

## Lo medido (2026-09-07)

Dos hechos que se combinan:

1. El store de la visita es **`cloudKitDatabase: .none`** sobre `YalaModel-Secondary`
   (`SwiftDataConfiguration.swift:1188`): no hay espejo en ninguna nube. Lo que se apunta vive en un
   único archivo, en un teléfono que no es suyo.
2. La salida de la sesión **borra ese archivo**: `performSecondaryWipeIfArmed` elimina los tres
   archivos `-Secondary` y purga el cajón de preferencias.

⇒ El camino privado en visita produce datos que **solo pueden existir mientras dure la visita**, y
la app no lo dice en ninguna pantalla.

## Por qué es una pregunta de producto y no un bug

El wipe **es correcto**: es lo que garantiza que la visita no deje rastro en el móvil del dueño, y
es la mitad que hace defendible ofrecerle la sesión. Lo que falta no es código, es una decisión
sobre **qué se le cuenta y cuándo**, y las opciones tienen contrapartidas reales:

1. **Decirlo en el aviso de sesión secundaria** (la pantalla que existe desde el 2026-09-07). Una
   frase más: «cuando cierres tu sesión, esto se borra». Contra: **disuade justo en el momento de
   empezar**, y el aviso está escrito hoy para tranquilizar, no para advertir.
2. **Decirlo al salir**, en la confirmación de cerrar la sesión de invitada. A favor: es el momento
   en que la información es accionable. Contra: llega tarde para quien ya apuntó dos semanas.
3. **Ofrecer una salida** (exportar, o convertir la visita en cuenta nube antes de cerrar). Es la
   única que no pierde datos, y es la más cara con diferencia.
4. **Nada, y se declara**: quien usa un móvil prestado para sus finanzas ya asume que es temporal.

**No decidas esto desde el ticket**: la 1 y la 2 son incompatibles en tono y las dos son baratas;
la 3 es otro tamaño de trabajo.

## Criterio de hecho

- [ ] Decisión del owner sobre cuál de las cuatro.
- [ ] Si es la 1 o la 2, copy propio en los 16 `.lproj` y una red que lo ancle.

## Relacionados

- [[welcome-privacy-branch-has-no-secondary-door]] — de ahí salió; su decisión (2026-09-06) enumeraba
  tres cosas para el aviso («de visita, no se mezcla, sigue») y esta advertencia sería una cuarta,
  con contrapartida, así que se sacó a su propio ticket en vez de colarla en el copy.
