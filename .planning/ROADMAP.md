# Roadmap: Yala

## Overview

App iOS de finanzas personales. Registrar y entender gastos, cuentas, presupuestos y reportes con claridad.

## Domain Expertise

- ./.claude/skills/expertise/iphone-apps/SKILL.md (si existe)

## Versiones

### V1.0 — Release inicial ✅
Features completas + App Store. Branch: `1.0`

### V1.1 — Registro inteligente y plataforma ✅
Registro con IA, iCloud Sync, Widgets iOS, modo Solo Gastos, modelo Pro/Free, temas PRO, Smart Insights, iPad/Mac, telemetría, sistema de conversión Pro.

### V1.2 — Reportes financieros y mejoras (en desarrollo)
Reportes Financieros (Comparativa + Flujo de Caja), mejoras de producción identificadas en V1.1.1.

### V1.3 — Predicciones y proyecciones
Predicción de saldo, proyección de presupuesto, correcciones de V1.2.

### V2.0 — Social y asistente IA
Funcionalidad compartida tipo Splitwise, asistente IA con preguntas.

### V2.1 — IA avanzada y visualizadores
Recomendación de presupuestos con IA, visualizador de ahorros, visualizador de deudas, notificaciones smart con IA (PRO).

### V2.2 — Reportes exportables PRO
Resúmenes PDF y Excel, solo para PRO.

### V3.0+ — Multiplataforma
Apple Watch, iPadOS nativo, macOS nativo, base de datos multiplataforma para web, Android.

---

## Detalle por Versión

### V1.2 — Reportes financieros y mejoras

**Producción:** V1.1.1
**Branch:** `1.2`
**Status:** En desarrollo

**Prioridad (en orden):**

1. **Reportes Financieros > Comparativa** — Vista avanzada, bien avanzada, falta refinar detalles
2. **Reportes Financieros > Flujo de Caja** — Vista avanzada, bien avanzada, falta refinar MUCHOS detalles
3. **Cambios ya realizados en 1.2** — Temas PRO, Smart Insights, iPad/Mac, filtros avanzados, telemetría, Cash Flow Plan, sistema conversión Pro, etc.
4. **Mejoras de producción:**
   - [ ] Limitar exportación de datos: solo algunos periodos Free, los demás PRO
   - [ ] Onboarding cuenta: teclado tapa todo al escribir nombre, no permitir saldo inicial 0 como default (forzar calculadora)
   - [ ] Onboarding cuenta: paso/banner/popup adicional explicativo (los usuarios siguen sin entenderlo)
   - [ ] Bug widget TopSubcategories en PanelView: % de participación incorrecto (investigar a detalle)
   - [ ] Notificaciones presupuesto: si se superan varios límites en una transacción, solo enviar el máximo (no todos)
   - [ ] Permitir adelantar un pago planificado

---

### V1.3 — Predicciones y proyecciones

1. [ ] Predicción de saldo en gráfica de tendencias
2. [ ] Proyección de presupuesto (ritmo de gasto, línea proyectada, alertas)
3. [ ] Correcciones y mejoras identificadas en producción de V1.2

---

### V2.0 — Social y asistente IA

1. [ ] Funcionalidad compartida tipo Splitwise (gastos compartidos, deudas, grupos)
2. [ ] Asistente IA con preguntas (chat interactivo sobre finanzas)
3. [ ] Correcciones y mejoras identificadas en producción de V1.3

---

### V2.1 — IA avanzada y visualizadores

1. [ ] Recomendación de presupuestos con IA
2. [ ] Visualizador de ahorros (metas amarradas a cuentas de ahorro)
3. [ ] Visualizador de deudas
4. [ ] Notificaciones smart con IA para PRO

---

### V2.2 — Reportes exportables PRO

1. [ ] Resúmenes PDF o Excel, solo para PRO

---

### V3.0+ — Multiplataforma

1. [ ] Apple Watch (registro rápido, balance, widgets)
2. [ ] iPadOS nativo (layouts dedicados, sidebar)
3. [ ] macOS nativo
4. [ ] Base de datos multiplataforma para versión web
5. [ ] Android

---

## Historial de versiones completadas

### V1.0 (2026-01-27)
- Estabilidad Core, filtros, gestión categorías, panel, visualizaciones
- Pagos planificados, beta preparation, acciones rápidas, settings, onboarding
- App Store release con 6 idiomas

### V1.1 (2026-02-13)
- Registro inteligente (voz + imagen + merchant memory)
- iCloud Sync, Widgets iOS, Control Center
- Modo Solo Gastos, sistema Pro/Free, animaciones y haptics
- Notificaciones personalizadas, deep scan pre-launch
- 21 items UAT resueltos, auditoría completa

### V1.1.1 (2026-03-05) — Producción actual
- Sistema de temas independientes (6 temas: 3 free + 3 PRO)
- Smart Insights (rule-based + LLM Pro)
- iPad/Mac layouts adaptados
- Filtros avanzados (excluir/incluir), línea promedio en gráficas
- Siri registro rápido, Lock Screen widgets
- Telemetría privacy-first, sistema de conversión Pro
- Cash Flow Plan, onboarding refinado
- 56+ bugs de producción resueltos

---

*Actualizar conforme se completen versiones*
