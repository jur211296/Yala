# QA Scenarios - Neto V1.0

Documento exhaustivo de escenarios de prueba manual para validación pre-release.
Ordenado por dependencias de datos para ejecución secuencial.

---

## Sección 0: Orden de Ejecución y Dependencias

### Diagrama de Dependencias entre Entidades

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ONBOARDING                                   │
│                    (Configuración inicial)                           │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    CUENTAS      │ │   CATEGORÍAS    │ │      TAGS       │
│ (sin deps)      │ │ (sin deps)      │ │  (sin deps)     │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         │          ┌────────┴────────┐          │
         │          ▼                 │          │
         │   ┌─────────────────┐      │          │
         │   │ SUBCATEGORÍAS   │      │          │
         │   │(depende de Cat) │      │          │
         │   └────────┬────────┘      │          │
         │            │               │          │
         └────────────┼───────────────┘──────────┘
                      ▼
         ┌─────────────────────────────────────┐
         │          TRANSACCIONES              │
         │  (depende de Cuenta + Subcategoría) │
         └─────────────────┬───────────────────┘
                           │
    ┌──────────────────────┼──────────────────────┐
    ▼                      ▼                      ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐
│ PRESUPUESTOS│    │   PAGOS     │    │     FAVORITOS       │
│(Cta+Sub+Tag)│    │ PROGRAMADOS │    │ (Cta+Sub+Tag, opt)  │
└──────┬──────┘    │(Cta+Sub+Tag)│    └─────────┬───────────┘
       │           └──────┬──────┘              │
       │                  │                     │
       └──────────────────┴─────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    PANEL    │    │ ESTADÍSTICAS│    │   FILTROS   │
│(visualiza)  │    │ (consume)   │    │  (opera)    │
└─────────────┘    └─────────────┘    └─────────────┘
```

### Orden Obligatorio para Testing Completo

| Orden | Módulo | Dependencias | Razón |
|-------|--------|--------------|-------|
| 1 | Onboarding | Ninguna | Configuración inicial de usuario |
| 2 | Cuentas | Ninguna | Necesarias para transacciones |
| 3 | Categorías | Ninguna | Contenedores de subcategorías |
| 4 | Subcategorías | Categorías | Necesarias para transacciones |
| 5 | Tags | Ninguna | Opcionales pero útiles para clasificar |
| 6 | Transacciones | Cuentas + Subcategorías | Core de la app |
| 7 | Presupuestos | Cuentas + Subcategorías + Tags | Dependen de filtros |
| 8 | Pagos Programados | Cuentas + Subcategorías + Tags | Generan transacciones |
| 9 | Favoritos | Cuentas + Subcategorías + Tags | Templates de transacción |
| 10 | Panel | Todo lo anterior | Visualiza datos |
| 11 | Estadísticas | Transacciones | Consume datos |
| 12 | Filtros | Todo | Opera sobre todo |
| 13 | Import/Export | Todo | Manipula datos |
| 14 | Settings | Independiente | Configuración |

---

## Sección 1: Onboarding (Primer Uso)

### Vista: OnboardingView

**Flujo completo de 4 pasos:**
1. Bienvenida + Nombre de usuario
2. Moneda principal
3. Monedas secundarias
4. Periodo por defecto

### Campos por Paso

**Paso 1 - Bienvenida:**
| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Nombre de usuario | TextField | No | Si vacío → "Usuario" |

**Paso 2 - Moneda principal:**
| Campo | Tipo | Obligatorio | Opciones |
|-------|------|-------------|----------|
| Moneda preferida | Single select | Sí | PEN, USD, EUR, MXN, COP, BRL, GBP |

**Paso 3 - Monedas secundarias:**
| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Monedas adicionales | Multi select | No | Máximo 2, excluye la principal |

**Paso 4 - Periodo por defecto:**
| Campo | Tipo | Obligatorio | Opciones |
|-------|------|-------------|----------|
| Periodo | Single select | Sí | thisWeek, last7Days, last30Days, thisMonth, lastMonth, thisYear, lastYear, allTime |

### Escenarios de Onboarding

#### Escenario 1.1: Completar onboarding mínimo
**Precondiciones:** App recién instalada o datos vaciados
**Pasos:**
1. Abrir app por primera vez
2. Verificar pantalla de bienvenida con icono 👋
3. Dejar nombre vacío
4. Tap "Siguiente"
5. Seleccionar moneda (default: PEN)
6. Tap "Siguiente"
7. No seleccionar monedas secundarias
8. Tap "Siguiente"
9. Seleccionar periodo (default: Este mes)
10. Tap "Finalizar"
**Resultado esperado:**
- [ ] Nombre guardado como "Usuario"
- [ ] Moneda PEN configurada
- [ ] Sin monedas secundarias
- [ ] Periodo "Este mes" activo
- [ ] Navega a Panel principal

#### Escenario 1.2: Completar onboarding completo
**Precondiciones:** App recién instalada
**Pasos:**
1. Ingresar nombre "Juan"
2. Tap "Siguiente"
3. Seleccionar USD como moneda principal
4. Tap "Siguiente"
5. Seleccionar EUR y GBP como secundarias
6. Tap "Siguiente"
7. Seleccionar "Últimos 30 días"
8. Tap "Finalizar"
**Resultado esperado:**
- [ ] Nombre "Juan" visible en Panel
- [ ] Moneda USD configurada
- [ ] EUR y GBP disponibles como secundarias
- [ ] Periodo "Últimos 30 días" activo

#### Escenario 1.3: Navegación entre pasos
**Precondiciones:** En onboarding
**Pasos:**
1. Avanzar al paso 3
2. Tap "Atrás"
3. Verificar que vuelve al paso 2 con datos intactos
4. Avanzar nuevamente
**Resultado esperado:**
- [ ] Navegación bidireccional funciona
- [ ] Datos persisten entre navegaciones

#### Escenario 1.4: Límite de monedas secundarias
**Precondiciones:** En paso 3 de onboarding
**Pasos:**
1. Seleccionar EUR
2. Seleccionar GBP
3. Intentar seleccionar MXN
**Resultado esperado:**
- [ ] MXN no se puede seleccionar (máximo 2)
- [ ] Contador muestra "2/2"

---

## Sección 2: Cuentas

### Vista: AccountFormView

### Campos del Formulario

| Campo | Tipo | Obligatorio | Validación | Valor por defecto |
|-------|------|-------------|------------|-------------------|
| Nombre | TextField | Sí | No vacío, único | - |
| Tipo de cuenta | Picker (6 tipos) | Sí | - | Efectivo |
| Número de cuenta | TextField | No | Formato libre | - |
| Moneda | Selector (7 opciones) | Sí | - | Moneda preferida |
| Modo de ajuste | Picker (2 opciones) | Sí | - | Cambiar saldo inicial |
| Signo del balance | Segmented (Positivo/Negativo) | Sí | - | Positivo |
| Balance | TextField (decimal) | No | Máx 2 decimales | 0.00 |
| Excluir de estadísticas | Toggle | No | - | Off |
| Archivar | Toggle | No | - | Off |

**Tipos de cuenta disponibles:**
- Efectivo
- Cuenta corriente
- Tarjeta de crédito
- Tarjeta de débito
- Ahorros
- Inversiones

**Monedas soportadas:**
- PEN (Sol peruano) 🇵🇪
- USD (Dólar americano) 🇺🇸
- EUR (Euro) 🇪🇺
- MXN (Peso mexicano) 🇲🇽
- COP (Peso colombiano) 🇨🇴
- BRL (Real brasileño) 🇧🇷
- GBP (Libra esterlina) 🇬🇧

**Modos de ajuste:**
- Cambiar saldo inicial: Modifica el saldo inicial, recalcula balance actual
- Ajustar por registro: Crea transacción de ajuste en fecha específica

### Escenarios de Cuentas

#### Escenario 2.1: Crear cuenta mínima
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Ir a Profile → Cuentas → "+"
2. Ingresar nombre: "Mi Cuenta"
3. Tap "Guardar"
**Resultado esperado:**
- [ ] Cuenta creada con tipo "Efectivo"
- [ ] Moneda = moneda preferida del usuario
- [ ] Balance = 0.00
- [ ] Aparece en lista y en Panel

#### Escenario 2.2: Crear cuenta completa
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Ir a Profile → Cuentas → "+"
2. Nombre: "Banco BBVA"
3. Tipo: "Cuenta corriente"
4. Número: "1234-5678-9012"
5. Moneda: USD
6. Balance: 1500.50 (positivo)
7. Tap "Guardar"
**Resultado esperado:**
- [ ] Cuenta creada con todos los campos
- [ ] Balance muestra $1,500.50
- [ ] Visible en Panel y selectores

#### Escenario 2.3: Crear cuenta con balance negativo
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Crear cuenta tipo "Tarjeta de crédito"
2. Seleccionar signo "Negativo"
3. Ingresar balance: 500.00
**Resultado esperado:**
- [ ] Balance guardado como -500.00
- [ ] Se muestra en rojo en la UI

#### Escenario 2.4: Validación de nombre duplicado
**Precondiciones:** Cuenta "Efectivo" existente
**Pasos:**
1. Crear nueva cuenta con nombre "Efectivo"
2. Intentar guardar
**Resultado esperado:**
- [ ] Botón guardar deshabilitado
- [ ] Mensaje de error visible

#### Escenario 2.5: Editar cuenta - cambiar nombre
**Precondiciones:** Cuenta existente
**Pasos:**
1. Profile → Cuentas → tap en cuenta
2. Cambiar nombre
3. Guardar
**Resultado esperado:**
- [ ] Nombre actualizado en toda la app
- [ ] Transacciones mantienen referencia

#### Escenario 2.6: Editar cuenta - ajuste por registro
**Precondiciones:** Cuenta con transacciones
**Pasos:**
1. Editar cuenta
2. Cambiar modo a "Ajustar por registro"
3. Ingresar nuevo balance
4. Seleccionar fecha de ajuste
5. Guardar
**Resultado esperado:**
- [ ] Transacción de ajuste creada
- [ ] Balance actual = nuevo balance
- [ ] Historial mantiene integridad

#### Escenario 2.7: Eliminar cuenta sin transacciones
**Precondiciones:** Cuenta sin transacciones
**Pasos:**
1. Editar cuenta
2. Tap "Eliminar cuenta"
3. Confirmar
**Resultado esperado:**
- [ ] Cuenta eliminada
- [ ] No aparece en ninguna lista

#### Escenario 2.8: Intentar eliminar cuenta con transacciones
**Precondiciones:** Cuenta con transacciones
**Pasos:**
1. Editar cuenta
2. Tap "Eliminar cuenta"
**Resultado esperado:**
- [ ] Alert de error: "No se puede eliminar"
- [ ] Muestra número de transacciones
- [ ] Cuenta NO se elimina

#### Escenario 2.9: Archivar cuenta
**Precondiciones:** Cuenta activa
**Pasos:**
1. Editar cuenta
2. Activar toggle "Archivar"
3. Guardar
**Resultado esperado:**
- [ ] Cuenta no aparece en selectores de transacción
- [ ] Cuenta visible en lista de cuentas (sección archivadas)
- [ ] Transacciones existentes no afectadas

#### Escenario 2.10: Excluir de estadísticas
**Precondiciones:** Cuenta con transacciones
**Pasos:**
1. Editar cuenta
2. Activar "Excluir de estadísticas"
3. Guardar
4. Ir a Statistics
**Resultado esperado:**
- [ ] Transacciones de esta cuenta no aparecen en gráficas
- [ ] Totales no incluyen esta cuenta

#### Escenario 2.11: Cuenta en cada moneda
**Precondiciones:** Ninguna
**Pasos por cada moneda (7x):**
1. Crear cuenta con moneda X
2. Verificar símbolo correcto
3. Crear transacción
4. Verificar formato de monto
**Monedas a probar:**
- [ ] PEN: S/ 1,234.56
- [ ] USD: $1,234.56
- [ ] EUR: €1,234.56
- [ ] MXN: $1,234.56
- [ ] COP: $1,234.56
- [ ] BRL: R$1,234.56
- [ ] GBP: £1,234.56

---

## Sección 3: Categorías y Subcategorías

### Vista: CategoryDetailView

### Campos de Categoría

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Nombre | TextField | Sí | No vacío |
| Icono | SF Symbol selector | Sí | Selección de grid |
| Color | Color picker | Sí | 15 predefinidos + custom |
| Visible | Toggle | No | Default: On |
| Tipo | Implícito (Ingreso/Gasto) | Sí | Solo lectura después de crear |

### Vista: SubcategoryDetailView

### Campos de Subcategoría

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Nombre | TextField | Sí | No vacío |
| Icono | SF Symbol selector | Sí | Hereda de categoría por default |
| Color | Heredado | - | Siempre hereda de categoría padre |
| Naturaleza | Picker (4 opciones) | Sí | Default: Sin clasificar |
| Visible | Toggle | No | Default: On |

**Naturalezas disponibles:**
- Esencial: Gastos necesarios (comida, servicios)
- Prioritaria: Importante pero no esencial
- Opcional: Gastos discrecionales
- Sin clasificar: Default

### Escenarios de Categorías

#### Escenario 3.1: Crear categoría de gasto
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Profile → Categorías → "+"
2. Seleccionar "Gasto"
3. Nombre: "Entretenimiento"
4. Seleccionar icono (🎬)
5. Seleccionar color (morado)
6. Agregar subcategoría "Cine"
7. Guardar
**Resultado esperado:**
- [ ] Categoría creada como tipo gasto
- [ ] Subcategoría hereda color
- [ ] Disponible en selector de transacciones (solo gastos)

#### Escenario 3.2: Crear categoría de ingreso
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Profile → Categorías → "+"
2. Seleccionar "Ingreso"
3. Nombre: "Trabajo"
4. Agregar subcategorías: "Salario", "Bonos"
5. Guardar
**Resultado esperado:**
- [ ] Categoría tipo ingreso
- [ ] Solo visible al crear ingresos (no gastos)

#### Escenario 3.3: Editar categoría existente
**Precondiciones:** Categoría con subcategorías y transacciones
**Pasos:**
1. Tap en categoría
2. Cambiar nombre y color
3. Guardar
**Resultado esperado:**
- [ ] Nombre actualizado
- [ ] Color propagado a TODAS las subcategorías
- [ ] Transacciones muestran nuevo color

#### Escenario 3.4: Ocultar categoría
**Precondiciones:** Categoría visible con transacciones
**Pasos:**
1. Editar categoría
2. Desactivar toggle "Visible"
3. Confirmar alert informativo
4. Guardar
**Resultado esperado:**
- [ ] Categoría no aparece en selector de transacciones
- [ ] Transacciones existentes no afectadas
- [ ] Visible en lista de categorías (sección ocultas)

#### Escenario 3.5: Eliminar categoría sin transacciones
**Precondiciones:** Categoría sin transacciones en ninguna subcategoría
**Pasos:**
1. Editar categoría
2. Tap "Eliminar categoría"
3. Confirmar
**Resultado esperado:**
- [ ] Categoría eliminada
- [ ] Subcategorías eliminadas
- [ ] No aparece en ninguna lista

#### Escenario 3.6: Intentar eliminar categoría con transacciones
**Precondiciones:** Categoría con transacciones
**Pasos:**
1. Editar categoría
2. Tap "Eliminar categoría"
**Resultado esperado:**
- [ ] Alert de error con conteo de transacciones
- [ ] Categoría NO se elimina

### Escenarios de Subcategorías

#### Escenario 3.7: Crear subcategoría
**Precondiciones:** Categoría existente
**Pasos:**
1. Dentro de categoría, tap "Agregar subcategoría"
2. Nombre: "Restaurantes"
3. Seleccionar naturaleza: "Opcional"
4. Seleccionar icono personalizado
5. Guardar
**Resultado esperado:**
- [ ] Subcategoría creada
- [ ] Color heredado de categoría padre
- [ ] Icono personalizado visible

#### Escenario 3.8: Cambiar naturaleza de subcategoría
**Precondiciones:** Subcategoría existente con transacciones
**Pasos:**
1. Editar subcategoría
2. Cambiar naturaleza de "Sin clasificar" a "Esencial"
3. Guardar
4. Verificar en Statistics → por naturaleza
**Resultado esperado:**
- [ ] Naturaleza actualizada
- [ ] Widget de naturalezas refleja cambio
- [ ] Transacciones existentes actualizan su clasificación

#### Escenario 3.9: Eliminar subcategoría sin transacciones
**Precondiciones:** Subcategoría sin transacciones
**Pasos:**
1. En modo edición de categoría, tap en "-" de subcategoría
2. Confirmar eliminación
**Resultado esperado:**
- [ ] Subcategoría eliminada
- [ ] Lista actualizada

#### Escenario 3.10: Eliminar subcategoría con transacciones - transferir
**Precondiciones:** Subcategoría con transacciones
**Pasos:**
1. Intentar eliminar subcategoría
2. Sheet de transferencia aparece
3. Seleccionar subcategoría destino
4. Confirmar
**Resultado esperado:**
- [ ] Transacciones movidas a nueva subcategoría
- [ ] Subcategoría original eliminada
- [ ] Conteos actualizados correctamente

---

## Sección 4: Tags (Etiquetas)

### Vista: TagFormView

### Campos del Formulario

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Nombre | TextField | Sí | Max 20 chars, único (case-insensitive) |
| Icono | SF Symbol selector | Sí | Default: "tag.fill" |
| Color | Color picker | Sí | 15 predefinidos + custom |
| Activo | Toggle | No | Default: On |

### Escenarios de Tags

#### Escenario 4.1: Crear tag mínimo
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Profile → Tags → "+"
2. Ingresar nombre: "Viaje"
3. Guardar (usar defaults para icono/color)
**Resultado esperado:**
- [ ] Tag creado con color automático (no repetido)
- [ ] Icono default "tag.fill"
- [ ] Activo por default

#### Escenario 4.2: Crear tag completo
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Profile → Tags → "+"
2. Nombre: "Trabajo"
3. Seleccionar icono (💼)
4. Seleccionar color (azul)
5. Guardar
**Resultado esperado:**
- [ ] Tag con todos los campos personalizados
- [ ] Disponible en selector de transacciones

#### Escenario 4.3: Validación nombre único
**Precondiciones:** Tag "Viaje" existente
**Pasos:**
1. Crear nuevo tag
2. Ingresar nombre "viaje" (minúsculas)
3. Intentar guardar
**Resultado esperado:**
- [ ] Botón guardar deshabilitado
- [ ] Validación case-insensitive

#### Escenario 4.4: Validación máximo 20 caracteres
**Precondiciones:** Ninguna
**Pasos:**
1. Crear tag
2. Intentar ingresar 25 caracteres
**Resultado esperado:**
- [ ] Texto truncado a 20 caracteres
- [ ] No permite escribir más

#### Escenario 4.5: Desactivar tag
**Precondiciones:** Tag activo usado en transacciones
**Pasos:**
1. Editar tag
2. Desactivar toggle "Activo"
3. Guardar
4. Crear nueva transacción
**Resultado esperado:**
- [ ] Tag no aparece en selector
- [ ] Transacciones existentes conservan el tag
- [ ] Tag visible en filtros (para buscar historial)

#### Escenario 4.6: Eliminar tag
**Precondiciones:** Tag con transacciones asociadas
**Pasos:**
1. Editar tag
2. Tap "Eliminar"
3. Confirmar
**Resultado esperado:**
- [ ] Tag eliminado
- [ ] Transacciones pierden referencia al tag
- [ ] No afecta otros datos de transacción

#### Escenario 4.7: Cambiar icono y color
**Precondiciones:** Tag existente
**Pasos:**
1. Editar tag
2. Tap en icono/color
3. Seleccionar nuevo icono
4. Guardar
**Resultado esperado:**
- [ ] Icono actualizado en toda la app
- [ ] Transacciones muestran nuevo icono

---

## Sección 5: Transacciones

### Vista: NewTransactionView

### Campos del Formulario (3 modos)

**Campos comunes:**

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Tipo | Segmented (Gasto/Ingreso/Transferencia) | Sí | - |
| Fecha | DatePicker + presets | Sí | Default: Hoy |
| Descripción/Nota | TextField | No | Soporta menciones (#tag, !subcategory, @account) |
| Monto | TextField (decimal) | Sí | Max 2 decimales, > 0 |

**Campos específicos Gasto/Ingreso:**

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Cuenta | Selector | Sí | Cuentas activas |
| Subcategoría | Selector | Sí | Según tipo (gasto/ingreso) |
| Tags | Multi-selector | No | Tags activos |
| Naturaleza override | Selector | No | Solo si subcategoría seleccionada |

**Campos específicos Transferencia:**

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Cuenta origen | Selector | Sí | Cuentas activas |
| Cuenta destino | Selector | Sí | Cuentas activas, diferente de origen |
| Monto origen | TextField | Sí | En moneda de cuenta origen |
| Monto destino | TextField | Condicional | Solo si monedas diferentes |
| Tipo de cambio | Auto/Manual | Condicional | Solo si multimoneda |

### Escenarios de Gastos

#### Escenario 5.1: Crear gasto mínimo
**Precondiciones:** Al menos 1 cuenta y 1 subcategoría de gasto
**Pasos:**
1. Tap "+" flotante
2. Verificar tipo "Gasto" seleccionado
3. Ingresar monto: 50.00
4. Seleccionar cuenta
5. Seleccionar subcategoría
6. Tap "Guardar"
**Resultado esperado:**
- [ ] Transacción creada con fecha de hoy
- [ ] Balance de cuenta disminuye en 50.00
- [ ] Aparece en Records
- [ ] Pantalla de éxito con opción "Crear otra"

#### Escenario 5.2: Crear gasto completo
**Precondiciones:** Cuenta, subcategorías y tags existentes
**Pasos:**
1. Tap "+"
2. Monto: 125.50
3. Descripción: "Almuerzo con cliente"
4. Cambiar fecha a ayer
5. Seleccionar cuenta "Tarjeta VISA"
6. Seleccionar subcategoría "Restaurantes"
7. Seleccionar 2 tags: "Trabajo", "Clientes"
8. Cambiar naturaleza a "Prioritaria"
9. Guardar
**Resultado esperado:**
- [ ] Todos los campos guardados correctamente
- [ ] Naturaleza override aplicada
- [ ] Tags visibles en detalle

#### Escenario 5.3: Gasto con mención de tag (#)
**Precondiciones:** Tag "viaje" existente
**Pasos:**
1. Crear gasto
2. En descripción escribir: "Hotel #via"
3. Seleccionar "viaje" del autocomplete
**Resultado esperado:**
- [ ] Tag "viaje" añadido automáticamente
- [ ] "#via" removido del texto
- [ ] Tag visible en chips

#### Escenario 5.4: Gasto con monto mínimo
**Precondiciones:** Cuenta existente
**Pasos:**
1. Crear gasto con monto 0.01
2. Guardar
**Resultado esperado:**
- [ ] Transacción creada correctamente
- [ ] Balance actualizado

#### Escenario 5.5: Gasto con monto máximo
**Precondiciones:** Cuenta existente
**Pasos:**
1. Crear gasto con monto 999999999.99
2. Guardar
**Resultado esperado:**
- [ ] Transacción creada
- [ ] Formato de número correcto en la UI

### Escenarios de Ingresos

#### Escenario 5.6: Crear ingreso
**Precondiciones:** Categoría de ingreso con subcategorías
**Pasos:**
1. Tap "+"
2. Cambiar a tipo "Ingreso"
3. Verificar color cambia a verde/índigo
4. Monto: 2500.00
5. Seleccionar subcategoría de ingreso
6. Guardar
**Resultado esperado:**
- [ ] Solo muestra categorías de ingreso
- [ ] Balance de cuenta aumenta
- [ ] Monto se muestra positivo

#### Escenario 5.7: Validar filtro de categorías por tipo
**Precondiciones:** Categorías de gasto e ingreso
**Pasos:**
1. Crear transacción tipo Gasto
2. Abrir selector de subcategorías
3. Verificar que solo aparecen gastos
4. Cambiar a tipo Ingreso
5. Abrir selector de subcategorías
**Resultado esperado:**
- [ ] En gasto: solo subcategorías de gastos
- [ ] En ingreso: solo subcategorías de ingresos

### Escenarios de Transferencias

#### Escenario 5.8: Transferencia misma moneda
**Precondiciones:** 2 cuentas en PEN
**Pasos:**
1. Tap "+"
2. Seleccionar "Transferencia"
3. Cuenta origen: "Efectivo"
4. Cuenta destino: "Ahorros"
5. Monto: 500.00
6. Guardar
**Resultado esperado:**
- [ ] 2 transacciones creadas (salida y entrada)
- [ ] Balance origen disminuye 500
- [ ] Balance destino aumenta 500
- [ ] Ambas vinculadas internamente

#### Escenario 5.9: Transferencia multimoneda
**Precondiciones:** Cuenta en PEN y cuenta en USD
**Pasos:**
1. Crear transferencia
2. Origen: Cuenta PEN
3. Destino: Cuenta USD
4. Monto origen: 1000.00 PEN
5. Verificar tipo de cambio automático
6. Ajustar monto destino si necesario: 270.00 USD
7. Guardar
**Resultado esperado:**
- [ ] Monto en cada moneda correcto
- [ ] Tipo de cambio guardado
- [ ] Balances actualizados correctamente

#### Escenario 5.10: Transferencia con tipo de cambio manual
**Precondiciones:** Transferencia multimoneda
**Pasos:**
1. Crear transferencia USD → EUR
2. Tap en monto destino
3. Ingresar monto manualmente
4. Guardar
**Resultado esperado:**
- [ ] Tipo de cambio calculado desde montos
- [ ] Ambos montos respetados

#### Escenario 5.10.1: Clasificación correcta de transferencias
**Precondiciones:** 2 cuentas en PEN
**Pasos:**
1. Crear transferencia de 500 PEN desde Efectivo a Ahorros
2. Ir a Statistics → Records
3. Filtrar por "Ingresos" (tap en total verde)
4. Verificar que aparece la transacción entrante (+500)
5. Filtrar por "Gastos" (tap en total rosa)
6. Verificar que aparece la transacción saliente (-500)
**Resultado esperado:**
- [ ] Transferencia entrante (+500) tiene categoría "Ingresos"
- [ ] Transferencia entrante aparece al filtrar por ingresos
- [ ] Transferencia saliente (-500) tiene categoría "Otros"
- [ ] Transferencia saliente aparece al filtrar por gastos
- [ ] Ambas excluidas de totales reales de ingresos/gastos en gráficas

#### Escenario 5.10.2: Protección de categorías del sistema
**Precondiciones:** App con datos
**Pasos:**
1. Ir a Profile → Categorías
2. Tap en categoría "Otros"
3. Verificar que NO aparece botón de eliminar
4. Tap en categoría "Ingresos"
5. Verificar que NO aparece botón de eliminar
6. Tap en categoría "Alimentación"
7. Verificar que SÍ aparece botón de eliminar
**Resultado esperado:**
- [ ] "Otros" e "Ingresos" no tienen botón eliminar
- [ ] Otras categorías sí tienen botón eliminar

#### Escenario 5.10.3: Protección de subcategorías del sistema
**Precondiciones:** App con datos
**Pasos:**
1. Ir a Profile → Categorías → Otros
2. Tap en "Editar"
3. Verificar que "Ajustes de saldo" NO tiene botón "-"
4. Verificar que "Transferencia entre cuentas" NO tiene botón "-"
5. Ir a Ingresos
6. Verificar que "Transferencia entre cuentas" NO tiene botón "-"
7. Verificar que "Salario" SÍ tiene botón "-"
**Resultado esperado:**
- [ ] Subcategorías del sistema no tienen botón eliminar
- [ ] Otras subcategorías sí tienen botón eliminar

#### Escenario 5.10.4: Importación de transferencias
**Precondiciones:** Archivo test_transfers.csv disponible
**Pasos:**
1. Profile → Importar
2. Seleccionar test_transfers.csv
3. Completar importación
4. Ir a Statistics → Records
5. Filtrar por "Ingresos"
6. Verificar transacciones entrantes (+500, +200)
**Resultado esperado:**
- [ ] 5 transacciones importadas
- [ ] Transferencias entrantes (positivas) en categoría Ingresos
- [ ] Transferencias salientes (negativas) en categoría Otros
- [ ] Todas marcadas con balanceAdjustmentType correcto

### Escenarios de Edición y Eliminación

#### Escenario 5.11: Editar transacción existente
**Precondiciones:** Transacción existente
**Pasos:**
1. Records → tap en transacción
2. Vista de edición se abre
3. Cambiar monto de 50 a 75
4. Guardar
**Resultado esperado:**
- [ ] Monto actualizado
- [ ] Balance recalculado (diferencia de 25)
- [ ] Fecha no afectada

#### Escenario 5.12: Cambiar tipo de transacción
**Precondiciones:** Gasto existente
**Pasos:**
1. Editar transacción
2. Cambiar de Gasto a Ingreso
3. Seleccionar nueva subcategoría
4. Guardar
**Resultado esperado:**
- [ ] Tipo actualizado
- [ ] Subcategoría válida para nuevo tipo
- [ ] Balance recalculado (+100 en vez de -100)

#### Escenario 5.13: Eliminar transacción (swipe)
**Precondiciones:** Transacción existente
**Pasos:**
1. Records → swipe left en transacción
2. Tap "Eliminar"
3. Confirmar
**Resultado esperado:**
- [ ] Transacción eliminada
- [ ] Balance de cuenta restaurado

### Escenarios de Edición Masiva (Bulk Edit)

#### Escenario 5.14: Entrar en modo selección
**Precondiciones:** Al menos 3 transacciones en Records
**Pasos:**
1. Records → tap icono checkmark (toolbar)
2. Verificar UI de modo selección
**Resultado esperado:**
- [ ] Barra superior muestra "Cancelar" y "Seleccionar todo"
- [ ] Transacciones muestran checkbox
- [ ] FAB "+" desaparece
- [ ] Barra inferior aparece al seleccionar (vacía si 0 seleccionados)

#### Escenario 5.15: Seleccionar múltiples transacciones
**Precondiciones:** Modo selección activo, 5+ transacciones
**Pasos:**
1. Tap en 3 transacciones diferentes
2. Verificar contador
3. Tap "Seleccionar todo"
4. Verificar contador
5. Tap una seleccionada para deseleccionar
**Resultado esperado:**
- [ ] Contador muestra "3 seleccionados" después de paso 2
- [ ] "Seleccionar todo" selecciona todas las visibles
- [ ] Deseleccionar reduce contador

#### Escenario 5.16: Eliminar múltiples transacciones
**Precondiciones:** 3+ transacciones seleccionadas
**Pasos:**
1. Con 3 transacciones seleccionadas
2. Tap icono papelera (barra inferior)
3. Confirmar eliminación en dialog
**Resultado esperado:**
- [ ] ConfirmationDialog aparece desde abajo
- [ ] Mensaje indica cantidad a eliminar
- [ ] Tras confirmar: transacciones eliminadas
- [ ] Balances de cuentas actualizados
- [ ] Modo selección se cierra automáticamente

#### Escenario 5.17: Edición masiva - Cambiar cuenta
**Precondiciones:** 3+ transacciones seleccionadas, 2+ cuentas activas
**Pasos:**
1. Con 3 transacciones seleccionadas
2. Tap icono lápiz (barra inferior)
3. Sheet de edición masiva aparece
4. Tap "Cuentas"
5. Seleccionar cuenta diferente
**Resultado esperado:**
- [ ] Sheet muestra 5 opciones (Cuentas, Categoría, Tags, Nota, Monto)
- [ ] Aviso de cambio de divisa visible
- [ ] Selector de cuentas abre
- [ ] Tras seleccionar: todas las transacciones cambian de cuenta
- [ ] Divisa actualizada según nueva cuenta
- [ ] Modo selección se cierra

#### Escenario 5.18: Edición masiva - Cambiar subcategoría
**Precondiciones:** 3+ transacciones de gasto seleccionadas
**Pasos:**
1. Seleccionar 3 gastos
2. Tap lápiz → "Categoría"
3. Seleccionar nueva subcategoría
**Resultado esperado:**
- [ ] Selector muestra solo subcategorías de gasto
- [ ] Tras seleccionar: subcategoría actualizada en todas
- [ ] Sheet y modo selección se cierran

#### Escenario 5.19: Edición masiva - Añadir tags
**Precondiciones:** 3+ transacciones seleccionadas, tags existentes
**Pasos:**
1. Seleccionar 3 transacciones (algunas con tags, otras sin)
2. Tap lápiz → "Tags"
3. Seleccionar 2 tags
4. Tap "Guardar"
**Resultado esperado:**
- [ ] Tags añadidos a todas las transacciones
- [ ] Tags existentes preservados (no reemplazados)
- [ ] No hay duplicados de tags

#### Escenario 5.20: Edición masiva - Cambiar nota
**Precondiciones:** 3+ transacciones seleccionadas
**Pasos:**
1. Seleccionar 3 transacciones
2. Tap lápiz → "Nota"
3. Escribir "Actualizado en lote"
4. Guardar
**Resultado esperado:**
- [ ] Campo de texto con auto-focus
- [ ] Nota aplicada a todas las transacciones
- [ ] Notas anteriores reemplazadas

#### Escenario 5.21: Edición masiva - Cambiar monto
**Precondiciones:** 3+ transacciones seleccionadas
**Pasos:**
1. Seleccionar 3 transacciones
2. Tap lápiz → "Monto"
3. Ingresar 100.00
4. Guardar
**Resultado esperado:**
- [ ] Teclado numérico aparece
- [ ] Monto aplicado a todas las transacciones
- [ ] Balances recalculados correctamente

#### Escenario 5.22: Cancelar edición masiva
**Precondiciones:** Transacciones seleccionadas
**Pasos:**
1. Seleccionar transacciones
2. Tap lápiz (abre sheet)
3. Tap X para cerrar sheet
4. Tap "Cancelar" en toolbar
**Resultado esperado:**
- [ ] Sheet se cierra sin cambios
- [ ] Cancelar sale del modo selección
- [ ] Transacciones no modificadas

### Escenarios de Favoritos en Transacciones

#### Escenario 5.23: Usar favorito para crear transacción
**Precondiciones:** Favorito "Café" existente con monto 8.50
**Pasos:**
1. Tap "+"
2. Tap icono estrella (favoritos)
3. Seleccionar "Café"
4. Verificar campos pre-llenados
5. Ajustar monto si necesario
6. Guardar
**Resultado esperado:**
- [ ] Campos pre-llenados del favorito
- [ ] Monto editable
- [ ] Transacción creada correctamente

### Escenarios de Acciones Rápidas (Quick Actions)

#### Escenario 5.24: Verificar visibilidad de botones de acción rápida
**Precondiciones:** Transacción existente
**Pasos:**
1. Crear nueva transacción (modo nuevo)
2. Verificar botones visibles debajo del monto
3. Editar transacción existente
4. Verificar botones visibles
**Resultado esperado:**
- [ ] En modo nuevo: solo "Favorito" y "Recurrente" visibles
- [ ] En modo edición: los 4 botones visibles (Duplicar, Eliminar, Favorito, Recurrente)
- [ ] Iconos correctos: doc.on.doc, trash, star, repeat
- [ ] Labels correctos según idioma

#### Escenario 5.25: Duplicar transacción existente
**Precondiciones:** Transacción existente con todos los campos llenados
**Pasos:**
1. Editar transacción existente
2. Verificar título "Editar registro"
3. Tap botón "Duplicar"
4. Verificar que título cambia a "Nuevo registro"
5. Verificar que todos los campos mantienen sus valores
6. Guardar
**Resultado esperado:**
- [ ] Título cambia de "Editar registro" a "Nuevo registro"
- [ ] Monto, cuenta, subcategoría, tags, nota se mantienen
- [ ] Fecha permanece igual
- [ ] Al guardar: crea NUEVA transacción (no modifica original)
- [ ] Dos transacciones existen con mismos datos

#### Escenario 5.26: Eliminar transacción desde quick action
**Precondiciones:** Transacción existente
**Pasos:**
1. Editar transacción
2. Tap botón "Eliminar" (trash icon)
3. Verificar alert de confirmación
4. Cancelar primera vez
5. Repetir y confirmar
**Resultado esperado:**
- [ ] Alert aparece: "Confirmar eliminación"
- [ ] Mensaje: "Esta acción no se puede deshacer"
- [ ] Botón cancelar cierra alert sin acción
- [ ] Botón eliminar borra transacción
- [ ] Vista se cierra automáticamente
- [ ] Balance de cuenta actualizado

#### Escenario 5.27: Guardar como favorito desde transacción nueva
**Precondiciones:** Transacción nueva con datos (sin guardar)
**Pasos:**
1. Crear nueva transacción
2. Llenar: monto 50, cuenta, subcategoría, nota "Test"
3. Tap botón "Favorito"
4. Verificar alert con campo de nombre
5. Ingresar nombre "Mi Favorito"
6. Tap Guardar
**Resultado esperado:**
- [ ] Alert aparece: "Guardar como favorito"
- [ ] Campo de nombre pre-llenado con nota actual ("Test")
- [ ] Toast aparece: "Guardado como favorito"
- [ ] Favorito creado con datos del formulario
- [ ] Formulario de transacción sigue abierto (no se cierra)

#### Escenario 5.28: Guardar como favorito desde transacción existente
**Precondiciones:** Transacción existente con todos los campos
**Pasos:**
1. Editar transacción con cuenta, subcategoría, tags, nota
2. Tap botón "Favorito"
3. Cambiar nombre a "Recurrente mensual"
4. Guardar
**Resultado esperado:**
- [ ] Favorito incluye: cuenta, subcategoría, tags, monto, nota
- [ ] Nombre del favorito = lo ingresado
- [ ] Toast de confirmación visible
- [ ] Favorito aparece en lista de Favoritos

#### Escenario 5.29: Guardar como recurrente desde transacción
**Precondiciones:** Transacción nueva o existente con datos
**Pasos:**
1. Crear/editar transacción
2. Llenar: monto 100, cuenta, subcategoría
3. Tap botón "Recurrente"
4. Verificar alert con campo de nombre
5. Ingresar nombre "Pago mensual"
6. Tap Guardar
**Resultado esperado:**
- [ ] Alert aparece: "Guardar como recurrente"
- [ ] Campo de nombre pre-llenado con nota (si existe)
- [ ] Toast aparece: "Guardado como recurrente"
- [ ] ScheduledPayment creado con:
  - Recurrencia mensual (default)
  - nextDueDate = fecha de la transacción
  - Datos del formulario (cuenta, subcategoría, monto, etc.)
- [ ] Pago aparece en Planning → Pagos Programados

#### Escenario 5.30: Verificar localización de acciones rápidas
**Precondiciones:** App configurada en diferentes idiomas
**Pasos:**
1. Cambiar idioma del dispositivo a cada uno soportado
2. Ir a editar transacción
3. Verificar labels de los 4 botones
**Resultado esperado:**
- [ ] ES: Duplicar, Eliminar, Favorito, Recurrente
- [ ] EN: Duplicate, Delete, Favorite, Recurring
- [ ] DE: Duplizieren, Löschen, Favorit, Wiederkehrend
- [ ] FR: Dupliquer, Supprimer, Favori, Récurrent
- [ ] IT: Duplica, Elimina, Preferito, Ricorrente
- [ ] PT: Duplicar, Excluir, Favorito, Recorrente

---

## Sección 6: Presupuestos

### Vista: BudgetEditorView

### Campos del Formulario

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Nombre | TextField | Sí | No vacío |
| Monto límite | TextField (decimal) | Sí | > 0 |
| Tipo de periodo | Segmented (4 opciones) | Sí | Semanal/Mensual/Anual/Único |
| Fecha inicio | DatePicker | Condicional | Solo para periodo Único |
| Fecha fin | DatePicker | Condicional | Solo para periodo Único |
| Activo | Toggle | No | Default: On |
| Filtro Cuentas | Multi-select chips | No | Default: Todas |
| Filtro Subcategorías | Sheet selector | No | Default: Todas |
| Filtro Tags | Multi-select chips | No | Default: Todos |
| Filtro Naturalezas | Multi-select chips | No | Default: Todas |

### Escenarios de Presupuestos

#### Escenario 6.1: Crear presupuesto mensual simple
**Precondiciones:** Usuario con transacciones
**Pasos:**
1. Planning → Presupuestos → "+"
2. Nombre: "Comida"
3. Monto: 1500.00
4. Periodo: Mensual (default)
5. Guardar
**Resultado esperado:**
- [ ] Presupuesto sin filtros = aplica a todo
- [ ] Progreso calculado con gastos del mes
- [ ] Widget visible en Panel

#### Escenario 6.2: Crear presupuesto con filtros
**Precondiciones:** Categorías y tags existentes
**Pasos:**
1. Crear presupuesto
2. Nombre: "Entretenimiento"
3. Monto: 500.00
4. Seleccionar solo subcategorías de entretenimiento
5. Seleccionar cuentas específicas
6. Guardar
**Resultado esperado:**
- [ ] Solo cuenta gastos que coincidan con filtros
- [ ] Resumen muestra filtros activos

#### Escenario 6.3: Presupuesto semanal
**Precondiciones:** Ninguna
**Pasos:**
1. Crear presupuesto
2. Periodo: Semanal
3. Monto: 200.00
4. Guardar
**Resultado esperado:**
- [ ] Se reinicia cada semana
- [ ] Semana comienza según configuración (lunes o domingo)

#### Escenario 6.4: Presupuesto único (rango de fechas)
**Precondiciones:** Ninguna
**Pasos:**
1. Crear presupuesto
2. Periodo: Único
3. Fecha inicio: 1 enero 2026
4. Fecha fin: 31 marzo 2026
5. Monto: 5000.00
6. Guardar
**Resultado esperado:**
- [ ] Solo cuenta gastos en ese rango
- [ ] No se reinicia automáticamente
- [ ] Fechas visibles en detalle

#### Escenario 6.5: Ver progreso de presupuesto
**Precondiciones:** Presupuesto con gastos asociados
**Pasos:**
1. Ir a Planning → Presupuestos
2. Observar barra de progreso
**Resultado esperado:**
- [ ] Barra muestra porcentaje correcto
- [ ] Color verde: < 75%
- [ ] Color amarillo: 75-99%
- [ ] Color rojo: >= 100%

#### Escenario 6.6: Presupuesto excedido
**Precondiciones:** Presupuesto con límite 100
**Pasos:**
1. Crear gastos que sumen 150
2. Ver presupuesto
**Resultado esperado:**
- [ ] Barra en rojo
- [ ] Muestra "150%" o similar
- [ ] Monto excedido visible

#### Escenario 6.7: Presupuesto con naturalezas
**Precondiciones:** Subcategorías con naturalezas asignadas
**Pasos:**
1. Crear presupuesto
2. En filtros, seleccionar naturaleza "Opcional"
3. Guardar
**Resultado esperado:**
- [ ] Solo cuenta gastos de subcategorías con naturaleza "Opcional"
- [ ] Útil para controlar gastos discrecionales

#### Escenario 6.8: Desactivar presupuesto
**Precondiciones:** Presupuesto activo
**Pasos:**
1. Editar presupuesto
2. Desactivar toggle "Activo"
3. Guardar
**Resultado esperado:**
- [ ] No aparece en widget de Panel
- [ ] Visible en lista con indicador
- [ ] Historial preservado

---

## Sección 7: Pagos Programados

### Vista: ScheduledPaymentEditorView

### Campos del Formulario

**Información básica:**

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Tipo | Segmented (Gasto/Ingreso) | Sí | Default: Gasto |
| Nombre | TextField | Sí | No vacío |
| Monto | TextField (decimal) | Sí | > 0 |
| Nota | TextField | No | - |
| Activo | Toggle | No | Default: On |
| Es suscripción | Toggle | No | Default: Off |

**Clasificación:**

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Cuenta | Selector | Sí | Cuentas activas |
| Subcategoría | Selector | Sí | Según tipo |
| Tags | Multi-select | No | - |

**Recurrencia:**

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Tipo recurrencia | Segmented (Único/Recurrente) | Sí | - |
| Frecuencia | Picker | Condicional | Diario/Semanal/Mensual/Anual |
| Intervalo | Picker (1-30) | Condicional | "Cada X días/semanas/meses" |
| Día del mes | Picker (1-31) | Condicional | Solo si mensual |
| Días de semana | Multi-select | Condicional | Solo si semanal |
| Mes y día | Pickers | Condicional | Solo si anual |
| Fecha inicio | DatePicker | Sí | - |
| Tiene fecha fin | Toggle | No | - |
| Fecha fin | DatePicker | Condicional | Si tiene fecha fin |

**Notificaciones:**

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Notificar el día | Toggle | No | Default: On |
| Notificar días antes | Picker | No | 0,1,2,3,5,7,14,30 |

### Escenarios de Pagos Programados

#### Escenario 7.1: Crear pago único (one-time)
**Precondiciones:** Cuenta y subcategoría existentes
**Pasos:**
1. Planning → Pagos → "+"
2. Nombre: "Pago seguro auto"
3. Monto: 350.00
4. Tipo: Único (no recurrente)
5. Fecha: 15 de febrero
6. Seleccionar cuenta y subcategoría
7. Guardar
**Resultado esperado:**
- [ ] Pago aparece en calendario en fecha específica
- [ ] No tiene próximas ocurrencias
- [ ] Notificación programada

#### Escenario 7.2: Crear suscripción mensual
**Precondiciones:** Ninguna
**Pasos:**
1. Crear pago
2. Nombre: "Netflix"
3. Activar "Es suscripción"
4. Monto: 45.00
5. Recurrente: Mensual
6. Día del mes: 5
7. Guardar
**Resultado esperado:**
- [ ] Aparece con icono de suscripción
- [ ] Próximo pago: día 5 del mes actual o siguiente
- [ ] Se repite automáticamente

#### Escenario 7.3: Pago semanal en días específicos
**Precondiciones:** Ninguna
**Pasos:**
1. Crear pago recurrente
2. Frecuencia: Semanal
3. Seleccionar: Lunes y Viernes
4. Intervalo: Cada 1 semana
5. Guardar
**Resultado esperado:**
- [ ] Dos ocurrencias por semana
- [ ] Calendario muestra ambos días
- [ ] Próximo pago = próximo lunes o viernes

#### Escenario 7.4: Pago anual
**Precondiciones:** Ninguna
**Pasos:**
1. Crear pago
2. Nombre: "Membresía gym anual"
3. Frecuencia: Anual
4. Mes: Enero, Día: 1
5. Guardar
**Resultado esperado:**
- [ ] Una ocurrencia por año
- [ ] Próximo: 1 enero del próximo año

#### Escenario 7.5: Marcar pago como realizado
**Precondiciones:** Pago programado con fecha hoy o pasada
**Pasos:**
1. Ir a pago próximo
2. Tap "Registrar pago"
3. Confirmar
**Resultado esperado:**
- [ ] Transacción creada con datos del pago
- [ ] Si recurrente: próxima fecha calculada
- [ ] Si único: pago marcado como completado

#### Escenario 7.6: Pausar suscripción
**Precondiciones:** Suscripción activa
**Pasos:**
1. Editar pago
2. Desactivar toggle "Activo"
3. Guardar
**Resultado esperado:**
- [ ] No genera notificaciones
- [ ] No aparece en próximos pagos
- [ ] Historial preservado
- [ ] Puede reactivarse

#### Escenario 7.7: Vista calendario
**Precondiciones:** Varios pagos programados
**Pasos:**
1. Ir a Planning → Pagos → Calendario
2. Navegar entre meses
3. Tap en día con pagos
**Resultado esperado:**
- [ ] Días con pagos marcados
- [ ] Detalle al hacer tap
- [ ] Navegación fluida

#### Escenario 7.8: Pago con fecha fin
**Precondiciones:** Ninguna
**Pasos:**
1. Crear pago mensual
2. Activar "Tiene fecha fin"
3. Fecha fin: 6 meses después
4. Guardar
**Resultado esperado:**
- [ ] Pago se detiene después de fecha fin
- [ ] Calendario no muestra ocurrencias después
- [ ] Indicador visual de fecha fin

---

## Sección 8: Favoritos

### Vista: FavoriteEditorView

### Campos del Formulario

| Campo | Tipo | Obligatorio | Validación |
|-------|------|-------------|------------|
| Nombre | TextField | Sí | No vacío |
| Tipo | Segmented (Gasto/Ingreso) | Sí | NO transferencia |
| Monto | TextField (decimal) | No | - |
| Descripción | TextField | No | - |
| Cuenta | Selector | No | - |
| Subcategoría | Selector | No | - |
| Tags | Multi-select | No | - |
| Naturaleza override | Selector | No | Solo si subcategoría seleccionada |

### Escenarios de Favoritos

#### Escenario 8.1: Crear favorito mínimo
**Precondiciones:** Usuario autenticado
**Pasos:**
1. Planning → Favoritos → "+"
2. Nombre: "Café"
3. Guardar
**Resultado esperado:**
- [ ] Favorito creado solo con nombre
- [ ] Al usar: solo pre-llena tipo (gasto)
- [ ] Usuario debe completar resto

#### Escenario 8.2: Crear favorito completo
**Precondiciones:** Cuentas, categorías y tags existentes
**Pasos:**
1. Crear favorito
2. Nombre: "Almuerzo trabajo"
3. Tipo: Gasto
4. Monto: 25.00
5. Descripción: "Almuerzo"
6. Cuenta: "Efectivo"
7. Subcategoría: "Restaurantes"
8. Tags: "Trabajo"
9. Guardar
**Resultado esperado:**
- [ ] Favorito con todos los campos
- [ ] Al usar: pre-llena todo
- [ ] Solo falta confirmar fecha

#### Escenario 8.3: Usar favorito
**Precondiciones:** Favorito "Café" existente
**Pasos:**
1. Tap "+" para nueva transacción
2. Tap icono estrella
3. Seleccionar "Café"
4. Verificar campos pre-llenados
5. Modificar monto si necesario
6. Guardar
**Resultado esperado:**
- [ ] Sheet se cierra
- [ ] Form pre-llenado
- [ ] Fecha = hoy (siempre actual)

#### Escenario 8.4: Editar favorito
**Precondiciones:** Favorito existente
**Pasos:**
1. Planning → Favoritos
2. Tap en favorito
3. Modificar campos
4. Guardar
**Resultado esperado:**
- [ ] Cambios guardados
- [ ] Próximo uso refleja cambios

#### Escenario 8.5: Reordenar favoritos
**Precondiciones:** Múltiples favoritos
**Pasos:**
1. Planning → Favoritos
2. Modo edición
3. Arrastrar para reordenar
4. Confirmar
**Resultado esperado:**
- [ ] Nuevo orden guardado
- [ ] Orden respetado en selector de transacción

---

## Sección 9: Panel/Dashboard

### Vista: PanelView

### Componentes

| Componente | Función |
|------------|---------|
| Saludo | "Hola, {nombre}" con fecha |
| Carrusel de cuentas | Balances y total |
| 12 widgets configurables | Ver lista abajo |

### Widgets Disponibles

1. **BudgetsWidget** - Presupuestos activos con progreso
2. **CashFlowWidget** - Ingresos vs gastos del periodo
3. **CategoriesPieWidget** - Gráfico pie por categorías
4. **SubcategoriesPieWidget** - Gráfico pie por subcategorías
5. **TagsPieWidget** - Gráfico pie por tags
6. **TopCategoriesWidget** - Top 5 categorías
7. **TopSubcategoriesWidget** - Top 5 subcategorías
8. **TrendWidget** - Línea de balance en el tiempo
9. **NatureTrendWidget** - Gasto por naturaleza
10. **RecentRecordsWidget** - Últimas transacciones
11. **ExchangeRateWidget** - Tasas de cambio
12. **ScheduledPaymentsWidget** - Próximos pagos

### Escenarios de Panel

#### Escenario 9.1: Panel sin datos (empty state)
**Precondiciones:** App recién iniciada, sin transacciones
**Pasos:**
1. Ir a Panel
**Resultado esperado:**
- [ ] Saludo con nombre de usuario
- [ ] Carrusel muestra cuentas seed (si hay)
- [ ] Widgets muestran empty states amigables
- [ ] CTA para crear primera transacción

#### Escenario 9.2: Panel con datos
**Precondiciones:** Transacciones en varias categorías
**Pasos:**
1. Ir a Panel
2. Verificar cada widget
**Resultado esperado:**
- [ ] Carrusel muestra balances correctos
- [ ] Total suma todas las cuentas
- [ ] Gráficas populadas
- [ ] Datos del periodo seleccionado

#### Escenario 9.3: Navegar desde widget a detalle
**Precondiciones:** Datos en widgets
**Pasos:**
1. Tap en chevron de TopCategories
2. Verificar navegación
**Resultado esperado:**
- [ ] Navega a Statistics
- [ ] Mantiene contexto/filtros
- [ ] Puede volver a Panel

#### Escenario 9.4: Configurar widgets visibles
**Precondiciones:** Ninguna
**Pasos:**
1. Panel → icono engranaje
2. Desactivar algunos widgets
3. Activar otros
4. Guardar
**Resultado esperado:**
- [ ] Solo widgets seleccionados visibles
- [ ] Configuración persiste

#### Escenario 9.5: Reordenar widgets
**Precondiciones:** Varios widgets activos
**Pasos:**
1. Panel → configuración
2. Arrastrar widgets
3. Guardar
**Resultado esperado:**
- [ ] Nuevo orden aplicado
- [ ] Persiste entre sesiones

#### Escenario 9.6: InfoHintButton en widgets
**Precondiciones:** Widgets visibles
**Pasos:**
1. Tap en "i" de cualquier widget
**Resultado esperado:**
- [ ] Popover con explicación del widget
- [ ] Texto claro y útil

#### Escenario 9.7: Cambio de periodo en Panel
**Precondiciones:** Datos en múltiples periodos
**Pasos:**
1. Cambiar periodo global (ej: Este mes → Este año)
2. Observar widgets
**Resultado esperado:**
- [ ] Todos los widgets actualizan datos
- [ ] Gráficas reflejan nuevo periodo
- [ ] Totales recalculados

---

## Sección 10: Estadísticas

### Vista: DetailContainerView (3 tabs)

### TrendsTabView

**Elementos:**
- Gráfico de línea (balance/gastos/ingresos)
- Selector de métrica
- Selector de periodo (9 presets + custom)
- Tooltip en hover/tap
- Variación vs periodo anterior

### CategoriesTabView

**Elementos:**
- Pie chart categorías
- Pie chart subcategorías
- Pie chart tags
- Lista expandible por categoría
- Comparación con periodo anterior

### RecordsTabView

**Elementos:**
- Lista de transacciones agrupadas por fecha
- Búsqueda
- Totales clicables (ingreso/gasto)

### Escenarios de Estadísticas

#### Escenario 10.1: Ver tendencia de gastos
**Precondiciones:** Transacciones en múltiples meses
**Pasos:**
1. Statistics → Trends
2. Seleccionar métrica "Gastos"
3. Periodo: Últimos 6 meses
**Resultado esperado:**
- [ ] Línea muestra tendencia
- [ ] Puntos por cada mes
- [ ] Tooltip con valor al tocar

#### Escenario 10.2: Ver distribución por categorías
**Precondiciones:** Gastos en varias categorías
**Pasos:**
1. Statistics → Categories
2. Observar pie chart
3. Tap en segmento
**Resultado esperado:**
- [ ] Porcentajes correctos
- [ ] Colores de categoría
- [ ] Al tap: filtra por esa categoría

#### Escenario 10.3: Comparar con periodo anterior
**Precondiciones:** Datos en periodo actual y anterior
**Pasos:**
1. Activar comparación (M o A)
2. Observar variación
**Resultado esperado:**
- [ ] Muestra +/- porcentaje
- [ ] Flechas de tendencia
- [ ] Contexto útil

#### Escenario 10.4: Drill-down de categoría a subcategoría
**Precondiciones:** Categoría con varias subcategorías
**Pasos:**
1. Tap en categoría del pie
2. Ver subcategorías de esa categoría
**Resultado esperado:**
- [ ] Pie se actualiza a subcategorías
- [ ] Solo de la categoría seleccionada
- [ ] Puede volver atrás

#### Escenario 10.5: Buscar transacciones
**Precondiciones:** Transacciones con notas
**Pasos:**
1. Statistics → Records
2. Escribir en búsqueda: "almuerzo"
**Resultado esperado:**
- [ ] Solo transacciones que coinciden
- [ ] Búsqueda en nota y categoría
- [ ] Resultado instantáneo

#### Escenario 10.6: Empty state sin datos
**Precondiciones:** Periodo sin transacciones
**Pasos:**
1. Seleccionar periodo vacío
2. Ver gráficas
**Resultado esperado:**
- [ ] Mensaje claro "Sin datos"
- [ ] Gráficas vacías pero no rotas
- [ ] Sugerencia de cambiar periodo

---

## Sección 11: Filtros

### Vista: RecordsFiltersView

### Campos de Filtro

| Campo | Tipo | Comportamiento |
|-------|------|----------------|
| Cuentas | Multi-select | Default: todas |
| Categorías/Subcategorías | Sheet selector | Default: todas |
| Tags | Chips | Default: todos |
| Monedas | Multi-select | Default: todas |
| Rango de fechas | Date pickers | Default: periodo actual |
| Tipo transacción | Segmented | Default: todos |

### PeriodSelector

**Presets disponibles:**
1. Esta semana
2. Últimos 7 días
3. Últimos 30 días
4. Este mes
5. Mes pasado
6. Este año
7. Año pasado
8. Todo el tiempo
9. Personalizado (custom range)

### Escenarios de Filtros

#### Escenario 11.1: Filtro simple (una cuenta)
**Precondiciones:** Múltiples cuentas con transacciones
**Pasos:**
1. Abrir filtros
2. Seleccionar solo "Cuenta BBVA"
3. Aplicar
**Resultado esperado:**
- [ ] Solo transacciones de BBVA
- [ ] Totales recalculados
- [ ] Indicador de filtro activo

#### Escenario 11.2: Filtros combinados
**Precondiciones:** Datos variados
**Pasos:**
1. Filtrar por cuenta "Efectivo"
2. Filtrar por categoría "Comida"
3. Filtrar por tag "Viaje"
4. Aplicar
**Resultado esperado:**
- [ ] Solo transacciones que cumplen TODOS los filtros
- [ ] Conteo reducido
- [ ] Indicador muestra múltiples filtros

#### Escenario 11.3: Periodo personalizado
**Precondiciones:** Transacciones en varias fechas
**Pasos:**
1. Tap en selector de periodo
2. Seleccionar "Personalizado"
3. Fecha inicio: 1 enero 2026
4. Fecha fin: 31 enero 2026
5. Aplicar
**Resultado esperado:**
- [ ] Solo transacciones en rango
- [ ] Gráficas ajustadas a rango
- [ ] Periodo visible en header

#### Escenario 11.4: Limpiar todos los filtros
**Precondiciones:** Múltiples filtros activos
**Pasos:**
1. Tap "Limpiar filtros"
**Resultado esperado:**
- [ ] Todos los filtros reseteados
- [ ] Vista completa restaurada
- [ ] Indicador de filtro desaparece

#### Escenario 11.5: Sincronización entre vistas
**Precondiciones:** Filtros aplicados en Statistics
**Pasos:**
1. Aplicar filtros en Statistics
2. Ir a Records
3. Verificar filtros
**Resultado esperado:**
- [ ] Mismos filtros aplicados
- [ ] Contexto compartido
- [ ] Cambio en una vista afecta otra

#### Escenario 11.6: FilterBlockedPopover
**Precondiciones:** Widget que no soporta cierto filtro
**Pasos:**
1. Aplicar filtro que no aplica a widget específico
2. Observar widget
**Resultado esperado:**
- [ ] Popover explica por qué filtro no aplica
- [ ] Widget muestra estado apropiado

---

## Sección 12: Import/Export

### Import (ImportView)

**Formatos soportados:**
- CSV simple (fecha, monto, descripción, categoría)
- CSV multimoneda (incluye campo moneda)

### Export (ExportWizardView)

**Proceso de 3 pasos:**
1. Selección de columnas
2. Filtros de exportación
3. Generación y descarga

### Escenarios de Import

#### Escenario 12.1: Importar CSV simple
**Precondiciones:** Archivo CSV válido
**Pasos:**
1. Profile → Importar → seleccionar archivo
2. Mapear columnas si necesario
3. Seleccionar cuenta destino
4. Importar
**Resultado esperado:**
- [ ] Transacciones creadas
- [ ] Resumen de importación
- [ ] Balances actualizados

#### Escenario 12.2: Importar CSV multimoneda
**Precondiciones:** CSV con columna de moneda
**Pasos:**
1. Importar CSV
2. Sistema detecta múltiples monedas
3. Asignar cuenta por moneda
4. Importar
**Resultado esperado:**
- [ ] Transacciones en cuentas correctas
- [ ] Monedas respetadas

#### Escenario 12.3: Manejar errores de importación
**Precondiciones:** CSV con filas inválidas
**Pasos:**
1. Intentar importar CSV con errores
2. Ver reporte
**Resultado esperado:**
- [ ] Filas válidas importadas
- [ ] Errores listados con detalle
- [ ] Opción de corregir y reintentar

**Casos de error a probar:**
- [ ] Fecha en formato incorrecto
- [ ] Monto no numérico
- [ ] Categoría inexistente
- [ ] Columnas faltantes

### Escenarios de Export

#### Escenario 12.4: Export básico
**Precondiciones:** Transacciones existentes
**Pasos:**
1. Profile → Exportar
2. Seleccionar columnas default
3. Sin filtros adicionales
4. Generar
**Resultado esperado:**
- [ ] CSV generado
- [ ] Todas las transacciones incluidas
- [ ] Formato válido

#### Escenario 12.5: Export con filtros
**Precondiciones:** Transacciones en varias categorías
**Pasos:**
1. Iniciar export
2. Filtrar solo "Este mes"
3. Filtrar categoría "Comida"
4. Generar
**Resultado esperado:**
- [ ] Solo transacciones filtradas
- [ ] Nombre de archivo indica filtros

#### Escenario 12.6: Selección de columnas
**Precondiciones:** Ninguna
**Pasos:**
1. Iniciar export
2. Desmarcar columnas no necesarias
3. Generar
**Resultado esperado:**
- [ ] CSV solo con columnas seleccionadas
- [ ] Orden respetado

---

## Sección 13: Settings/Configuración

### Vista: ProfileView

### Secciones

1. **Personal details:** Nombre, moneda preferida
2. **Cuentas:** Acceso a gestión
3. **Categorías:** Acceso a gestión
4. **Tags:** Acceso a gestión
5. **Moneda:** Principal + secundarias (7 soportadas)
6. **Divisas secundarias:** Hasta 2 adicionales
7. **Tema:** Claro/Oscuro/Sistema
8. **Icono de app:** Selección de variantes
9. **Tabs visibles:** Configurar navegación
10. **Primer día de semana:** Lunes/Domingo
11. **Vaciar datos:** Acción destructiva

### Escenarios de Settings

#### Escenario 13.1: Cambiar nombre de usuario
**Precondiciones:** Nombre actual "Usuario"
**Pasos:**
1. Profile → Personal details
2. Cambiar a "Juan"
3. Guardar
**Resultado esperado:**
- [ ] Panel muestra "Hola, Juan"
- [ ] Cambio persiste

#### Escenario 13.2: Cambiar moneda preferida
**Precondiciones:** Moneda actual PEN
**Pasos:**
1. Profile → Moneda
2. Seleccionar USD
3. Confirmar
**Resultado esperado:**
- [ ] Totales muestran símbolo $
- [ ] Conversiones automáticas
- [ ] Nuevas transacciones default USD

#### Escenario 13.3: Configurar divisas secundarias
**Precondiciones:** Ninguna
**Pasos:**
1. Profile → Divisas secundarias
2. Activar EUR
3. Activar GBP
**Resultado esperado:**
- [ ] Tipo de cambio visible en Panel
- [ ] Disponibles en transferencias
- [ ] Máximo 2

#### Escenario 13.4: Cambiar tema
**Precondiciones:** Tema actual "Sistema"
**Pasos:**
1. Profile → Tema
2. Seleccionar "Oscuro"
**Resultado esperado:**
- [ ] App cambia a modo oscuro
- [ ] Todos los colores adaptan
- [ ] Persiste entre sesiones

#### Escenario 13.5: Cambiar primer día de semana
**Precondiciones:** Presupuesto semanal existente
**Pasos:**
1. Profile → Primer día de semana
2. Cambiar de Lunes a Domingo
3. Verificar presupuesto semanal
**Resultado esperado:**
- [ ] Semana ahora empieza en domingo
- [ ] Presupuesto semanal recalculado
- [ ] Calendario refleja cambio

#### Escenario 13.6: Vaciar todos los datos
**Precondiciones:** App con datos (backup recomendado)
**Pasos:**
1. Profile → Vaciar datos
2. Primera confirmación
3. Segunda confirmación (escribir texto)
4. Confirmar
**Resultado esperado:**
- [ ] Todos los datos eliminados
- [ ] Categorías semilla restauradas
- [ ] Vuelve a onboarding

---

## Sección 14: Casos Edge Globales

### Empty States

#### Escenario 14.1: App con 0 datos
**Precondiciones:** App recién instalada, onboarding completado
**Verificaciones:**
- [ ] Panel: mensaje de bienvenida
- [ ] Records: "No hay transacciones"
- [ ] Statistics: gráficas vacías con mensaje
- [ ] Presupuestos: invita a crear
- [ ] Pagos: lista vacía con CTA
- [ ] Favoritos: lista vacía con CTA

### Performance con Muchos Datos

#### Escenario 14.2: App con 1000+ transacciones
**Precondiciones:** Importar dataset de prueba
**Verificaciones:**
- [ ] Scroll fluido en Records
- [ ] Gráficas cargan sin lag
- [ ] Filtros responden rápido (<1s)
- [ ] Búsqueda instantánea
- [ ] Cambio de periodo fluido

### Valores Extremos

#### Escenario 14.3: Montos extremos
**Verificaciones:**
- [ ] Monto 0.01 se guarda correctamente
- [ ] Monto 999,999,999.99 se guarda
- [ ] Formato no se rompe con números grandes
- [ ] Cálculos de balance precisos

#### Escenario 14.4: Límites de texto
**Verificaciones:**
- [ ] Nota de 500 caracteres
- [ ] Nombre de cuenta de 50 caracteres
- [ ] Truncamiento elegante en UI
- [ ] Datos completos en detalle

#### Escenario 14.5: Muchas entidades
**Verificaciones:**
- [ ] 100 transacciones en un día
- [ ] Categoría con 50 subcategorías
- [ ] 30 tags simultáneos
- [ ] Scroll funciona en selectores

### Fechas Límite

#### Escenario 14.6: Transacciones en fechas especiales
**Verificaciones:**
- [ ] 1 de enero (inicio de año)
- [ ] 31 de diciembre (fin de año)
- [ ] 29 de febrero (año bisiesto)
- [ ] Cambio de mes durante uso
- [ ] Cambio de año durante uso

### Multimoneda Intensivo

#### Escenario 14.7: Operaciones multimoneda
**Verificaciones:**
- [ ] 3+ cuentas en diferentes monedas
- [ ] Transferencia USD → EUR
- [ ] Transferencia EUR → PEN
- [ ] Tipo de cambio del día vs histórico
- [ ] Totales en moneda preferida correctos

### Recuperación de Errores

#### Escenario 14.8: Resiliencia
**Verificaciones:**
- [ ] App cerrada durante guardado → datos no corruptos
- [ ] Sin conexión → funcionalidad offline completa
- [ ] Poco espacio en disco → mensaje claro
- [ ] Rotación de pantalla → estado preservado

### Idiomas

#### Escenario 14.9: Cambio de idioma
**Verificaciones:**
- [ ] Cambiar idioma del dispositivo
- [ ] Toda la UI traduce correctamente
- [ ] Fechas en formato local
- [ ] Números en formato local

---

## Sección 15: Checklist Pre-Release

### Matriz de Pruebas por Módulo

| Módulo | CRUD | Edge Cases | UI | Integración |
|--------|------|------------|-----|-------------|
| Onboarding | - | ✓ | ✓ | ✓ |
| Cuentas | ✓ | ✓ | ✓ | ✓ |
| Categorías | ✓ | ✓ | ✓ | ✓ |
| Subcategorías | ✓ | ✓ | ✓ | ✓ |
| Tags | ✓ | ✓ | ✓ | ✓ |
| Transacciones | ✓ | ✓ | ✓ | ✓ |
| Presupuestos | ✓ | ✓ | ✓ | ✓ |
| Pagos Programados | ✓ | ✓ | ✓ | ✓ |
| Favoritos | ✓ | ✓ | ✓ | ✓ |
| Panel | - | ✓ | ✓ | ✓ |
| Estadísticas | - | ✓ | ✓ | ✓ |
| Filtros | - | ✓ | ✓ | ✓ |
| Import/Export | ✓ | ✓ | ✓ | ✓ |
| Settings | ✓ | ✓ | ✓ | ✓ |

### Checklist por Idioma

| Idioma | UI | Formatos | Plurales | RTL |
|--------|-----|----------|----------|-----|
| Español | ☐ | ☐ | ☐ | N/A |
| Inglés | ☐ | ☐ | ☐ | N/A |
| Portugués | ☐ | ☐ | ☐ | N/A |
| (otros) | ☐ | ☐ | ☐ | ☐ |

### Checklist por Moneda

| Moneda | Símbolo | Formato | Transferencia | Widget |
|--------|---------|---------|---------------|--------|
| PEN 🇵🇪 | ☐ | ☐ | ☐ | ☐ |
| USD 🇺🇸 | ☐ | ☐ | ☐ | ☐ |
| EUR 🇪🇺 | ☐ | ☐ | ☐ | ☐ |
| MXN 🇲🇽 | ☐ | ☐ | ☐ | ☐ |
| COP 🇨🇴 | ☐ | ☐ | ☐ | ☐ |
| BRL 🇧🇷 | ☐ | ☐ | ☐ | ☐ |
| GBP 🇬🇧 | ☐ | ☐ | ☐ | ☐ |

### Checklist de Performance

| Área | Métrica | Objetivo | Resultado |
|------|---------|----------|-----------|
| App launch | Tiempo | <2s | ☐ |
| Records scroll | FPS | 60fps | ☐ |
| Filtro aplicación | Tiempo | <500ms | ☐ |
| Gráficas render | Tiempo | <1s | ☐ |
| Búsqueda | Tiempo | <200ms | ☐ |
| Export 1000 tx | Tiempo | <5s | ☐ |

### Checklist Final

- [ ] Todos los escenarios principales probados
- [ ] Empty states verificados en cada módulo
- [ ] Performance con datos reales aceptable
- [ ] Al menos 2 idiomas verificados completamente
- [ ] Las 7 monedas funcionan correctamente
- [ ] Sin crashes en flujos principales
- [ ] Datos persisten correctamente entre sesiones
- [ ] Notificaciones funcionan (pagos programados)
- [ ] Backup/restore funciona (si aplica)
- [ ] Accesibilidad básica (VoiceOver)

---

## Sección 16: Bandeja de Entrada (Inbox) - V1.1

### Vista: InboxView

Bandeja para borradores de transacciones generados por extractores (voz, imagen, etc.).

### Precondiciones

- Tener drafts en la bandeja (requiere Fase 8.3+ para generar desde voz/imagen)
- Para testing manual: crear drafts programáticamente o mediante debug tools

### Escenarios de Lista

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 16.1 | Ver bandeja vacía (Pendientes) | Abrir bandeja sin drafts | Empty state: "Sin borradores pendientes" |
| 16.2 | Ver bandeja vacía (Archivados) | Cambiar a filtro Archivados | Empty state: "Sin borradores archivados" |
| 16.3 | Filtrar por Pendientes | Tap en chip "Pendientes" | Solo muestra drafts con status pending |
| 16.4 | Filtrar por Archivados | Tap en chip "Archivados" | Muestra drafts approved + rejected |
| 16.5 | Badge en Panel | Ver botón en PanelView | Badge muestra conteo de pendientes |

### Escenarios de Edición Individual

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 16.6 | Abrir editor | Tap en draft | Sheet de edición estilo NewTransactionView |
| 16.7 | Editar nota | Cambiar texto | Se actualiza al guardar |
| 16.8 | Editar monto | Cambiar valor | Se actualiza al guardar |
| 16.9 | Editar fecha | Tap en chip fecha | DatePicker funcional |
| 16.10 | Asignar cuenta | Tap en chip cuenta | AccountSelectorSheet |
| 16.11 | Asignar subcategoría | Tap en chip subcategoría | SubcategorySelectorSheet |
| 16.12 | Asignar tags | Tap en chip tags | TagSelectorSheet |
| 16.13 | Guardar cambios | Tap "Guardar" | Draft actualizado, sheet cierra |

### Escenarios de Aprobación

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 16.14 | Aprobar desde editor | Completar campos + Tap "Aprobar" | TransactionItem creado, draft → approved |
| 16.15 | Aprobar incompleto | Intentar aprobar sin cuenta/monto/subcategoría | Alert con error específico |
| 16.16 | Swipe right to approve | Swipe derecha en draft válido | Draft aprobado, transacción creada |
| 16.17 | Swipe right bloqueado | Swipe derecha en draft incompleto | Swipe no disponible |

### Escenarios de Eliminación

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 16.18 | Swipe left to delete | Swipe izquierda | Draft → rejected, desaparece de Pendientes |
| 16.19 | Ver eliminado en Archivados | Filtrar Archivados | Draft eliminado visible |

### Escenarios de Selección Múltiple

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 16.20 | Entrar modo selección | Tap "Edición múltiple" | Círculos de selección aparecen |
| 16.21 | Seleccionar draft | Tap en draft | Círculo se llena |
| 16.22 | Seleccionar todos | Tap en círculo de barra | Todos seleccionados |
| 16.23 | Deseleccionar todos | Tap en círculo lleno | Todos deseleccionados |
| 16.24 | Salir modo selección | Tap "Cancelar" | Círculos desaparecen |

### Escenarios de Acciones en Lote

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 16.25 | Asignar cuenta a varios | Seleccionar → Editar → Cuenta | Todos actualizados con cuenta |
| 16.26 | Asignar subcategoría a varios | Seleccionar → Editar → Subcategoría | Todos actualizados |
| 16.27 | Aprobar varios válidos | Seleccionar válidos → Aprobar | Transacciones creadas |
| 16.28 | Aprobar con algunos inválidos | Mezcla de válidos e inválidos | Solo válidos se aprueban, muestra conteo |
| 16.29 | Eliminar varios | Seleccionar → Eliminar | Confirmación → todos rejected |

### Validaciones de UI

| Elemento | Verificación |
|----------|--------------|
| Icono de fuente | Correcto para tipo (voz, recibo, etc.) |
| Indicadores campos faltantes | Chips rojos para account/subcategory/amount |
| Fecha relativa | "Hoy", "Ayer", o fecha formateada |
| Color de monto | Verde/morado para positivo, rosa para negativo |
| Indicador confianza | Triángulo naranja si <70% |

---

*Documento creado: 2026-01-20*
*Última actualización: 2026-01-22*
*Total escenarios: ~156*
*Total verificaciones: ~320+*
