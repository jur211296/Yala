---
id: 2026-11-19-primeros-pasos-paso-7-y-prueba-maquetas
status: done
priority: medium
area: "onboarding, primeros-pasos, pro"
created: 2026-11-19
updated: 2026-11-20
card: tablero-maquetas-paso-7-sheet-de-los-7-pasos-coa-rzvq
source: "encargo 2026-11-20-primeros-pasos-paso-7-sheet-coach-tips-y-prueba-maquetas"
---

# Maquetas: paso 7, hoja de los 7 pasos, coach tips de Ajustes y Pro, y prueba de un mes

Sesión de maquetas: no cambia código de la app. Entrega: artifact «Primeros pasos: cuatro decisiones»
(https://claude.ai/artifact/ANdsF3Pb48ajkr27C1HGRG, privado: la organización no permite compartir con enlace) y su copia en
`docs/maquetas/primeros-pasos-paso-7-y-prueba/` (HTML + 15 capturas del antes).

## Qué decide Jürgen (con la recomendación)

1. **Paso 7.** A vitrina de atajos · **B historias con ejemplo y beneficio (recomendada)** · C el flujo de hoy con ejemplo entre medias.
2. **Hoja «Ver los 7 pasos».** A quitarla · **B progreso dentro del mazo (recomendada)** · C hoja corta con estados.
3. **Coach tips.** A quitar los dos · **B quitar el de Ajustes y enseñar Pro en «¡Listo! Tienes Pro» (recomendada)** · C mantenerlos más suaves.
4. **Prueba de un mes.** A paso 7 como hoy sin cortes · **B al terminar «Aprender a registrar» (recomendada)** · C primer candado Pro tras la cortesía. Incluye maqueta de la hoja.

Las elecciones se guardan en la base del artifact (colección `decisiones`, un documento por tema: `paso7`, `hoja`, `tips`, `prueba`).

## Medido

- Simulador iPhone 17 Pro, iOS 27.2, build Debug-Dev de la rama 2.3, con `-uitest-show-setup-deck -uitest-setup-deck-at 7 -uitest-fake-prices eligible`.
- La oferta del final (`SetupCompleteTrialOfferSheet`) **sí sale** al cerrar el paso 7 recorrido de punta a punta.
- En la hoja de los 7 pasos, un paso omitido se pinta igual que uno pendiente.
- Los tours de Ajustes y Pro no se pueden capturar: están apagados con `-uitest` y sin él la app pide la bienvenida completa; en el artifact van recreados sobre capturas reales.

## Siguiente

Cuando Jürgen elija, un encargo por tema. Por qué no sale la oferta: `tickets/backlog/2026-11-20-oferta-de-un-mes-se-cae-en-silencio.md`.
