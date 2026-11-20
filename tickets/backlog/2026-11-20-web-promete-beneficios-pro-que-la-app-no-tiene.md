---
id: 2026-11-20-web-promete-beneficios-pro-que-la-app-no-tiene
status: backlog
priority: medium
area: "web, pro"
created: 2026-11-20
updated: 2026-11-20
source: "encargo 2026-11-20-oferta-pro-final-primeros-pasos-mas-beneficios-maquetas"
---

# La web promete beneficios de Pro que la app no tiene

Encontrado al levantar la lista real de beneficios Pro para la oferta de Primeros pasos (2026-11-20).

`Web/src/i18n/translations.ts` (bloque `pricingPro*`, español) anuncia en Yala Pro:

- `pricingPro4` «Reportes avanzados»
- `pricingPro5` «Acceso adelantado a nuevas funciones»
- `pricingPro6` «Iconos premium + soporte prioritario» (los iconos sí existen; el soporte prioritario, no)

Ninguno es una puerta de `FeatureGateService.ProFeature` (las ocho reales: voz, foto/PDF, Yala IA, resúmenes con IA,
cuentas, presupuestos, temas Pro, iconos premium). Además la tarjeta de precios no nombra los temas Pro (la sección
de Yala IA sí cubre el análisis del mes, `yalaaiBullet3`).

Medido: `grep -n "pricingPro" Web/src/i18n/translations.ts` en la rama 2.3 del 2026-11-20. No se comprobó si la ficha de
la App Store (territorio de Lola) dice lo mismo.

## Qué hacer

Decidir con Jürgen si se quitan o si alguno es una promesa real de producto. Un cambio en `Web/` que deba verse ya es
un hotfix sobre `1.0` (`docs/FLUJO-RAMAS-Y-HOTFIX.md`).
