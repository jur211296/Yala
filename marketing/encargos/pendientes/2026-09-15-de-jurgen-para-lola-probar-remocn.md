---
de: jurgen
para: lola
fecha: 2026-09-15
estado: abierto
---

# Probar Remocn en el proyecto Remotion de Yala

## Contexto
**Remocn** (<https://github.com/Remocn/remocn>, MIT, gratis, 1.5k estrellas) es un catálogo de
componentes para Remotion —animaciones, transiciones, fondos, escenas, títulos cinéticos— que se
copian al proyecto con `npx shadcn@latest add @remocn/<componente>`, al estilo shadcn: el código
queda en el repo y se edita. Trae además una skill para agentes:
`npx skills add Remocn/remocn --yes`.

Encaja porque `Yala/marketing/remotion` ya existe y está vivo: Remotion 4.0.523, React 19,
Tailwind 4 y `@remotion/transitions`. Hoy cada transición y cada título se escriben a mano en
`src/components`; Remocn puede ahorrar eso en la siguiente pieza.

## Qué se espera
1. Instalar la skill de Remocn y traer **dos o tres componentes** que sustituyan algo que ya
   existe en `src/components` (una transición, un título) en una rama aparte.
2. Comparar contra lo propio: si el resultado es igual o mejor y el código es más corto, se
   adopta; si no, se descarta y se dice por qué.
3. Anotar en tu memoria el veredicto y qué componentes del catálogo merecen la pena.

## Qué NO hacer
- No reescribir las piezas ya entregadas (Presentation-16x9, la de redes) con Remocn.
- No traer componentes que arrastren dependencias nuevas sin decirlo.
- No mezclar esta prueba con la de Recordly: son dos encargos.

## Cómo se sabe que está bien
Una rama en Yala con los componentes probados y una comparación de dos líneas en tu memoria.

## Vuelta
(la rellena Lola)
