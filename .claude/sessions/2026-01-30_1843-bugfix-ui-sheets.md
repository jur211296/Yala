# Session Started: 2026-01-30 18:43

## Context
- Mac: jur
- Phase: V1.1 → V1.2 (bugs encontrados en V1.1)
- Recent commits:
  - ac64dfd docs(state): mark audit as closed and prepare for Phase 11 (V1.2)
  - 05a8c3f docs(roadmap): mark Phase 10 as completed
  - b729fa1 docs(roadmap): mark Phase 10 as completed

## Goal
Resolver 2 bugs de UI en V1.1 antes de comenzar Fase 11

### Bug 1: Tema no se aplica en sheets de Perfil
Al cambiar tema (Sistema/Claro/Oscuro) desde Perfil, los sheets abiertos no reflejan el cambio inmediatamente. Se requiere salir hasta Panel para aplicación completa.

Solución: Implementar la opción más robusta entre:
- a) Aplicar inmediatamente a toda la app (incluyendo sheets activos)
- b) Cerrar sheets de Perfil → aplicar cambio

### Bug 2: Background incorrecto en sheets (dark mode)
Algunas sheets usan background negro en vez de `Color.yalaCard` en dark mode.

Casos identificados:
- Tipo de cuenta (creación de cuenta)
- Selección de ajuste (edición de cuenta)

Alcance: Auditar TODO el proyecto para casos similares (dark + light mode)

## Plan
1. Investigar y resolver Bug 1 (tema en sheets de Perfil)
   - Revisar cómo se aplica `preferredColorScheme` actualmente
   - Implementar solución robusta
   - Verificar que funciona en todos los casos

2. Auditoría de backgrounds en sheets
   - Buscar todas las sheets con `.background()` o `.presentationBackground()`
   - Identificar casos con colores incorrectos
   - Crear lista completa de archivos a corregir

3. Corregir backgrounds identificados
   - Aplicar `Color.yalaCard` donde corresponda
   - Verificar en dark y light mode
   - Actualizar QA-SCENARIOS.md

## Timeline
- 18:43 - Sesión iniciada
- Plan de 3 incrementos definido

## Outcomes
(Se llenará con /session-end)
