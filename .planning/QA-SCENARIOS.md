# QA Scenarios - Neto V1.0

Documento de escenarios de prueba manual para validación pre-release.

---

## 1. Transacciones

### Escenario: Crear gasto simple
**Precondiciones:** Al menos 1 cuenta y 1 categoría existentes
**Pasos:**
1. Tap en botón "+" flotante
2. Ingresar monto (ej: 50.00)
3. Seleccionar categoría y subcategoría
4. Agregar nota opcional
5. Tap en "Guardar"
**Resultado esperado:** Transacción aparece en Records, balance de cuenta se actualiza
**Casos edge:**
- Monto con decimales largos (50.123456)
- Monto muy grande (999,999,999)
- Nota con caracteres especiales y emojis

### Escenario: Crear ingreso
**Precondiciones:** Categoría de ingreso existente
**Pasos:**
1. Tap en "+" → cambiar a tipo Ingreso
2. Ingresar monto positivo
3. Seleccionar categoría de ingreso
4. Guardar
**Resultado esperado:** Transacción con monto positivo, balance aumenta

### Escenario: Crear transferencia entre cuentas
**Precondiciones:** Al menos 2 cuentas existentes
**Pasos:**
1. Tap en "+" → seleccionar Transferencia
2. Seleccionar cuenta origen y destino
3. Ingresar monto
4. Si monedas diferentes, verificar tipo de cambio
5. Guardar
**Resultado esperado:** Dos transacciones creadas (salida y entrada), balances actualizados
**Casos edge:**
- Transferencia entre misma moneda
- Transferencia multimoneda (USD → PEN)
- Tipo de cambio manual vs automático

### Escenario: Editar transacción existente
**Precondiciones:** Al menos 1 transacción existente
**Pasos:**
1. Ir a Records → tap en transacción
2. Modificar monto, categoría o nota
3. Guardar cambios
**Resultado esperado:** Cambios reflejados, balance recalculado

### Escenario: Eliminar transacción
**Precondiciones:** Al menos 1 transacción existente
**Pasos:**
1. Ir a Records → swipe left en transacción
2. Confirmar eliminación
**Resultado esperado:** Transacción eliminada, balance actualizado

---

## 2. Cuentas

### Escenario: Crear cuenta nueva
**Precondiciones:** Ninguna
**Pasos:**
1. Ir a Profile → Cuentas → "+"
2. Ingresar nombre, seleccionar tipo, moneda y color
3. Ingresar saldo inicial (opcional)
4. Guardar
**Resultado esperado:** Cuenta aparece en lista y en Panel
**Casos edge:**
- Nombre muy largo
- Saldo inicial negativo
- Cuenta en moneda diferente a preferida

### Escenario: Editar cuenta
**Precondiciones:** Al menos 1 cuenta existente
**Pasos:**
1. Profile → Cuentas → tap en cuenta
2. Modificar nombre, tipo o color
3. Guardar
**Resultado esperado:** Cambios reflejados en toda la app

### Escenario: Ocultar cuenta
**Precondiciones:** Al menos 2 cuentas (no se puede ocultar la única)
**Pasos:**
1. Profile → Cuentas → tap en cuenta
2. Toggle "Visible" a off
3. Guardar
**Resultado esperado:** Cuenta no aparece en selectores pero mantiene transacciones

### Escenario: Reordenar cuentas
**Precondiciones:** Al menos 2 cuentas
**Pasos:**
1. Profile → Cuentas → Editar
2. Arrastrar cuentas para reordenar
3. Confirmar
**Resultado esperado:** Nuevo orden respetado en Panel y selectores

---

## 3. Categorías

### Escenario: Crear categoría
**Precondiciones:** Ninguna
**Pasos:**
1. Profile → Categorías → "+"
2. Ingresar nombre, seleccionar color e icono
3. Marcar si es ingreso o gasto
4. Agregar subcategorías
5. Guardar
**Resultado esperado:** Categoría disponible en selector de transacciones

### Escenario: Editar categoría
**Precondiciones:** Categoría existente con transacciones
**Pasos:**
1. Profile → Categorías → tap en categoría
2. Cambiar nombre, color o icono
3. Guardar
**Resultado esperado:** Cambios reflejados en transacciones existentes

### Escenario: Eliminar subcategoría con transacciones
**Precondiciones:** Subcategoría con transacciones asociadas
**Pasos:**
1. Profile → Categorías → tap en categoría → tap en subcategoría
2. Eliminar subcategoría
3. Elegir: transferir transacciones o eliminarlas
**Resultado esperado:** Transacciones transferidas o eliminadas según elección
**Casos edge:**
- Transferir a "Sin asignar"
- Transferir a otra subcategoría existente

### Escenario: Cambiar naturaleza de subcategoría
**Precondiciones:** Subcategoría existente
**Pasos:**
1. Editar subcategoría
2. Cambiar naturaleza (Esencial/Prioritaria/Opcional/Sin clasificar)
3. Guardar
**Resultado esperado:** Cambio reflejado en widget de naturalezas

---

## 4. Presupuestos

### Escenario: Crear presupuesto mensual
**Precondiciones:** Al menos 1 categoría de gasto
**Pasos:**
1. Planning → Presupuestos → "+"
2. Seleccionar categorías a incluir
3. Definir monto límite
4. Seleccionar periodo (mensual)
5. Guardar
**Resultado esperado:** Presupuesto activo, widget muestra progreso

### Escenario: Ver progreso de presupuesto
**Precondiciones:** Presupuesto activo con gastos
**Pasos:**
1. Ir a Planning → Presupuestos
2. Ver barra de progreso
3. Verificar porcentaje vs monto gastado
**Resultado esperado:** Progreso correcto, colores según umbral (verde/amarillo/rojo)

### Escenario: Presupuesto excedido
**Precondiciones:** Presupuesto con límite bajo
**Pasos:**
1. Crear gasto que exceda el límite
2. Ver presupuesto
**Resultado esperado:** Barra en rojo, porcentaje > 100%

---

## 5. Filtros

### Escenario: Filtrar por periodo personalizado
**Precondiciones:** Transacciones en diferentes fechas
**Pasos:**
1. En Statistics o Records, tap en selector de periodo
2. Seleccionar "Personalizado"
3. Elegir fecha inicio y fin
4. Aplicar
**Resultado esperado:** Solo transacciones en rango seleccionado

### Escenario: Filtrar por múltiples categorías
**Precondiciones:** Transacciones en varias categorías
**Pasos:**
1. Abrir filtros
2. Seleccionar 2+ categorías
3. Aplicar
**Resultado esperado:** Solo transacciones de categorías seleccionadas, gráficas actualizadas

### Escenario: Filtrar por cuenta
**Precondiciones:** Transacciones en múltiples cuentas
**Pasos:**
1. Abrir filtros → Cuentas
2. Seleccionar cuenta específica
3. Aplicar
**Resultado esperado:** Solo transacciones de cuenta seleccionada

### Escenario: Filtrar por etiqueta
**Precondiciones:** Transacciones con etiquetas
**Pasos:**
1. Abrir filtros → Etiquetas
2. Seleccionar etiqueta
3. Aplicar
**Resultado esperado:** Solo transacciones con etiqueta seleccionada

### Escenario: Limpiar todos los filtros
**Precondiciones:** Filtros activos
**Pasos:**
1. Tap en "Limpiar filtros"
**Resultado esperado:** Todos los filtros reseteados, vista completa

---

## 6. Estadísticas

### Escenario: Ver tendencia de gastos
**Precondiciones:** Transacciones en múltiples meses
**Pasos:**
1. Ir a Statistics → Trends
2. Verificar gráfica de línea
3. Cambiar periodo (mes/año)
**Resultado esperado:** Gráfica muestra tendencia correcta, tooltip con detalles

### Escenario: Ver distribución por categorías
**Precondiciones:** Gastos en múltiples categorías
**Pasos:**
1. Ir a Statistics → Categories
2. Ver pie chart
3. Tap en segmento para filtrar
**Resultado esperado:** Porcentajes correctos, filtro aplicado al hacer tap

### Escenario: Comparar periodos
**Precondiciones:** Datos en periodo actual y anterior
**Pasos:**
1. Activar modo comparación (M o A)
2. Ver variación porcentual
**Resultado esperado:** Chips muestran +/- % vs periodo anterior

### Escenario: Ver ingresos vs gastos (Cash Flow)
**Precondiciones:** Ingresos y gastos en el periodo
**Pasos:**
1. Ver widget Cash Flow en Panel
2. Verificar balance neto
**Resultado esperado:** Ingreso - Gasto = Balance mostrado

---

## 7. Panel

### Escenario: Ver resumen de cuentas
**Precondiciones:** Múltiples cuentas con saldos
**Pasos:**
1. Ir a Panel
2. Ver carrusel de cuentas
3. Verificar saldos individuales y total
**Resultado esperado:** Saldos correctos, total suma todos

### Escenario: Navegar desde widget a detalle
**Precondiciones:** Widgets configurados
**Pasos:**
1. Tap en chevron de widget (ej: Top Categorías)
2. Verificar navegación a vista detallada
**Resultado esperado:** Navega a Statistics con contexto correcto

### Escenario: Configurar widgets visibles
**Precondiciones:** Ninguna
**Pasos:**
1. Panel → icono engranaje
2. Toggle widgets on/off
3. Reordenar widgets
4. Guardar
**Resultado esperado:** Solo widgets seleccionados visibles, en orden elegido

---

## 8. Pagos Planificados

### Escenario: Crear suscripción recurrente
**Precondiciones:** Cuenta y categoría existentes
**Pasos:**
1. Planning → Pagos → "+"
2. Seleccionar "Recurrente"
3. Configurar: monto, frecuencia (mensual), día de cobro
4. Seleccionar cuenta y categoría
5. Guardar
**Resultado esperado:** Pago aparece en lista y calendario

### Escenario: Ver calendario de pagos
**Precondiciones:** Pagos planificados existentes
**Pasos:**
1. Planning → Pagos → vista Calendario
2. Navegar entre meses
3. Ver días con pagos marcados
**Resultado esperado:** Días con pagos resaltados, detalle al hacer tap

### Escenario: Marcar pago como realizado
**Precondiciones:** Pago planificado próximo
**Pasos:**
1. Tap en pago → "Registrar pago"
2. Confirmar
**Resultado esperado:** Transacción creada, próxima fecha calculada

### Escenario: Pausar suscripción
**Precondiciones:** Suscripción activa
**Pasos:**
1. Editar suscripción → toggle "Activo" off
2. Guardar
**Resultado esperado:** No aparece en próximos pagos, mantiene historial

---

## 9. Importación

### Escenario: Importar CSV simple
**Precondiciones:** Archivo CSV con formato correcto
**Pasos:**
1. Profile → Importar → seleccionar archivo
2. Mapear columnas si es necesario
3. Seleccionar cuenta destino
4. Importar
**Resultado esperado:** Transacciones creadas, resumen de importación

### Escenario: Importar CSV multimoneda
**Precondiciones:** CSV con transacciones en diferentes monedas
**Pasos:**
1. Importar CSV
2. Sistema detecta múltiples monedas
3. Asignar cuenta por moneda
4. Importar
**Resultado esperado:** Transacciones en cuentas correctas según moneda

### Escenario: Manejar errores de importación
**Precondiciones:** CSV con filas inválidas
**Pasos:**
1. Intentar importar CSV con errores
2. Ver reporte de errores
**Resultado esperado:** Filas válidas importadas, errores reportados claramente
**Casos edge:**
- Fechas en formato incorrecto
- Montos no numéricos
- Categorías inexistentes

---

## 10. Configuración

### Escenario: Cambiar moneda preferida
**Precondiciones:** Transacciones existentes
**Pasos:**
1. Profile → Moneda → seleccionar nueva moneda
2. Confirmar cambio
**Resultado esperado:** Todos los montos convertidos, totales recalculados

### Escenario: Cambiar idioma
**Precondiciones:** Ninguna
**Pasos:**
1. Cambiar idioma del dispositivo (Settings iOS)
2. Reabrir app
**Resultado esperado:** Toda la UI en nuevo idioma

### Escenario: Exportar datos
**Precondiciones:** Transacciones existentes
**Pasos:**
1. Profile → Exportar
2. Configurar filtros y columnas
3. Generar CSV
4. Compartir/guardar archivo
**Resultado esperado:** CSV generado con datos correctos

### Escenario: Vaciar datos
**Precondiciones:** Datos existentes (backup recomendado)
**Pasos:**
1. Profile → Vaciar datos
2. Confirmar (doble confirmación)
**Resultado esperado:** Todos los datos eliminados, categorías semilla restauradas

---

## Casos Edge Prioritarios

### App con 0 datos (Empty States)
- [ ] Panel muestra mensaje de bienvenida
- [ ] Records muestra "No hay transacciones"
- [ ] Statistics muestra gráficas vacías con mensaje
- [ ] Presupuestos invita a crear primero

### App con muchos datos (1000+ transacciones)
- [ ] Scroll fluido en Records
- [ ] Gráficas cargan sin lag
- [ ] Filtros responden rápido
- [ ] Búsqueda funciona correctamente

### Valores extremos
- [ ] Monto 0.01 (mínimo práctico)
- [ ] Monto 999,999,999.99 (máximo)
- [ ] 100 transacciones en un día
- [ ] Categoría con 50 subcategorías

### Fechas límite
- [ ] Transacción en 1 de enero (inicio de año)
- [ ] Transacción en 31 de diciembre (fin de año)
- [ ] Transacción en 29 de febrero (año bisiesto)
- [ ] Cambio de mes durante uso de app

### Multimoneda
- [ ] 3+ cuentas en diferentes monedas
- [ ] Transferencia USD → EUR
- [ ] Tipo de cambio del día vs histórico
- [ ] Totales en moneda preferida correctos

### Recuperación de errores
- [ ] App cerrada durante guardado → datos no corruptos
- [ ] Sin conexión → funcionalidad offline completa
- [ ] Poco espacio en disco → mensaje claro

---

## Checklist Pre-Release

- [ ] Todos los escenarios principales probados
- [ ] Empty states verificados
- [ ] Performance con datos reales aceptable
- [ ] Todos los idiomas verificados (al menos 2)
- [ ] Todas las monedas funcionan correctamente
- [ ] Sin crashes en flujos principales
- [ ] Datos persisten correctamente entre sesiones

---

*Documento creado: 2026-01-20*
*Última actualización: 2026-01-20*
