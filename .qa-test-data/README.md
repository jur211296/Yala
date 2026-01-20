# CSV de Prueba para QA - Neto iOS

Este directorio contiene archivos CSV para testing manual y automatizado de la funcionalidad de importación.

## Formato CSV Esperado

**Encabezados válidos:**
- Básico: `date,amount,currency,category,subcategory`
- Con nota: `date,amount,currency,category,subcategory,note`
- Con tags: `date,amount,currency,category,subcategory,tags`
- Completo: `date,amount,currency,category,subcategory,tags,note`

**Reglas:**
- Montos positivos = Ingresos
- Montos negativos = Gastos
- Tags separados por `;` (punto y coma)
- Formatos de fecha soportados: `yyyy-MM-dd`, `dd/MM/yyyy`, `dd/MM/yy`

---

## Archivos Disponibles

### 1. `test_basic_pen.csv`
**Propósito:** Test básico de importación en soles
- 10 transacciones
- Solo moneda PEN
- Categorías seed estándar
- **Uso:** Verificar flujo básico de importación

### 2. `test_basic_usd.csv`
**Propósito:** Test básico de importación en dólares
- 8 transacciones
- Solo moneda USD
- Requiere cuenta en USD
- **Uso:** Verificar importación en moneda alternativa

### 3. `test_multicurrency.csv`
**Propósito:** Test de importación multimoneda
- 12 transacciones
- Mezcla PEN y USD
- Requiere cuentas en ambas monedas
- **Uso:** Verificar flujo de mapeo de monedas a cuentas

### 4. `screenshot_data_pen.csv` ⭐
**Propósito:** Datos realistas para screenshots del App Store
- 38 transacciones (enero 2026)
- Distribución variada de categorías
- Incluye tags y notas descriptivas
- Montos realistas para mercado peruano
- **Uso:** Generar datos atractivos para capturas oficiales

**Distribución de gastos:**
- Alimentación: ~25%
- Hogar: ~15%
- Entretenimiento: ~15%
- Personal: ~15%
- Compras: ~12%
- Transporte: ~8%
- Otros: ~10%

**Ingresos incluidos:**
- Salario: S/ 4,500
- Freelance: S/ 850
- Alquiler: S/ 1,200
- Reembolso: S/ 300

### 5. `test_errors.csv`
**Propósito:** Validar manejo de errores de importación
- 7 filas (1 válida, 6 con errores)
- **Errores incluidos:**
  - Fecha inválida
  - Monto no numérico
  - Moneda inválida (XXX)
  - Categoría vacía
  - Subcategoría vacía
  - Categoría inexistente
- **Uso:** Verificar mensajes de error y aborto de importación

### 6. `test_edge_cases.csv`
**Propósito:** Casos límite y formatos especiales
- 12 transacciones con casos edge
- **Casos incluidos:**
  - Monto mínimo (0.01)
  - Monto máximo (999,999.99)
  - Caracteres especiales en nota
  - Emojis en nota
  - Nota muy larga (>100 chars)
  - Múltiples formatos de fecha
  - Año bisiesto (29/02)
  - Fin/inicio de año
- **Uso:** Verificar robustez del parser

### 7. `test_large_dataset.csv`
**Propósito:** Test de performance
- 150 transacciones
- Span: noviembre 2025 - enero 2026
- Distribución realista de categorías
- **Uso:** Verificar rendimiento con muchos datos

---

## Cómo Usar

### Para Testing Manual:
1. Copiar el CSV deseado a iCloud Drive o Files
2. En la app: Profile → Importar
3. Seleccionar archivo
4. Verificar mapeo de cuenta(s)
5. Importar

### Para Screenshots:
1. Vaciar datos de la app (Profile → Vaciar datos)
2. Completar onboarding con PEN como moneda
3. Crear cuenta "Efectivo" en PEN
4. Importar `screenshot_data_pen.csv`
5. Tomar capturas de Panel, Statistics, Records

### Para Testing de Errores:
1. Intentar importar `test_errors.csv`
2. Verificar que muestra error específico por fila
3. Confirmar que no se importa ninguna transacción

---

## Notas Importantes

- Los CSVs usan categorías seed de Neto 1.0
- Requieren que existan las categorías por defecto
- El toggle "Crear categorías" puede ignorar categorías inexistentes
- Verificar que las cuentas tengan la moneda correcta antes de importar
