---
id: 2026-11-25-primeros-pasos-cada-paso-cuenta-bien
status: done
priority: high
area: "primeros-pasos, onboarding, panel, pagos-planificados, nuevo-registro"
created: 2026-11-25
updated: 2026-11-25
source: "encargo 2026-11-25-primeros-pasos-cada-paso-cuenta-bien (lote 1 de la observación del iPhone 14)"
---

# Primeros pasos: que cada paso cuente bien

Primer lote de la prueba en vivo del iPhone 14 del 25-nov (`docs/qa/observacion-iphone14-2026-11-25/bitacora.md`).
Pasos hechos que salían «para después», un paso dado por hecho sin estarlo y un pago que «desaparecía».

## Qué cambia para quien usa Yala

1. **«Solo gastos» se hace de cero** (decisión de Jürgen, 25-nov 17:19; revierte la del 19-nov). El alta ya no crea
   «Gastos <moneda>»: Primeros pasos arranca en 1 de 7 y la persona crea su cuenta, como con «Ingresos y gastos». Sin la
   línea «Tus gastos van a…». La cuenta y el saldo grande salen al hacer el paso 1 en los dos modos. Las cuentas ya
   creadas así no se tocan.
2. **La guía del primer registro** ya no se salta «Tu cuenta ya está puesta» con una cuenta de soles y dólares: cuenta
   las cuentas que la persona ve (sin archivadas, de sistema ni líneas de otra moneda), no las filas.
3. **El widget de Pagos planificados** enseña el próximo vencimiento aunque caiga el mes que viene (opción 1 de Jürgen):
   la lista de próximos lo suma, el widget pequeño dice «Próximo pago · nombre · fecha» en vez de «Sin pagos próximos»
   y la ficha «Con tus datos» lo nombra. Lo de «este mes» (total, anillo, por pagar) no cambia.
4. **Paso 7:** pasar las historias hasta «Terminar» deja el paso hecho, aunque no se abra ningún «Enséñame cómo».
5. **Grupos (paso 5):** ver la intro basta; «Ahora no», crear o unirse lo dejan hecho. El aviso «Grupos ya lo conoces: lo
   viste al entrar» pasa a «Ya conoces Grupos. Seguimos con el paso 6.» en los 16 idiomas.

## Pruebas

- `YalaTests/PrimerosPasosCuentaBien/` (5 suites, una por arreglo) y las que cambiaron por la decisión nueva de «Solo
  gastos» (`SoloGastosPrimerosPasos`, `PanelProgresivo`, `NovedadesPanelNota`, `Bienvenida23Alta`, `Bienvenida23Final`,
  `Bienvenida23PasosPlanificacion`), cada una diciendo por qué.
- `YalaUITests/PrimerosPasosCuentaBien/PrimerosPasosCuentaBienUITests`: paso 4 con un pago que vence el mes que viene,
  paso 5 con «Ahora no», paso 7 hasta «Terminar».

## Fuera

- Guías de lugar, gesto de las historias, aviso «viven en Más», paso 6 e intro de Grupos tras cerrar sesión: lote 2.
- Textos de pulido: lote 3. Oferta Pro y mazo centrado: esperan maqueta.
- El alta antigua de «Activar Yala completo» (`OnboardingView`) no se tocó.
