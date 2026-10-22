# Capturas del simulador para la web — 2026-09-04

PNG nativos (1206×2622) del iPhone 17 Pro, scheme **Yala Dev**, apariencia oscura, Pro activado,
barra de estado fijada a 9:41. Semilla `DevSeedService` perfil **grupos** (determinista, `SeededRandom(42)`),
usuario **Camila**, período **Últimos 30 días**.

Los JPEG que sirve la web (620 px de ancho) están en `public/images/screenshots/v3/`.

| Fichero | Pantalla | Se usa en |
|---|---|---|
| `panel-hero-{es,en}.png` | Panel principal | Hero |
| `nuevo-registro-{es,en}.png` | Nuevo registro: «Taxi al aeropuerto» · S/ 18.50 · Transporte · Cuenta Principal | Anota |
| `stats-resumen-{es,en}.png` | Estadísticas › Resumen | Entiende |
| `grupos-lista-{es,en}.png` | Lista de grupos | (no usada hoy) |
| `grupos-balances-{es,en}.png` | Viaje a Cusco › Balances (ES) / Gastos (EN) | Comparte |

## Cifras que el copy de la web repite (medidas aquí, no inventadas)

- Salud financiera **95** de 100 · Ritmo 100 · Compromisos 91 · Presupuestos «—» (la semilla no deja
  presupuestos activos en el período; ya salía así en el set anterior).
- **27 movimientos** en 30 días · gastos **S/ 2,063** · ingresos S/ 8,500 · disponible S/ 6,437.
- Promedio diario **S/ 66.55** · categoría principal Alimentación **S/ 1,175 (56 %)** · mayor gasto
  **S/ 192** en Mercado.
- Grupo «Viaje a Cusco» (Camila, Ana, Beto), deudas ya simplificadas: Beto→Ana S/ 30, Ana→Camila S/ 80,
  Beto→Camila S/ 110.

## Dos cosas medidas que corrigieron el copy

1. **El Panel ya no saluda por nombre.** La clave `panel.greeting` («Hola, %@») existe en `L10n` pero
   **ningún** view la usa: la captura anterior de la web venía de una versión previa. El alt del hero se
   escribió sin el saludo.
2. **El formulario de nuevo registro NO interpreta lenguaje natural libre.** Se comprobó escribiendo
   «Taxi al aeropuerto» en la descripción: el monto se queda en 0.00. Lo que ofrece es
   `@cuenta !categoría #etiqueta`. El lenguaje libre («registra 24 soles de pizza») es de **Yala IA** y
   de **voz**, ambas Pro. El copy de «Escríbelo» y la nota del hero se reescribieron por eso.

## En inglés, dos límites conocidos

- Los **nombres de los gastos del grupo** («Souvenirs», «Mercado», «Almuerzo criollo») y el nombre del
  grupo son datos de la semilla, en español. Son datos de usuario, no interfaz: un viaje a Cusco.
- La captura de grupo en EN usa la pestaña **Gastos** en vez de **Balances**: en Balances el miembro
  actual sale como «Tú» (lo escribe la semilla) y el nombre del perfil no se propaga a esa fila sin
  volver a sembrar. La de Gastos está íntegramente en inglés («You paid», «Ana paid») y cuenta lo mismo.
