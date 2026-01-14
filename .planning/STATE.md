# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 1 — Estabilidad Core

## Current Position

Phase: 1 of 8 (Estabilidad Core)
Plan: In progress
Status: Working on bugs
Last activity: 2026-01-13 — Fix bug de etiquetas (many-to-many relationship)

Progress: ██░░░░░░░░ 15%

## Completed

- Refactor: Saldo inicial ahora es transacción (no propiedad de Account)
- Fix: Gráficas de tendencia se actualizan al cambiar saldo inicial
- Fix: SwiftData @Query detecta cambios en transacciones de saldo
- Fix: Bug de etiquetas — múltiples transacciones pueden tener la misma etiqueta (many-to-many)

## Next (Fase 1)

- CRITICO: Los puntos de las graficas de tendencia de saldo NO cuadran con el acumulado de transacciones. He hecho pruebas con datos sencillos: Sin saldo inicial, solo transacciones, solo una cuenta, solo una divisa, sin ajustes, una unica importacion. El valor del saldo en la tarjeta de la cuenta es correcto. El valor del flujo en cashflow es igual al de la tarjeta de la cuenta, correcto. El saldo en RecordsTabView es igual al de la tarjeta de la cuenta, correcto. Pero la grafica de Trends (en PanelView y TrendsTabView) SOLO en la parte de saldo, no cuadra. En ingresos y gastos si cuadra. Pero en Saldo NO cuadra, es mas alto. También he ido revisando punto por punto con el hover de la grafica y no cuadra con las transacciones una a una. Creo que el problema puede estar en la importación. 
Este fue el CSV importado:
date,amount,currency,category,subcategory,tags,note
2025-01-31,-0.8,EUR,Alimentación,Supermercados y bodegas,,Chino
2025-01-26,-1.29,EUR,Entretenimiento,Hobbies y gaming,,Weltita tono
2025-01-24,-0.24,EUR,Finanzas,Comisiones y cargos,,Banco
2025-01-23,-14,EUR,Alimentación,Delivery,,Hundreds
2025-01-21,20,EUR,Ingresos,Ayudas y subvenciones,,Préstamo Luismi
2025-01-20,-11.35,EUR,Alimentación,Restaurantes,,Comida
2025-01-19,-12,EUR,Alimentación,Restaurantes,,Poke
2025-01-19,-5,EUR,Personal,Telefonía y comunicaciones,,Orange
2025-01-18,-39,EUR,Alimentación,Restaurantes,,Sidrería
2025-01-17,-2.99,EUR,Personal,Suscripciones de utilidad,,Google Photos
2025-01-17,-11.99,EUR,Personal,Suscripciones de utilidad,,Apple Care
2025-01-17,-5.99,EUR,Personal,Suscripciones de utilidad,,Oura Ring
2025-01-16,-12.5,EUR,Alimentación,Delivery,,Hundred
2025-01-16,-1.27,EUR,Alimentación,Supermercados y bodegas,,Carrefour
2025-01-13,-70,EUR,Personal,Asesorías y trámites,,Toma de huellas
2025-01-12,-13.06,EUR,Personal,Suscripciones de utilidad,,ExpressVPN
2025-01-12,-13.99,EUR,Compras,Tecnología y accesorios,,Correa Apple Watch
2025-01-12,-14.95,EUR,Transporte,Taxis y apps,,Bolt
2025-01-12,-16.11,EUR,Alimentación,Restaurantes,,BK
2025-01-11,-51.35,EUR,Entretenimiento,Fiestas y vida nocturna,,Ponzano
2025-01-11,-10,EUR,Entretenimiento,Fiestas y vida nocturna,,Aiara cerveza
2025-01-11,-0.8,EUR,Alimentación,Supermercados y bodegas,,Chino
2025-01-11,-43.68,EUR,Alimentación,Supermercados y bodegas,,Mercadona
2025-01-10,-15.5,EUR,Alimentación,Restaurantes,,IMA
2025-01-10,-33.79,EUR,Entretenimiento,Hobbies y gaming,,Juegos de mesa
2025-01-10,-49.98,EUR,Compras,Cuidado personal y belleza,,Oral B
2025-01-10,-5.08,EUR,Alimentación,Supermercados y bodegas,,Carrefour
2025-01-10,-21.5,EUR,Entretenimiento,Viajes y vacaciones,,Bus Alsa a Sanse
2025-01-09,-17.9,EUR,Personal,Belleza y estética,,Peluquería
2025-01-08,-75.83,EUR,Compras,Ropa y calzado,,Zara
2025-01-08,-29,EUR,Compras,Tecnología y accesorios,,Arreglo iPhone
2025-01-08,-24.1,EUR,Compras,Cuidado personal y belleza,,Primor
2025-01-08,-76.05,EUR,Compras,Ropa y calzado,,Zara
2025-01-07,-13,EUR,Compras,Ropa y calzado,,Primark
2025-01-07,-151.09,EUR,Personal,Fitness y actividad física,,MyProtein
2025-01-07,-9.99,EUR,Entretenimiento,Streaming y plataformas,,DAZN
2025-01-07,-4.99,EUR,Entretenimiento,Streaming y plataformas,,Prime Video
2025-01-07,-16.5,EUR,Alimentación,Restaurantes,,Vips
2025-01-07,-59.78,EUR,Alimentación,Supermercados y bodegas,,Mercadona
2025-01-06,-21.8,EUR,Transporte,Transporte público,,Metro
2025-01-06,-15,EUR,Personal,Telefonía y comunicaciones,,Orange
2025-01-01,-3.49,EUR,Personal,Suscripciones de utilidad,,Hevy mensual
- Bug: Hover CashFlow en Panel/Trends muestra colores incorrectos. Bug: Actualmente el hover muestra puntitos de colores que no son los colores de las barras/lineas. Añadir: leyenda debajo porque no está claro que el teal es ingreso, rosa egreso y morado saldo. Simple, similar a la de naturalezas. Esto en ambos lugares. Bug: El título siempre dice Flujo neto. Para PanelView esta bien, pero en TrendsTabView hay otros matices: Ahi tenemos un selector para ver un CashFlow por cada cuenta o por cada Moneda, entonces en lugar de Flujo neto deberia decir el nombre de la cuenta o el nombre de la moneda (nombre completo: dólar estadounidense, no diminutivo).

## Risk/Notes

- SwiftData @Query no detecta modificaciones in-place; usar delete+insert
- Cadenas largas de .onChange pueden exceder límite del compilador; extraer a ViewModifiers
- Saldo inicial usa `balanceAdjustmentType = "initial_balance"` en TransactionItem
- Categoría seed "Otros/Ajustes de saldo" para transacciones de ajuste
- Tag ↔ TransactionItem require `@Relationship(inverse:)` para many-to-many correcto

## Session Continuity

Last session: 2026-01-13 17:19
Stopped at: Tag bug fixed, 2 bugs pendientes en Fase 1
Resume file: None
