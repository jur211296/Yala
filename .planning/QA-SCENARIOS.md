# QA Scenarios - Yala V1.0/V1.1

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
| 15 | Inbox | Transacciones | Depende de drafts generados |
| 16 | Voz | API Key + Internet | Genera drafts en Inbox |
| 17 | Imagen | Ninguna | Genera drafts en Inbox |

---

## Sección 1: Onboarding (Primer Uso)

### Vista: OnboardingView

**Flujo completo de 5 pasos:**
1. Bienvenida + Nombre de usuario
2. Moneda principal
3. Monedas secundarias
4. Periodo por defecto
5. Categorías iniciales (semilla)

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

**Paso 5 - Categorías iniciales:**
| Campo | Tipo | Obligatorio | Opciones |
|-------|------|-------------|----------|
| Cargar categorías | Single select | Sí | "Empezar con estas categorías" (recomendado), "Empezar desde cero" |

### Escenarios de Onboarding

#### Escenario 1.1: Completar onboarding mínimo con categorías
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
10. Tap "Siguiente"
11. Verificar grid visual de categorías con animación
12. Dejar seleccionado "Empezar con estas categorías" (default)
13. Tap "Empezar"
**Resultado esperado:**
- [ ] Nombre guardado como "Usuario"
- [ ] Moneda PEN configurada
- [ ] Sin monedas secundarias
- [ ] Periodo "Este mes" activo
- [ ] 11 categorías semilla creadas (Alimentación, Compras, Transporte, etc.)
- [ ] Subcategorías correspondientes creadas
- [ ] Navega a Panel principal

#### Escenario 1.2: Completar onboarding sin categorías
**Precondiciones:** App recién instalada
**Pasos:**
1. Ingresar nombre "Juan"
2. Tap "Siguiente"
3. Seleccionar USD como moneda principal
4. Tap "Siguiente"
5. Seleccionar EUR y GBP como secundarias
6. Tap "Siguiente"
7. Seleccionar "Últimos 30 días"
8. Tap "Siguiente"
9. Seleccionar "Empezar desde cero"
10. Tap "Empezar"
**Resultado esperado:**
- [ ] Nombre "Juan" visible en Panel
- [ ] Moneda USD configurada
- [ ] EUR y GBP disponibles como secundarias
- [ ] Periodo "Últimos 30 días" activo
- [ ] 0 categorías creadas
- [ ] Panel muestra empty state para categorías

#### Escenario 1.3: Navegación entre pasos
**Precondiciones:** En onboarding
**Pasos:**
1. Avanzar al paso 4
2. Tap "Atrás"
3. Verificar que vuelve al paso 3 con datos intactos
4. Avanzar hasta paso 5
5. Tap "Atrás"
6. Verificar que vuelve al paso 4
**Resultado esperado:**
- [ ] Navegación bidireccional funciona en 5 pasos
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

#### Escenario 1.5: Animación de categorías
**Precondiciones:** En paso 4 de onboarding
**Pasos:**
1. Tap "Siguiente" para ir al paso 5
2. Observar la pantalla de categorías
**Resultado esperado:**
- [ ] Grid de 11 iconos de categorías aparece
- [ ] Animación staggered (iconos aparecen uno por uno)
- [ ] Cada icono muestra color correcto de la categoría
- [ ] Nombre corto debajo de cada icono
- [ ] Badge "Recomendado" en opción de cargar categorías

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
- XLSX (Excel) - mismo formato de columnas que CSV

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

### Escenarios de Import XLSX

#### Escenario 12.3.1: Importar XLSX simple
**Precondiciones:** Archivo XLSX válido con columnas: date,amount,currency,category,subcategory
**Pasos:**
1. Profile → Importar → seleccionar archivo .xlsx
2. Sistema detecta formato Excel
3. Mapear columnas si necesario
4. Seleccionar cuenta destino
5. Importar
**Resultado esperado:**
- [ ] XLSXReader parsea primera hoja
- [ ] Transacciones creadas correctamente
- [ ] Resumen de importación muestra conteo
- [ ] Balances actualizados

#### Escenario 12.3.2: Importar XLSX multimoneda
**Precondiciones:** XLSX con columna currency con múltiples divisas (PEN, USD, EUR)
**Pasos:**
1. Importar archivo XLSX
2. Sistema detecta múltiples monedas via scanCurrenciesFromFile()
3. Sheet de asignación de cuentas por moneda aparece
4. Asignar cuenta a cada moneda
5. Importar
**Resultado esperado:**
- [ ] Detección automática de monedas funciona
- [ ] Transacciones asignadas a cuentas correctas según moneda
- [ ] Balances de cada cuenta actualizados

#### Escenario 12.3.3: XLSX con columnas opcionales (tags, note)
**Precondiciones:** XLSX con columnas: date,amount,currency,category,subcategory,tags,note
**Pasos:**
1. Importar archivo XLSX con 7 columnas
2. Completar importación
**Resultado esperado:**
- [ ] Tags parseados correctamente (separados por coma)
- [ ] Notas importadas
- [ ] Tags nuevos creados con colores únicos

#### Escenario 12.3.4: XLSX con errores de formato
**Precondiciones:** XLSX con celdas inválidas (fecha como texto malformado, monto como texto)
**Pasos:**
1. Intentar importar XLSX con errores
2. Ver reporte de errores
**Resultado esperado:**
- [ ] Filas válidas importadas
- [ ] Errores específicos reportados por fila
- [ ] Mensaje claro del tipo de error

#### Escenario 12.3.5: XLSX vacío o sin datos
**Precondiciones:** Archivo XLSX con solo encabezados, sin filas de datos
**Pasos:**
1. Intentar importar XLSX vacío
**Resultado esperado:**
- [ ] Error claro: "No hay datos para importar"
- [ ] No se crean transacciones

#### Escenario 12.3.6: Selector de archivo acepta .xlsx
**Precondiciones:** Ninguna
**Pasos:**
1. Profile → Importar
2. Verificar que el picker muestra archivos .xlsx y .csv
**Resultado esperado:**
- [ ] UTType.spreadsheet acepta .xlsx
- [ ] UTType.commaSeparatedText acepta .csv
- [ ] Ambos formatos seleccionables

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

#### Escenario 13.2: Cambiar moneda preferida via CurrencyPickerSheet
**Precondiciones:** Moneda actual PEN
**Pasos:**
1. Profile → Divisa y cambio
2. Tap en fila de "Divisa preferida" (muestra PEN actual)
3. Se abre CurrencyPickerSheet con divisas agrupadas por continente
4. Verificar que divisas están ordenadas A-Z dentro de cada sección
5. Seleccionar USD (en sección "Norteamérica")
6. Sheet se cierra automáticamente
7. Observar indicador de progreso (recalculando conversiones)
**Resultado esperado:**
- [ ] Sheet muestra divisas agrupadas por continente (Latinoamérica, Norteamérica, Europa, Asia, Oceanía, Medio Oriente, África)
- [ ] Divisa actual (PEN) tiene checkmark visible
- [ ] Al seleccionar otra divisa, sheet se cierra automáticamente
- [ ] Indicador de progreso aparece mientras se actualizan transacciones
- [ ] Totales ahora muestran símbolo $ (USD)
- [ ] Nuevas transacciones default USD

#### Escenario 13.3: Configurar divisas secundarias via SecondaryCurrencyPickerSheet
**Precondiciones:** Sin divisas secundarias configuradas
**Pasos:**
1. Profile → Divisa y cambio
2. Tap en fila de "Divisas secundarias" (muestra "Ninguna")
3. Se abre SecondaryCurrencyPickerSheet
4. Tap en EUR (sección Europa) - aparece estrella llena
5. Tap en GBP (sección Europa) - aparece estrella llena
6. Intentar tap en CHF - debe estar deshabilitado (límite de 2)
7. Cerrar sheet con X
**Resultado esperado:**
- [ ] Sheet muestra divisas agrupadas por continente (sin incluir la preferida)
- [ ] Al seleccionar, aparece sección "Seleccionados" al tope con las divisas marcadas
- [ ] Icono de estrella llena para seleccionadas, vacía para no seleccionadas
- [ ] Después de 2 selecciones, las demás aparecen con opacity 0.5 y deshabilitadas
- [ ] Sheet NO se cierra al seleccionar (permite múltiples toggle)
- [ ] Fila de divisas secundarias ahora muestra "🇪🇺 EUR 🇬🇧 GBP"
- [ ] Widget de tipo de cambio refleja las nuevas divisas

#### Escenario 13.3.1: Ver todas las tasas de cambio via ExchangeRatesSheet
**Precondiciones:** Divisas secundarias configuradas (EUR, GBP)
**Pasos:**
1. Profile → Divisa y cambio
2. En sección "Tipo de cambio", verificar que muestra EUR y GBP inline
3. Tap en "Ver todas"
4. Se abre ExchangeRatesSheet
5. Scroll para ver todas las divisas
**Resultado esperado:**
- [ ] Sheet muestra todas las divisas excepto la preferida
- [ ] Divisas agrupadas por continente
- [ ] Cada fila muestra: Bandera + "1 [código]" + nombre + tasa actual
- [ ] Footer muestra última actualización
- [ ] Filas son de solo lectura (no hay interacción)

#### Escenario 13.3.2: Quitar divisa secundaria
**Precondiciones:** Divisas secundarias: EUR, GBP
**Pasos:**
1. Profile → Divisa y cambio
2. Tap en fila de divisas secundarias
3. En sección "Seleccionados", tap en EUR para quitarla
4. Estrella de EUR cambia a vacía
5. Cerrar sheet
**Resultado esperado:**
- [ ] EUR ya no aparece en sección "Seleccionados"
- [ ] Fila de divisas secundarias ahora muestra solo "🇬🇧 GBP"
- [ ] Otras divisas vuelven a estar habilitadas (ya no hay límite de 2)

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
3. Segunda confirmación
4. Confirmar
**Resultado esperado:**
- [ ] Todos los datos eliminados
- [ ] Vuelve a onboarding (5 pasos)
- [ ] En paso 5 del onboarding puede elegir cargar categorías o no

#### Escenario 13.7: Agregar divisa secundaria carga tipos de cambio históricos
**Precondiciones:**
- Moneda preferida: PEN
- Sin divisas secundarias configuradas
**Pasos:**
1. Profile → Divisa y cambio
2. Agregar USD como divisa secundaria
3. Observar indicador de carga (isUpdating)
4. Esperar a que termine la carga (~10-30 segundos)
5. Ir a Panel → Widget Tipo de Cambio
**Resultado esperado:**
- [ ] Indicador de progreso visible durante carga
- [ ] Widget muestra gráfica de 1 año de USD→PEN
- [ ] Gráfica tiene datos completos (no vacía ni plana)
- [ ] Tipos de cambio actuales visibles en Settings

#### Escenario 13.8: Cambiar divisa secundaria por otra
**Precondiciones:**
- Divisas secundarias: USD, EUR
- Widget muestra gráficas de ambas
**Pasos:**
1. Profile → Divisa y cambio
2. Quitar EUR
3. Agregar GBP
4. Esperar carga de datos históricos
5. Volver a Panel → Widget Tipo de Cambio
**Resultado esperado:**
- [ ] Widget ahora muestra USD y GBP (no EUR)
- [ ] Gráfica de GBP tiene datos históricos de 1 año
- [ ] Selector de divisas en widget refleja cambio

#### Escenario 13.9: Onboarding con divisas secundarias carga datos históricos
**Precondiciones:** App sin datos (data wipe)
**Pasos:**
1. Completar onboarding hasta paso de divisas secundarias
2. Seleccionar PEN como preferida
3. Seleccionar USD y EUR como secundarias
4. Completar onboarding (elegir periodo, categorías, notificaciones)
5. Esperar 5-10 segundos después de dismiss (carga en background)
6. Ir a Panel → Widget Tipo de Cambio
**Resultado esperado:**
- [ ] Widget muestra gráfica de 1 año para USD y EUR
- [ ] Datos históricos completos (no solo punto actual)
- [ ] Usuario no experimentó retraso en onboarding (carga fue en background)

#### Escenario 13.10: Widget sin divisas secundarias muestra todas disponibles
**Precondiciones:**
- Moneda preferida: PEN
- Sin divisas secundarias
**Pasos:**
1. Ir a Panel → Widget Tipo de Cambio
2. Abrir selector de divisas (botón círculo con flechas)
**Resultado esperado:**
- [ ] Selector muestra todas las 6 divisas (USD, EUR, MXN, COP, BRL, GBP)
- [ ] Puede seleccionar hasta 2 para comparar
- [ ] Gráfica muestra las divisas seleccionadas

#### Escenario 13.11: Tipos de cambio se actualizan diariamente
**Precondiciones:**
- App con datos
- Último update de tipos de cambio fue hace 24+ horas
**Pasos:**
1. Abrir app después de 24 horas de inactividad
2. Esperar 2-3 segundos (carga automática en background)
3. Ir a Settings → Divisa y cambio
4. Verificar "Última actualización" al final de la sección
**Resultado esperado:**
- [ ] Fecha de actualización es "hoy"
- [ ] Tipos de cambio reflejan valores actuales
- [ ] Widget en Panel muestra datos actualizados

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

### Escenarios de Pantalla de Éxito (8.1/8.2)

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 16.30 | Aprobar desde editor | Completar campos + Tap "Aprobar" | Pantalla éxito con checkmark, detalles de transacción |
| 16.31 | Editar desde éxito | Tap "Editar" en pantalla éxito | Abre NewTransactionView con la transacción |
| 16.32 | Aceptar desde éxito | Tap "Aceptar" en pantalla éxito | Vuelve a InboxView |
| 16.33 | Aprobar siguiente | Con otro draft pending, tap "Aprobar siguiente" | Abre editor del siguiente draft |
| 16.34 | Aprobar siguiente (único) | Sin más drafts, verificar | Botón "Aprobar siguiente" no visible |
| 16.35 | Swipe approve con éxito | Swipe derecha en draft válido | Pantalla éxito aparece como sheet |
| 16.36 | Bulk approve éxito | Aprobar 3 drafts en lote | Pantalla éxito con "3 transacciones creadas" |
| 16.37 | Ver en registros desde bulk | Tap "Ver en registros" en éxito bulk | Cierra Inbox, navega a Statistics |
| 16.38 | Volver a bandeja desde bulk | Tap "Volver a bandeja" en éxito bulk | Cierra sheet, queda en InboxView |

### Validaciones de UI

| Elemento | Verificación |
|----------|--------------|
| Icono de fuente | Correcto para tipo (voz, recibo, etc.) |
| Indicadores campos faltantes | Chips rojos para account/subcategory/amount |
| Fecha relativa | "Hoy", "Ayer", o fecha formateada |
| Color de monto | Verde/morado para positivo, rosa para negativo |
| Indicador confianza | Triángulo naranja si <70% |

---

## Sección 17: Entrada por Voz (Voz MVP) - V1.1

### Vista: VoiceRecordingView + ProfileView (Settings)

Funcionalidad de entrada de transacciones por voz usando OpenAI Whisper (STT) y GPT-4o-mini (parsing).

### Precondiciones Generales

- API Key de OpenAI configurada en Secrets.xcconfig
- Permiso de micrófono otorgado (o disponible para solicitar)
- Conexión a internet activa

---

### Escenarios de Configuración (ProfileView)

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.1 | Toggle voz deshabilitado (default) | Abrir Profile → Personalización | Toggle "Entrada por voz con IA" está OFF |
| 17.2 | Habilitar entrada por voz | Activar toggle "Entrada por voz con IA" | Toggle ON, selector de idioma aparece |
| 17.3 | Deshabilitar entrada por voz | Desactivar toggle | Toggle OFF, selector de idioma desaparece |
| 17.4 | Selector idioma - Sistema | Con voz habilitada, seleccionar "Sistema" | Usa idioma del dispositivo para transcripción |
| 17.5 | Selector idioma - Español | Seleccionar "Español" | Whisper transcribe en español |
| 17.6 | Selector idioma - Inglés | Seleccionar "English" | Whisper transcribe en inglés |
| 17.7 | Persistencia de configuración | Cerrar y abrir app | Toggle y idioma mantienen valor |

---

### Escenarios de FAB Condicional

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.8 | FAB simple (voz deshabilitada) | Con voz OFF, ver PanelView | FAB "+" abre NewTransactionView directamente |
| 17.9 | FAB menú (voz habilitada) | Con voz ON, tap en FAB "+" en PanelView | Menú con opciones: "Voz" y "Manual" |
| 17.10 | FAB menú en Statistics | Con voz ON, tap en FAB "+" en DetailContainerView | Mismo menú: "Voz" y "Manual" |
| 17.11 | Seleccionar "Manual" del menú | Tap en "Manual" | Abre NewTransactionView |
| 17.12 | Seleccionar "Voz" del menú | Tap en "Voz" | Abre VoiceRecordingView |

---

### Escenarios de Permisos de Micrófono

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.13 | Primera solicitud de permiso | Primera vez que se abre VoiceRecordingView | Alert del sistema pidiendo permiso de micrófono |
| 17.14 | Permiso otorgado | Aceptar permiso | Grabación disponible, botón de grabar activo |
| 17.15 | Permiso denegado | Denegar permiso | Mensaje de error, enlace a Settings |
| 17.16 | Permiso revocado posteriormente | Revocar en Settings del sistema, volver a app | Mensaje indicando que se necesita permiso |

---

### Escenarios de Grabación (VoiceRecordingView)

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.17 | UI inicial | Abrir VoiceRecordingView | Botón grande de micrófono, instrucciones visibles |
| 17.18 | Iniciar grabación | Tap en botón de micrófono | Círculo pulsante, contador de duración inicia (0:00) |
| 17.19 | Contador en tiempo real | Grabar por 5 segundos | Duración muestra 0:05 en tiempo real |
| 17.20 | Detener grabación | Tap en botón durante grabación | Grabación se detiene, inicia procesamiento |
| 17.21 | Estado "Procesando" | Después de detener | Indicador de carga, texto "Procesando..." |
| 17.22 | Cancelar grabación | Tap en X o swipe down durante grabación | Grabación cancelada, sheet se cierra |

---

### Escenarios de Transcripción y Parsing

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.23 | Transcripción exitosa | Grabar "Gasté veinte soles en almuerzo" | Whisper devuelve texto transcrito |
| 17.24 | Parsing de monto | Transcripción con monto | GPT-4o-mini extrae amount: 20.00 |
| 17.25 | Parsing de nota | Transcripción con descripción | Extrae note: "almuerzo" o similar |
| 17.26 | Parsing de fecha implícita | "Gasté ayer..." | Extrae date: fecha de ayer |
| 17.27 | Parsing de tipo (gasto) | "Gasté..." o "Pagué..." | isExpense: true |
| 17.28 | Parsing de tipo (ingreso) | "Me pagaron..." o "Recibí..." | isExpense: false |
| 17.29 | Confidence scores | Después de parsing | Cada campo tiene confidence (0.0-1.0) |

---

### Escenarios de Creación de InboxDraft

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.30 | Draft creado exitosamente | Flujo completo de voz | InboxDraft creado en bandeja |
| 17.31 | Draft con sourceType correcto | Ver draft en Inbox | sourceType = .voice |
| 17.32 | Draft con campos extraídos | Ver draft | amount, note, date poblados según parsing |
| 17.33 | Draft con confidence | Ver indicadores | Campos con confidence <70% muestran indicador |
| 17.34 | Navegación post-creación | Después de crear draft | Sheet se cierra, puede ir a Inbox |
| 17.35 | Toast de confirmación | Después de crear draft | Toast: "Borrador creado" o similar |

---

### Escenarios de Errores

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.36 | Sin conexión a internet | Intentar grabar sin internet | Error claro: "Se requiere conexión a internet" |
| 17.37 | API Key inválida/faltante | Grabar con key incorrecta | Error: "Error de autenticación" |
| 17.38 | Timeout de transcripción | Simular timeout | Error con opción de reintentar |
| 17.39 | Audio muy corto | Grabar <1 segundo | Error: "Grabación muy corta" |
| 17.40 | Audio inaudible/silencio | Grabar silencio | Error o warning: "No se detectó audio" |
| 17.41 | Parsing falla | Transcripción no parseable | Draft creado solo con nota (texto completo) |
| 17.42 | Error de Whisper API | Error 500 de OpenAI | Mensaje de error, opción reintentar |

---

### Escenarios de Localización

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 17.43 | Labels en Español | Dispositivo en ES | "Entrada por voz con IA", "Idioma de voz", etc. |
| 17.44 | Labels en Inglés | Dispositivo en EN | "Voice input with AI", "Voice language", etc. |
| 17.45 | Labels en Alemán | Dispositivo en DE | Textos traducidos correctamente |
| 17.46 | Labels en Francés | Dispositivo en FR | Textos traducidos correctamente |
| 17.47 | Labels en Italiano | Dispositivo en IT | Textos traducidos correctamente |
| 17.48 | Labels en Portugués | Dispositivo en PT | Textos traducidos correctamente |

---

### Validaciones de UI

| Elemento | Verificación |
|----------|--------------|
| Toggle voz | Estilo consistente con otros toggles de Settings |
| Selector idioma | Aparece/desaparece con animación al toggle |
| Botón micrófono | Tamaño grande, fácil de presionar |
| Círculo pulsante | Animación suave durante grabación |
| Contador duración | Formato MM:SS, actualiza cada segundo |
| Estados de carga | Indicadores claros para cada estado |
| Mensajes de error | Texto claro, accionable |

---

## Sección 18: Entrada por Imagen (Imágenes MVP) - V1.1

### Vista: ImageSelectionView + ProfileView (Settings)

Funcionalidad de entrada de transacciones desde imágenes usando Vision OCR + clasificación heurística + extractores.

### Precondiciones Generales

- iOS 16+ (Vision framework)
- Permiso de acceso a fotos otorgado (o disponible para solicitar)
- Imágenes de prueba en biblioteca de fotos

---

### Escenarios de Configuración (ProfileView)

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.1 | Toggle imagen deshabilitado (default) | Abrir Profile → Personalización | Toggle "Entrada por imagen" está OFF |
| 18.2 | Habilitar entrada por imagen | Activar toggle "Entrada por imagen" | Toggle ON |
| 18.3 | Deshabilitar entrada por imagen | Desactivar toggle | Toggle OFF, opción desaparece del FAB |
| 18.4 | Persistencia de configuración | Cerrar y abrir app | Toggle mantiene valor |

---

### Escenarios de FAB Condicional

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.5 | FAB sin imagen (imagen OFF) | Con imagen OFF, ver PanelView | FAB muestra solo opciones habilitadas (Manual o Voz+Manual) |
| 18.6 | FAB con imagen (imagen ON) | Con imagen ON, tap en FAB "+" | Menú muestra "Imagen" con icono naranja |
| 18.7 | FAB con voz+imagen | Con voz ON e imagen ON | Menú muestra 3 opciones: "Voz", "Imagen", "Manual" |
| 18.8 | Seleccionar "Imagen" del menú | Tap en "Imagen" | Abre ImageSelectionView |

---

### Escenarios de Selección de Imagen

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.9 | UI inicial | Abrir ImageSelectionView | Instrucciones, botón "Seleccionar imagen" |
| 18.10 | Abrir PhotosPicker | Tap en botón | PhotosPicker del sistema se abre |
| 18.11 | Cancelar PhotosPicker | Tap en Cancelar en picker | Picker se cierra, vuelve a ImageSelectionView |
| 18.12 | Seleccionar imagen válida | Elegir screenshot bancario | Picker se cierra, inicia procesamiento |
| 18.13 | Estado "Procesando" | Después de seleccionar | ProgressView, texto "Procesando..." |

---

### Escenarios de Procesamiento OCR

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.14 | OCR exitoso - Screenshot single | Seleccionar alerta bancaria individual | Texto extraído, draft creado en Inbox |
| 18.15 | OCR exitoso - Screenshot list | Seleccionar lista de transacciones | Múltiples drafts creados (uno por fila) |
| 18.16 | OCR exitoso - Receipt | Seleccionar foto de recibo | Draft creado con monto total |
| 18.17 | Navegación a Inbox | Después de procesar exitosamente | ImageSelectionView cierra, Inbox se abre automáticamente |

---

### Escenarios de Extracción de Datos

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.18 | Extracción monto con símbolo $ | Imagen con "$50.00" | Draft muestra 50.00 |
| 18.19 | Extracción monto con símbolo € | Imagen con "€100" | Draft muestra 100.00 |
| 18.20 | Extracción monto negativo (paréntesis) | Imagen con "($25.50)" | Draft muestra -25.50 |
| 18.21 | Extracción formato europeo | Imagen con "1.234,56" | Draft muestra 1234.56 |
| 18.22 | Extracción formato americano | Imagen con "1,234.56" | Draft muestra 1234.56 |
| 18.23 | Extracción fecha relativa "hoy" | Imagen con "hoy" | Draft muestra fecha de hoy |
| 18.24 | Extracción fecha relativa "ayer" | Imagen con "ayer" | Draft muestra fecha de ayer |
| 18.25 | Extracción fecha absoluta DD/MM/YYYY | Imagen con "24/01/2026" | Draft muestra 24 enero 2026 |
| 18.26 | Extracción nombre comercio | Imagen con "en STARBUCKS" | Draft nota contiene "Starbucks" |

---

### Escenarios de Clasificación

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.27 | Clasificar screenshot single | Imagen con keywords "consumo", "tarjeta" + 1 monto | Clasificado como screenshotSingle, 1 draft |
| 18.28 | Clasificar screenshot list | Imagen con 3+ líneas con montos | Clasificado como screenshotList, múltiples drafts |
| 18.29 | Clasificar receipt | Imagen con "total", "subtotal" + monto | Clasificado como receiptPhoto, 1 draft |
| 18.30 | Clasificar unknown | Imagen sin montos ni keywords | Error "Tipo de imagen no reconocido" |

---

### Escenarios de Errores

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.31 | Error carga imagen | Seleccionar imagen corrupta | Alert: "No se pudo cargar la imagen" |
| 18.32 | Error OCR sin texto | Seleccionar imagen sin texto | Alert: "No se detectó texto en la imagen" |
| 18.33 | Error sin transacciones | Seleccionar imagen con texto pero sin montos | Alert: "No se detectaron transacciones" |
| 18.34 | Error tipo no reconocido | Seleccionar imagen no bancaria | Alert: "Tipo de imagen no reconocido" |

---

### Escenarios de Integración con Inbox

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.35 | Draft en Inbox | Después de procesar imagen | Draft aparece en InboxView con sourceType correcto |
| 18.36 | Icono de fuente correcto | Ver draft en Inbox | Icono "rectangle.on.rectangle" para screenshot single |
| 18.37 | Icono lista | Ver drafts de screenshot list | Icono "list.bullet.rectangle" |
| 18.38 | Raw text preservado | Abrir draft | rawText contiene texto OCR completo |
| 18.39 | Evidence visible | Ver draft | evidence muestra primera línea de texto |
| 18.40 | Campos detectados | Ver draft | amount, date (si detectados) marcados con confianza |

---

### Validaciones de UI

| Elemento | Verificación |
|----------|--------------|
| Toggle imagen | Estilo consistente con otros toggles de Settings |
| Icono FAB | "photo" naranja en menú |
| Botón selección | Tamaño grande, fácil de presionar |
| PhotosPicker | Picker nativo del sistema |
| ProgressView | Indicador de carga durante procesamiento |
| Estados de error | Alertas claras con texto accionable |
| Transición a Inbox | Animación suave al abrir Inbox |

---

### Escenarios de Vision API (GPT-4o Online)

Nueva funcionalidad: procesamiento de imágenes usando GPT-4o Vision para mejor precisión en extracción.

**Precondiciones específicas:**
- API key de OpenAI configurada en Secrets.xcconfig
- Conexión a internet activa

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.41 | Vision API disponible | Con API key configurada, procesar imagen | Usa Vision API (no OCR local) |
| 18.42 | Vision API no disponible | Sin API key configurada, procesar imagen | Fallback automático a OCR local |
| 18.43 | Vision exitoso - Screenshot single | Seleccionar alerta bancaria | Draft creado con datos de Vision, sourceType=screenshotSingle |
| 18.44 | Vision exitoso - Screenshot list | Seleccionar historial bancario | Múltiples drafts creados, sourceType=screenshotList |
| 18.45 | Vision exitoso - Receipt | Seleccionar foto de recibo | Draft con TOTAL extraído, sourceType=receiptPhoto |
| 18.46 | Vision - Monto negativo (gasto) | Imagen con gasto | amount < 0 en draft |
| 18.47 | Vision - Monto positivo (ingreso) | Imagen con ingreso | amount > 0 en draft |
| 18.48 | Vision - Fecha formato ES abreviado | Imagen con "13 ene 2026" | date = 2026-01-13 |
| 18.49 | Vision - Fecha formato ES completo | Imagen con "13 de enero de 2026" | date = 2026-01-13 |
| 18.50 | Vision - Fecha formato EN | Imagen con "Jan 13, 2026" | date = 2026-01-13 |
| 18.51 | Vision - Fecha relativa "hoy" | Imagen con "hoy" | date = fecha actual |
| 18.52 | Vision - Fecha relativa "ayer" | Imagen con "ayer" | date = fecha actual - 1 |
| 18.53 | Vision - Merchant extraído | Imagen con comercio | note contiene nombre del comercio |

---

### Escenarios de Fallback Vision → OCR

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 18.54 | Fallback por error de red | Desconectar internet durante proceso | Cae a OCR local, draft creado |
| 18.55 | Fallback por respuesta vacía | Vision retorna imageType=unknown | Cae a OCR local |
| 18.56 | Fallback por sin transacciones | Vision retorna transactions=[] | Cae a OCR local |
| 18.57 | Fallback exitoso | Error de Vision + OCR funciona | Draft creado vía OCR, sin error visible |
| 18.58 | Ambos fallan | Error de Vision + Error de OCR | Muestra error "No se detectaron transacciones" |

---

### Validaciones de Vision API

| Elemento | Verificación |
|----------|--------------|
| Confidencia | confidence.overall en respuesta ≥ 0.7 |
| JSON válido | Respuesta parseable como VisionResponse |
| Montos firmados | Gastos negativos, ingresos positivos |
| Fechas ISO | Formato YYYY-MM-DD interno |
| Fallback silencioso | Usuario no ve mensaje de error de Vision si OCR funciona |

---

## Sección 19: Merchant Memory (Subfase 8.5)

### Precondiciones
- Al menos 1 cuenta creada
- Al menos 1 subcategoría visible
- Input de voz o imagen funcional (API key configurada)

### 19.1 Canonicalización de Merchants

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 1 | Normalización básica | Aprobar draft con nota "Starbucks Coffee" → aprobar otro con "STARBUCKS COFFEE" | Ambos mapean a la misma memoria de comercio |
| 2 | Prefijos de pago | Aprobar draft con nota "DP*Uber Eats" | La memoria guarda "UBER EATS" (sin prefijo DP*) |
| 3 | Símbolos y espacios | Aprobar draft con nota "Pizza Hut #123" | La memoria guarda "PIZZA HUT 123" (sin #) |

### 19.2 Sugerencia de Subcategoría

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 4 | Sin sugerencia (<3 aprobaciones) | Aprobar 2 drafts de "Starbucks" con subcategoría "Café" → crear nuevo draft "Starbucks" | NO se sugiere subcategoría automáticamente |
| 5 | Sugerencia (>=3 aprobaciones) | Aprobar 3 drafts de "Starbucks" con subcategoría "Café" → abrir nuevo draft "Starbucks" | Subcategoría "Café" aparece preseleccionada |
| 6 | Autoasignación (>=5, baja corrección) | Aprobar 5 drafts de "Starbucks" con "Café" sin corregir → crear nuevo draft | Subcategoría autoasignada en el draft |
| 7 | Corrección reduce confianza | Aprobar 3 con "Café", cambiar 2 a "Restaurantes" → nuevo draft | No sugiere (tasa corrección alta) |

### 19.3 Integración con Voz

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 8 | Voice draft con memoria | Tener 5+ aprobaciones para "Uber" → grabar "gasté 50 en Uber" | Draft creado con subcategoría prefilled de merchant memory |
| 9 | LLM hint tiene prioridad | LLM sugiere subcategoría + merchant memory sugiere otra | Se usa la del LLM (merchant memory es fallback) |

### 19.4 Integración con Imágenes

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 10 | Image draft con memoria | Tener 5+ aprobaciones para merchant → procesar imagen con ese merchant | Draft(s) creados con subcategoría prefilled |

### 19.5 Corrección y Aprendizaje

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 11 | Corrección registrada | Abrir draft con subcategoría sugerida → cambiar a otra → aprobar | Memory registra corrección, countCorrected incrementa |
| 12 | Aprobación sin corrección | Abrir draft con subcategoría sugerida → aprobar sin cambiar | countApproved incrementa |

### 19.6 Data Wipe

| # | Escenario | Pasos | Verificación |
|---|-----------|-------|--------------|
| 13 | Wipe limpia memoria | Tener memorias de comercios → vaciar datos | Todas las memorias eliminadas, sin crash |

## Sección 20: Seguridad Biométrica (Fase 9)

### Precondiciones
- Dispositivo con Face ID, Touch ID, o passcode configurado
- App instalada y onboarding completado

### Escenario 20.1: Activar bloqueo biométrico
1. Ir a Perfil → Seguridad → Face ID / Touch ID
2. Activar toggle "Activar bloqueo"
3. **Verificar:** Sistema pide autenticación biométrica/passcode antes de activar
4. **Verificar:** Toggle queda encendido tras autenticación exitosa
5. **Verificar:** Si se cancela la autenticación, toggle vuelve a apagado

### Escenario 20.2: Configurar tiempo de bloqueo
1. Con bloqueo activado, verificar que aparece selector de tiempo
2. Seleccionar cada opción: Inmediatamente, 1 min, 5 min, 15 min
3. **Verificar:** Checkmark se mueve a la opción seleccionada
4. **Verificar:** La preferencia persiste al cerrar y reabrir Settings

### Escenario 20.3: Bloqueo al abrir la app
1. Activar bloqueo con timeout "Inmediatamente"
2. Cerrar la app completamente (kill)
3. Abrir la app
4. **Verificar:** Overlay de bloqueo aparece después del splash
5. **Verificar:** Se muestra icono correcto (Face ID / Touch ID / Lock)
6. **Verificar:** Botón "Desbloquear" visible
7. Autenticarse correctamente
8. **Verificar:** Overlay desaparece y se ve la app

### Escenario 20.4: Bloqueo al volver del background
1. Activar bloqueo con timeout "Inmediatamente"
2. Poner app en background (Home button / swipe up)
3. Esperar unos segundos
4. Volver a la app
5. **Verificar:** Overlay de bloqueo aparece
6. Autenticarse correctamente
7. **Verificar:** App desbloqueada

### Escenario 20.5: Timeout de bloqueo respetado
1. Activar bloqueo con timeout "5 minutos"
2. Poner app en background
3. Volver en menos de 5 minutos
4. **Verificar:** App NO muestra overlay de bloqueo
5. Poner app en background nuevamente
6. Esperar más de 5 minutos
7. Volver a la app
8. **Verificar:** Overlay de bloqueo aparece

### Escenario 20.6: Fallback a passcode del dispositivo
1. Con bloqueo activado, intentar desbloquear
2. Fallar la autenticación biométrica varias veces
3. **Verificar:** iOS ofrece automáticamente ingresar passcode del dispositivo
4. Ingresar passcode correcto
5. **Verificar:** App se desbloquea

### Escenario 20.7: Desactivar bloqueo
1. Ir a Perfil → Seguridad → Face ID / Touch ID
2. Desactivar toggle
3. **Verificar:** Bloqueo desactivado sin pedir autenticación
4. Cerrar y reabrir app
5. **Verificar:** No aparece overlay de bloqueo

### Escenario 20.8: Icono dinámico en Settings
1. En dispositivo con Face ID: verificar icono "faceid" en la fila de seguridad
2. En dispositivo con Touch ID: verificar icono "touchid"
3. **Verificar:** El texto del título coincide con el tipo de biométrico

### Escenario 20.9: Localizaciones
1. Cambiar idioma del dispositivo a cada uno de los 6 idiomas soportados
2. **Verificar:** Todos los textos de la vista de seguridad biométrica están traducidos
3. **Verificar:** Textos del overlay de bloqueo están traducidos

---

## Sección 21: Refinamiento Registro Inteligente (Fase 10)

### Escenario 21.1: Tildes no crean etiquetas duplicadas (voz)
1. Crear manualmente una etiqueta llamada "cafe"
2. Activar entrada por voz y decir: "gasto de 5 soles con etiqueta café" (con tilde)
3. **Verificar:** Se reutiliza la etiqueta existente "cafe", no se crea "Café" como duplicada
4. Verificar en Perfil → Etiquetas que solo existe una etiqueta

### Escenario 21.2: Tildes no crean subcategorías duplicadas (voz)
1. Tener subcategoría existente "Transporte publico"
2. Dictar por voz: "gasto de 3 soles en transporte público" (con tilde)
3. **Verificar:** Se asigna la subcategoría existente, no se crea match fallido

### Escenario 21.3: Matching parcial con tildes (voz)
1. Tener etiqueta "viaje"
2. Dictar: "gasto con etiqueta viáje" (con tilde en la a)
3. **Verificar:** Match correcto con etiqueta "viaje" existente

### Escenario 21.4: FAB con imagen en Statistics (DetailContainerView)
1. Activar entrada de imagen en Perfil → Preferencias
2. Ir a Statistics → Records tab
3. Tocar el FAB (+)
4. **Verificar:** Menú muestra opciones: Voz (si habilitada), Imagen (teal), Manual (rosa)
5. Tocar "Imagen"
6. **Verificar:** Se abre ImageSelectionView correctamente

### Escenario 21.5: FAB solo imagen en Statistics
1. Activar solo imagen (desactivar voz) en Preferencias
2. Ir a Statistics → Records tab
3. Tocar FAB
4. **Verificar:** Menú muestra: Imagen (teal) y Manual (rosa), sin opción de Voz

### Escenario 21.6: FAB sin inputs especiales en Statistics
1. Desactivar voz e imagen en Preferencias
2. Ir a Statistics → Records tab
3. **Verificar:** FAB es botón simple (+) que abre transacción manual directamente

### Escenario 21.7: Permiso micrófono al activar toggle
1. Ir a Perfil → Preferencias
2. Activar toggle "Entrada de voz" (primera vez, permiso no determinado)
3. **Verificar:** iOS muestra diálogo de permiso de micrófono
4. Aceptar permiso
5. **Verificar:** Toggle queda activado

### Escenario 21.8: Permiso micrófono denegado
1. Denegar permiso de micrófono desde Ajustes del sistema
2. Ir a Perfil → Preferencias
3. Activar toggle "Entrada de voz"
4. **Verificar:** Aparece alerta con mensaje de permiso denegado
5. **Verificar:** Botón "Abrir Ajustes" redirige a Settings del sistema
6. **Verificar:** Botón "Cancelar" cierra la alerta

### Escenario 21.9: Permiso fotos al activar toggle
1. Ir a Perfil → Preferencias
2. Activar toggle "Entrada de imagen" (primera vez)
3. **Verificar:** iOS muestra diálogo de permiso de fotos
4. Aceptar permiso
5. **Verificar:** Toggle queda activado

### Escenario 21.10: Permiso fotos denegado
1. Denegar permiso de fotos desde Ajustes del sistema
2. Ir a Perfil → Preferencias
3. Activar toggle "Entrada de imagen"
4. **Verificar:** Aparece alerta con mensaje de permiso denegado
5. **Verificar:** Botón "Abrir Ajustes" redirige a Settings del sistema

---

## Sección 22: Atajos de iOS (App Intents)

### Escenario 22.1: Shortcut visible en app Atajos
1. Abrir la app Atajos de iOS
2. Ir a pestaña "Galería" o buscar "Yala"
3. **Verificar:** Aparece el atajo "Gasto rápido" (o "Quick expense" en inglés)
4. **Verificar:** Icono del atajo muestra símbolo de minus en círculo

### Escenario 22.2: Flujo completo de gasto rápido
1. En app Atajos, crear nuevo atajo
2. Buscar "Yala" y seleccionar "Registrar gasto rápido"
3. Ejecutar el atajo
4. **Verificar:** Pregunta "¿Cuánto gastaste?" - ingresar 50
5. **Verificar:** Pregunta "¿Qué compraste?" - ingresar "Starbucks"
6. **Verificar:** Pregunta "¿En qué cuenta?" - seleccionar cuenta
7. **Verificar:** Pregunta "¿Qué tipo de gasto?" - seleccionar subcategoría
8. **Verificar:** Pregunta "¿Quieres añadir una etiqueta?" - seleccionar o saltar
9. **Verificar:** Mensaje final muestra: "Gasto registrado en [cuenta]: [divisa] 50.00 - Starbucks - [subcategoría] - [etiqueta o Sin etiqueta]"
10. Abrir Yala → Records
11. **Verificar:** Transacción existe con todos los datos correctos

### Escenario 22.3: Atajo con etiqueta
1. Crear atajo y completar flujo hasta etiqueta
2. Seleccionar una etiqueta existente
3. **Verificar:** Mensaje final incluye nombre de la etiqueta
4. **Verificar:** Transacción en Yala tiene la etiqueta asignada

### Escenario 22.4: Atajo sin etiqueta
1. Crear atajo y completar flujo
2. En paso de etiqueta, no seleccionar ninguna (skip)
3. **Verificar:** Mensaje final muestra "Sin etiqueta"
4. **Verificar:** Transacción en Yala no tiene etiquetas

### Escenario 22.5: Descripción vacía
1. En paso "¿Qué compraste?" dejar vacío
2. Completar resto del flujo
3. **Verificar:** Mensaje final muestra "-" en lugar de descripción
4. **Verificar:** Transacción en Yala tiene nota vacía

### Escenario 22.6: Error si no hay cuentas
1. Eliminar o archivar todas las cuentas
2. Ejecutar atajo de gasto rápido
3. **Verificar:** Mensaje de error indica que no hay cuentas disponibles

### Escenario 22.7: Frases Siri español
1. Activar Siri
2. Decir: "Registra un gasto en Yala"
3. **Verificar:** Siri inicia el flujo de preguntas
4. Responder las preguntas de forma conversacional
5. **Verificar:** Transacción creada exitosamente con mensaje detallado

### Escenario 22.8: Frases Siri inglés
1. Configurar Siri en inglés
2. Decir: "Record an expense in Yala"
3. **Verificar:** Siri reconoce el comando y procesa el flujo

### Escenario 22.9: Multimoneda en atajos
1. Tener cuentas en diferentes monedas (ej: PEN, USD)
2. Ejecutar atajo y seleccionar cuenta en USD
3. **Verificar:** Mensaje final muestra divisa correcta (USD)
4. **Verificar:** amountInPreferredCurrency se calcula correctamente

### Escenario 22.10: Subcategorías solo de gastos
1. Crear atajo y llegar al paso de subcategoría
2. **Verificar:** Lista muestra solo subcategorías de categorías de gasto
3. **Verificar:** No aparecen subcategorías de categorías de ingreso

### Escenario 22.11: Atajo "Registro por voz" con toggle activo
1. Activar toggle "Entrada por voz" en Ajustes > Personalización
2. Abrir app Shortcuts y ejecutar "Registro por voz"
3. **Verificar:** App se abre y muestra VoiceRecordingSheet
4. **Verificar:** Puedo dictar y registrar transacción

### Escenario 22.12: Atajo "Registro por voz" con toggle desactivado
1. Desactivar toggle "Entrada por voz" en Ajustes > Personalización
2. Abrir app Shortcuts y ejecutar "Registro por voz"
3. **Verificar:** Mensaje: "No has activado la entrada por voz..."
4. **Verificar:** App NO se abre

### Escenario 22.13: Atajo "Registro por imagen" con toggle activo
1. Activar toggle "Entrada por imagen" en Ajustes > Personalización
2. Abrir app Shortcuts y ejecutar "Registro por imagen"
3. **Verificar:** App se abre y muestra ImageSelectionView
4. **Verificar:** Puedo seleccionar imagen y procesarla

### Escenario 22.14: Atajo "Registro por imagen" con toggle desactivado
1. Desactivar toggle "Entrada por imagen" en Ajustes > Personalización
2. Abrir app Shortcuts y ejecutar "Registro por imagen"
3. **Verificar:** Mensaje: "No has activado la entrada por imagen..."
4. **Verificar:** App NO se abre

### Escenario 22.15: Búsqueda inteligente de etiquetas
1. Tener etiqueta "Devolución" creada
2. Ejecutar atajo "Registro rápido"
3. En paso de etiqueta, escribir "devolucion" (sin tilde, minúscula)
4. **Verificar:** Encuentra y asigna etiqueta "Devolución"

---

## Sección 23: Automatización Apple Pay (App Intent)

### Escenario 23.1: Atajo visible en app Atajos
1. Abrir la app Atajos de iOS
2. Buscar "Yala" en la galería o crear nuevo atajo
3. **Verificar:** Aparece acción "Registro Apple Pay" (o "Apple Pay Entry")
4. **Verificar:** Descripción indica que crea borrador en bandeja de entrada

### Escenario 23.2: Flujo básico - comercio nuevo
1. Crear atajo con acción "Registro Apple Pay"
2. Configurar parámetros: Monto=50, Comercio="Starbucks"
3. Ejecutar el atajo
4. **Verificar:** Mensaje confirma creación del borrador
5. Abrir Yala → Panel → Bandeja de entrada
6. **Verificar:** Existe draft con monto -50, nota "Starbucks"
7. **Verificar:** Icono Apple logo junto al draft
8. **Verificar:** Subcategoría vacía (comercio nuevo, sin memoria)
9. **Verificar:** Campo account puede estar vacío si hay múltiples cuentas

### Escenario 23.3: Auto-asignación de cuenta por divisa única
1. Tener solo UNA cuenta en USD
2. Ejecutar atajo con Monto=25, Comercio="Amazon", Divisa="USD"
3. Abrir bandeja de entrada
4. **Verificar:** Draft tiene cuenta USD asignada automáticamente
5. **Verificar:** needsUserInput NO incluye "account"

### Escenario 23.4: Múltiples cuentas misma divisa - sin auto-asignar
1. Tener DOS cuentas en PEN (ej: "Efectivo PEN" y "BCP PEN")
2. Ejecutar atajo con Monto=100, Comercio="Wong", Divisa="PEN"
3. Abrir bandeja de entrada
4. **Verificar:** Draft NO tiene cuenta asignada
5. **Verificar:** needsUserInput incluye "account"
6. **Verificar:** Usuario puede seleccionar cuenta al aprobar

### Escenario 23.5: Auto-categorización con Merchant Memory
**Precondición:** Tener MerchantMemory para "Starbucks" con ≥5 aprobaciones
1. Ejecutar atajo con Monto=30, Comercio="STARBUCKS LIMA"
2. Abrir bandeja de entrada
3. **Verificar:** Draft tiene subcategoría asignada automáticamente
4. **Verificar:** confidenceSubcategory = 0.8
5. Aprobar draft sin cambiar subcategoría
6. **Verificar:** MerchantMemory.countApproved incrementa

### Escenario 23.6: Sugerencia con Merchant Memory (confianza media)
**Precondición:** Tener MerchantMemory para "McDonalds" con 3-4 aprobaciones
1. Ejecutar atajo con Monto=20, Comercio="McDonalds"
2. Abrir bandeja de entrada
3. **Verificar:** Draft tiene subcategoría sugerida
4. **Verificar:** needsUserInput aún incluye "subcategory" (requiere confirmación)
5. Aprobar confirmando la subcategoría

### Escenario 23.7: Fecha opcional - con fecha
1. Ejecutar atajo con Monto=75, Comercio="Ripley", Fecha=ayer
2. Abrir bandeja de entrada
3. **Verificar:** Draft.date = fecha de ayer
4. **Verificar:** confidenceDate = 1.0

### Escenario 23.8: Fecha opcional - sin fecha
1. Ejecutar atajo con Monto=40, Comercio="Plaza Vea" (sin fecha)
2. Abrir bandeja de entrada
3. **Verificar:** Draft.date = ahora (momento de ejecución)
4. **Verificar:** confidenceDate = nil

### Escenario 23.9: Monto siempre negativo
1. Ejecutar atajo con Monto=100 (positivo)
2. Abrir bandeja de entrada
3. **Verificar:** Draft.amount = -100 (se convierte a gasto)
4. **Verificar:** Al aprobar, transacción es gasto

### Escenario 23.10: Notificación al abrir app
1. Ejecutar atajo Apple Pay con pantalla bloqueada
2. **Verificar:** Atajo completa sin abrir la app
3. Desbloquear y abrir Yala
4. **Verificar:** Badge en Inbox o notificación visible (igual que pagos planificados)

### Escenario 23.11: Error de base de datos
1. Simular error de acceso a BD (difícil de reproducir manualmente)
2. **Verificar:** Mensaje de error indica problema de base de datos

---

*Documento creado: 2026-01-20*
*Última actualización: 2026-01-28 - Sección 23 (Apple Pay)*
*Última actualización: 2026-01-28*
*Total escenarios: ~410*
*Total verificaciones: ~780+*

---

## Sección 24: Sistema de Notificaciones

**Objetivo:** Verificar el sistema de notificaciones personalizables

### Escenario 24.1: Primer inicio - Seed de notificaciones default
**Precondición:** App recién instalada o datos borrados
1. Abrir la app por primera vez
2. Ir a Perfil > Notificaciones
3. **Verificar:** Hay 5 notificaciones predefinidas:
   - Al final del día (20:00, activa)
   - Hora de almuerzo (12:30, inactiva)
   - Reporte semanal (09:00, inactiva)
   - Pagos planificados (09:00, activa)
   - Novedades de Yala (10:00, inactiva)
4. **Verificar:** Cada notificación muestra icono, nombre, hora y texto

### Escenario 24.2: Activar notificación - Solicita permiso
**Precondición:** Permisos de notificación no otorgados
1. Ir a Perfil > Notificaciones
2. Activar toggle de una notificación inactiva
3. **Verificar:** Sistema solicita permiso de notificaciones
4. Aceptar permiso
5. **Verificar:** Toggle queda activo
6. **Verificar:** Notificación programada (verificar en Configuración > Notificaciones)

### Escenario 24.3: Activar notificación - Permiso denegado
**Precondición:** Permisos de notificación previamente denegados
1. Ir a Perfil > Notificaciones
2. Activar toggle de una notificación
3. **Verificar:** Aparece alerta indicando que debe activar permisos en Configuración
4. **Verificar:** Toggle vuelve a inactivo automáticamente

### Escenario 24.4: Editar notificación default
1. Ir a Perfil > Notificaciones
2. Tocar "Al final del día"
3. Cambiar nombre a "Cierre del día"
4. Cambiar texto a "¿Cómo te fue hoy?"
5. Cambiar hora a 21:00
6. Guardar
7. **Verificar:** Card muestra nuevos valores
8. **Verificar:** Si estaba activa, notificación reprogramada

### Escenario 24.5: Crear notificación personalizada
1. Ir a Perfil > Notificaciones
2. Tocar botón "+" en toolbar
3. Completar:
   - Nombre: "Recordatorio mañana"
   - Texto: "Anota tu café matutino"
   - Hora: 08:00
4. Guardar
5. **Verificar:** Nueva notificación aparece en la lista
6. **Verificar:** Tiene icono cyan (color default de custom)
7. **Verificar:** Toggle activo por defecto

### Escenario 24.6: Eliminar notificación personalizada
1. Crear notificación personalizada (escenario 24.5)
2. Hacer swipe izquierda en la card
3. **Verificar:** Aparece botón "Eliminar" rojo
4. Tocar "Eliminar"
5. **Verificar:** Notificación desaparece de la lista
6. **Verificar:** Notificación cancelada del sistema

### Escenario 24.7: No se pueden eliminar notificaciones default
1. Ir a Perfil > Notificaciones
2. Hacer swipe izquierda en "Al final del día"
3. **Verificar:** NO aparece botón de eliminar
4. **Verificar:** Solo se puede editar (tocando la card)

### Escenario 24.8: Límite de caracteres en nombre
1. Crear/editar notificación
2. Escribir nombre de más de 30 caracteres
3. **Verificar:** Se trunca a 30 caracteres
4. **Verificar:** Contador muestra "0 caracteres restantes"
5. **Verificar:** Contador cambia a naranja cuando quedan < 10

### Escenario 24.9: Límite de caracteres en texto
1. Crear/editar notificación
2. Escribir texto de más de 100 caracteres
3. **Verificar:** Se trunca a 100 caracteres
4. **Verificar:** Contador muestra "0 caracteres restantes"
5. **Verificar:** Contador cambia a naranja cuando quedan < 20

### Escenario 24.10: Configuración de Reporte semanal
1. Ir a Perfil > Notificaciones
2. Tocar "Reporte semanal"
3. **Verificar:** Aparece sección "¿Qué incluir en el reporte?"
4. **Verificar:** 4 opciones con toggle:
   - Saldo actual
   - Total de gastos
   - Total de ingresos
   - Categoría con más gasto
5. Desactivar "Saldo actual" y "Total de ingresos"
6. Guardar
7. Volver a abrir
8. **Verificar:** Configuración persiste

### Escenario 24.11: Desactivar notificación activa
1. Tener una notificación activa y programada
2. Ir a Perfil > Notificaciones
3. Desactivar el toggle
4. **Verificar:** Toggle queda inactivo
5. **Verificar:** Notificación cancelada del sistema

### Escenario 24.12: Empty state
**Precondición:** Eliminar todas las notificaciones personalizadas y desactivar todas las default
1. Ir a Perfil > Notificaciones
2. **Verificar:** Muestra lista de notificaciones (default no se eliminan)
3. Nota: El empty state solo aparece si por algún motivo no hay notificaciones (raro)

### Escenario 24.13: Persistencia tras cierre de app
1. Configurar varias notificaciones con diferentes horarios
2. Cerrar la app completamente
3. Reabrir la app
4. Ir a Perfil > Notificaciones
5. **Verificar:** Todas las configuraciones persisten
6. **Verificar:** Notificaciones activas siguen programadas

### Escenario 24.14: Recibir notificación
**Precondición:** Notificación "Al final del día" activa a una hora próxima
1. Activar notificación con hora en 1-2 minutos
2. Cerrar la app
3. Esperar a la hora programada
4. **Verificar:** Recibir notificación push
5. **Verificar:** Título = "Yala"
6. **Verificar:** Texto = el configurado

### Escenario 24.15: Vaciar datos - Notificaciones se recrean
1. Ir a Perfil > Vaciar datos
2. Confirmar borrado
3. Ir a Perfil > Notificaciones
4. **Verificar:** 5 notificaciones default recreadas
5. **Verificar:** Notificaciones personalizadas eliminadas

---

## Sección 25: Fase 10.5.B y 10.5.C - Pendiente de Validación Manual

> **Estado:** PENDIENTE DE VALIDACIÓN
> **Fecha implementación:** 2026-02-01
> **Build:** Compilación exitosa

### 25.1 Consistencia Visual Pagos Planificados (10.5.B)

#### Escenario 25.1.1: Summary Card sin gradientes
**Precondición:** Tener al menos 1 pago planificado activo

1. Ir a Planning > Pagos Planificados
2. **Verificar:** El monto total en el summary card usa color primario (texto normal), NO gradiente electricIndigo→hotPink
3. **Verificar:** El borde del card es gris sutil (secondary.opacity(0.15)), NO gradiente
4. **Verificar:** La sombra es neutra (negra sutil), NO coloreada en índigo

#### Escenario 25.1.2: Section headers simplificados
**Precondición:** Tener pagos en diferentes estados (vencidos, hoy, próximos)

1. Ir a Planning > Pagos Planificados (vista lista)
2. **Verificar:** Solo la sección "Vencidos" tiene círculo rojo (hotPink) junto al título
3. **Verificar:** Secciones "Hoy" y "Próximos" NO tienen círculo de color
4. **Verificar:** NO hay contador "(N)" después del título de sección

#### Escenario 25.1.3: Due status en cards simplificado
**Precondición:** Tener pagos vencidos y próximos

1. Observar las cards de pagos individuales
2. **Verificar:** Pagos vencidos muestran texto en hotPink con círculo rojo
3. **Verificar:** Pagos "Hoy" y "Próximos" muestran texto en color secundario (gris), SIN círculo
4. **Verificar:** Ingresos planificados siguen mostrando monto en teal (esto NO cambió)

#### Escenario 25.1.4: Botones navegación calendario
**Precondición:** Estar en vista calendario de pagos

1. Ir a Planning > Pagos Planificados > Vista calendario
2. **Verificar:** Botones chevron izquierda/derecha son solo iconos grises
3. **Verificar:** NO tienen fondo coloreado (antes tenían fondo índigo claro)

#### Escenario 25.1.5: Comparación con Presupuestos
1. Ir a Planning > Presupuestos y observar el diseño
2. Ir a Planning > Pagos Planificados
3. **Verificar:** Ambas vistas tienen estilo visual consistente (sobrio, sin gradientes llamativos)

---

### 25.2 Onboarding Divisas con Continentes (10.5.C.3)

#### Escenario 25.2.1: Sección Recomendada
**Precondición:** Datos vacíos (data wipe) para ver onboarding

1. Ir a Perfil > Vaciar datos > Confirmar
2. Reiniciar la app para ver onboarding
3. Avanzar hasta el paso "Tu moneda principal"
4. **Verificar:** Hay una sección "RECOMENDADA" al inicio
5. **Verificar:** La moneda recomendada está destacada (fondo índigo claro)
6. **Verificar:** La moneda mostrada coincide con la región del dispositivo (ej: PEN para Perú)

#### Escenario 25.2.2: Agrupación por continentes
1. En el paso de moneda del onboarding
2. Hacer scroll hacia abajo
3. **Verificar:** Las monedas están agrupadas por continente (Latinoamérica, Europa, Asia, etc.)
4. **Verificar:** Cada continente tiene su header en mayúsculas
5. **Verificar:** Las monedas dentro de cada continente están ordenadas alfabéticamente

#### Escenario 25.2.3: No duplicación de moneda recomendada
**Precondición:** Región del dispositivo = Perú (o cualquier otra)

1. En el paso de moneda del onboarding
2. Verificar que PEN aparece en sección "RECOMENDADA"
3. Hacer scroll a la sección "LATINOAMÉRICA"
4. **Verificar:** PEN NO aparece duplicado en Latinoamérica
5. **Verificar:** El resto de monedas latinoamericanas SÍ aparecen

---

### 25.3 Filtro Monedas Solo con Transacciones (10.5.C.2)

#### Escenario 25.3.1: Filtro muestra solo monedas usadas
**Precondición:** Tener transacciones solo en PEN y USD

1. Ir a Statistics > Filtros
2. Buscar la sección "Moneda"
3. **Verificar:** Solo aparecen PEN y USD como opciones
4. **Verificar:** NO aparecen las 48 monedas soportadas

#### Escenario 25.3.2: Nueva moneda aparece al usarla
**Precondición:** Tener transacciones solo en PEN

1. Verificar que en Filtros > Moneda solo aparece PEN
2. Crear una cuenta en EUR
3. Crear una transacción en esa cuenta EUR
4. Ir a Statistics > Filtros > Moneda
5. **Verificar:** Ahora aparecen PEN y EUR

#### Escenario 25.3.3: Sección oculta sin transacciones
**Precondición:** Datos vacíos (sin transacciones)

1. Ir a Perfil > Vaciar datos > Confirmar (o usar app recién instalada)
2. Completar onboarding
3. Ir a Statistics > Filtros
4. **Verificar:** La sección "Moneda" NO aparece (está oculta)
5. Crear una transacción
6. Volver a Statistics > Filtros
7. **Verificar:** Ahora SÍ aparece la sección "Moneda"

---

### 25.4 Ejemplos Voz con Moneda Dinámica (10.5.C.1)

#### Escenario 25.4.1: Ejemplos con moneda preferida
**Precondición:** Moneda preferida = Sol peruano (PEN)

1. Ir a Settings > Moneda preferida, verificar que es PEN
2. Abrir FAB > Voz
3. Observar la sección de hints y ejemplos
4. **Verificar:** El hint de monto dice "50 soles" (plural, sin país)
5. **Verificar:** Ejemplo 1: "Gasto de 50 soles en Starbucks para café"
6. **Verificar:** Ejemplo 2: "Ingreso de 1000 soles por trabajo freelance"
7. **Verificar:** Ejemplo 3: "Transferencia de 200 soles a cuenta de ahorros"

#### Escenario 25.4.2: Ejemplos cambian con otra moneda
1. Ir a Settings > Moneda preferida > Cambiar a Euro (EUR)
2. Abrir FAB > Voz
3. **Verificar:** El hint de monto dice "50 euros"
4. **Verificar:** Los ejemplos dicen "euros" en lugar de "soles"

#### Escenario 25.4.3: Ejemplos con dólar
1. Ir a Settings > Moneda preferida > Cambiar a Dólar estadounidense (USD)
2. Abrir FAB > Voz
3. **Verificar:** El hint dice "50 dólares" (sin "estadounidenses")
4. **Verificar:** Los ejemplos dicen "dólares"

#### Escenario 25.4.4: Ejemplos con pesos (múltiples países)
1. Ir a Settings > Moneda preferida > Cambiar a Peso mexicano (MXN)
2. Abrir FAB > Voz
3. **Verificar:** El hint dice "50 pesos" (sin "mexicanos")
4. Cambiar a Peso colombiano (COP)
5. **Verificar:** También dice "50 pesos" (igual que mexicano)

#### Escenario 25.4.5: Validar en otros idiomas
1. Cambiar idioma del dispositivo a English
2. Abrir FAB > Voz
3. **Verificar:** Ejemplos en inglés con la moneda correcta (ej: "50 dollars")
4. Repetir con alemán, francés, italiano, portugués

### 25.5 Divisas Secundarias con Recomendadas (10.5.C.4)

#### Escenario 25.5.1: Sección Recomendadas visible
**Precondición:** Moneda preferida = PEN (o cualquier no-USD/EUR/GBP)

1. Ir a Settings > Divisas > Divisas secundarias
2. **Verificar:** Sección "RECOMENDADAS" aparece antes de los continentes
3. **Verificar:** Muestra USD, EUR, GBP con fondo índigo claro
4. **Verificar:** Las 3 monedas NO aparecen en sus continentes (Norteamérica/Europa)

#### Escenario 25.5.2: Excluye moneda preferida
**Precondición:** Moneda preferida = USD

1. Ir a Settings > Divisas > Divisas secundarias
2. **Verificar:** Sección Recomendadas muestra solo EUR y GBP (sin USD)

#### Escenario 25.5.3: Excluye monedas ya seleccionadas
**Precondición:** EUR ya seleccionada como secundaria

1. Ir a Settings > Divisas > Divisas secundarias
2. **Verificar:** Sección Recomendadas muestra USD y GBP (sin EUR)
3. **Verificar:** EUR aparece en sección "Seleccionadas"

#### Escenario 25.5.4: Sección oculta si no hay recomendadas disponibles
**Precondición:** Preferida = USD, Secundarias = EUR y GBP

1. Ir a Settings > Divisas > Divisas secundarias
2. **Verificar:** Sección "RECOMENDADAS" NO aparece (las 3 están en uso)

---

### Checklist de Validación Rápida

- [ ] 25.1.1 Summary card sin gradientes
- [ ] 25.1.2 Section headers solo vencidos con círculo
- [ ] 25.1.3 Due status simplificado
- [ ] 25.1.4 Botones calendario sin fondo
- [ ] 25.1.5 Consistencia con Presupuestos
- [ ] 25.2.1 Sección Recomendada en onboarding
- [ ] 25.2.2 Agrupación por continentes
- [ ] 25.2.3 No duplicación de moneda recomendada
- [ ] 25.3.1 Filtro solo monedas usadas
- [ ] 25.3.2 Nueva moneda aparece al usarla
- [ ] 25.3.3 Sección oculta sin transacciones
- [ ] 25.4.1 Ejemplos voz con moneda preferida
- [ ] 25.4.2 Ejemplos cambian con otra moneda
- [ ] 25.4.3 Dólar sin país
- [ ] 25.4.4 Pesos sin país
- [ ] 25.4.5 Validar otros idiomas
- [ ] 25.5.1 Sección Recomendadas visible
- [ ] 25.5.2 Excluye moneda preferida
- [ ] 25.5.3 Excluye monedas ya seleccionadas
- [ ] 25.5.4 Sección oculta si no hay recomendadas

---

## Sección 26: Modal Unificado para Nuevos Items en Bandeja (10.5.F)

Esta sección cubre la validación del modal que notifica al usuario cuando hay nuevos items en su bandeja de entrada que no ha visto.

### 26.1 Modal para Pagos Planificados

#### Escenario 26.1.1: Modal aparece para pagos planificados vencidos
**Precondición:** App cerrada, pago planificado con fecha de hoy o pasada

1. Crear un pago planificado con fecha = ayer
2. Cerrar la app completamente
3. Abrir la app
4. **Verificar:** Aparece modal con título "¡Tienes pagos pendientes!"
5. **Verificar:** El mensaje dice "Se añadieron X pagos planificados a tu bandeja."
6. **Verificar:** El icono es una campana (bell.badge.fill)

#### Escenario 26.1.2: Acción "Ver bandeja" navega correctamente
1. Desde el modal de pagos planificados, tocar "Ver bandeja"
2. **Verificar:** El modal se cierra con animación
3. **Verificar:** Se navega a la vista de Inbox
4. **Verificar:** Los drafts de pagos planificados son visibles

#### Escenario 26.1.3: Acción "Más tarde" cierra sin perder datos
1. Desde el modal de pagos planificados, tocar "Más tarde"
2. **Verificar:** El modal se cierra
3. **Verificar:** La app permanece en la vista principal
4. Navegar manualmente a Inbox
5. **Verificar:** Los drafts siguen ahí (no se perdieron)

---

### 26.2 Modal para Suscripciones

#### Escenario 26.2.1: Modal para suscripciones vencidas
**Precondición:** Suscripción configurada con fecha de renovación vencida

1. Crear una suscripción con fecha de renovación = ayer
2. Cerrar y abrir la app
3. **Verificar:** Modal con título "¡Suscripciones por revisar!"
4. **Verificar:** Mensaje "Se añadieron X suscripciones a tu bandeja."
5. **Verificar:** Icono de tarjeta (creditcard.and.123)

---

### 26.3 Modal para Automatizaciones

#### Escenario 26.3.1: Modal para registros de Apple Pay
**Precondición:** Shortcut de Apple Pay configurado

1. Ejecutar shortcut de Apple Pay (genera un draft automático)
2. Cerrar la app (o enviar a background y volver)
3. **Verificar:** Modal con título "¡Nuevos registros automáticos!"
4. **Verificar:** Mensaje "Se añadieron X registros automáticos a tu bandeja."
5. **Verificar:** Icono de engranaje (gearshape.badge.checkmark)

#### Escenario 26.3.2: Modal para automatizaciones externas
**Precondición:** Shortcut de automatización externa configurado

1. Ejecutar shortcut de automatización
2. Cerrar y abrir la app
3. **Verificar:** Mismo comportamiento que Apple Pay (tipo automations)

---

### 26.4 Modal Mixto

#### Escenario 26.4.1: Modal con múltiples tipos
**Precondición:** Pagos planificados Y suscripciones vencidas

1. Crear pago planificado con fecha vencida
2. Crear suscripción con fecha vencida
3. Cerrar y abrir la app
4. **Verificar:** Modal con título "¡Nuevos registros en tu bandeja!"
5. **Verificar:** Mensaje con desglose: "X pagos y Y suscripciones"
6. **Verificar:** Icono de bandeja llena (tray.full.fill)

#### Escenario 26.4.2: Desglose incluye todos los tipos
**Precondición:** Los 3 tipos de fuentes activos

1. Crear pago planificado vencido
2. Crear suscripción vencida
3. Ejecutar shortcut de Apple Pay
4. Cerrar y abrir la app
5. **Verificar:** Mensaje muestra los 3 tipos: "X pagos, Y suscripciones y Z registros automáticos"

---

### 26.5 Comportamiento "Solo Nuevos"

#### Escenario 26.5.1: No reaparece para drafts ya vistos
1. Abrir app, ver modal, tocar "Más tarde"
2. Cerrar y abrir la app inmediatamente
3. **Verificar:** El modal NO reaparece (ya se mostró para esos drafts)

#### Escenario 26.5.2: Reaparece solo para drafts nuevos
1. Abrir app, ver modal para 2 pagos, tocar "Más tarde"
2. Crear NUEVO pago planificado vencido
3. Cerrar y abrir la app
4. **Verificar:** Modal aparece solo para el nuevo pago (count = 1)

---

### 26.6 Exclusiones (No Deben Mostrar Modal)

#### Escenario 26.6.1: Voz no dispara modal
1. Abrir FAB > Voz
2. Grabar gasto por voz, generar draft
3. Cerrar y abrir la app
4. **Verificar:** NO aparece modal (voz está excluida)

#### Escenario 26.6.2: Foto de recibo no dispara modal
1. Abrir FAB > Foto
2. Capturar recibo, generar draft
3. Cerrar y abrir la app
4. **Verificar:** NO aparece modal (foto está excluida)

#### Escenario 26.6.3: Screenshot no dispara modal
1. Compartir screenshot desde galería a Yala
2. Generar draft
3. Cerrar y abrir la app
4. **Verificar:** NO aparece modal (screenshot está excluida)

---

### 26.7 Verificación Multi-Idioma

#### Escenario 26.7.1: Mensajes correctos en cada idioma
Para cada idioma (es, en, de, fr, it, pt):
1. Cambiar idioma del dispositivo
2. Generar un pago planificado vencido
3. Abrir la app
4. **Verificar:** Título, mensaje y botones en el idioma correcto

---

### Checklist de Validación Rápida 26.x

- [ ] 26.1.1 Modal pagos planificados aparece
- [ ] 26.1.2 "Ver bandeja" navega correctamente
- [ ] 26.1.3 "Más tarde" cierra sin perder datos
- [ ] 26.2.1 Modal suscripciones aparece
- [ ] 26.3.1 Modal Apple Pay aparece
- [ ] 26.3.2 Modal automatización aparece
- [ ] 26.4.1 Modal mixto con desglose
- [ ] 26.4.2 Desglose incluye 3 tipos
- [ ] 26.5.1 No reaparece para vistos
- [ ] 26.5.2 Reaparece solo para nuevos
- [ ] 26.6.1 Voz excluida
- [ ] 26.6.2 Foto excluida
- [ ] 26.6.3 Screenshot excluido
- [ ] 26.7.1 Verificar 6 idiomas

---

## Sección 27: Alertas de Presupuestos (10.5.D.1)

Esta sección cubre la validación de notificaciones push cuando los presupuestos alcanzan umbrales configurados.

### 27.1 Configuración de Alertas

#### Escenario 27.1.1: Activar alertas en presupuesto nuevo
**Precondición:** Crear nuevo presupuesto

1. Ir a Presupuestos > Crear nuevo
2. Completar nombre, límite ($100), período (mensual)
3. **Verificar:** Sección "Alertas" visible después de "Activo"
4. Activar toggle "Notificar al alcanzar límite"
5. **Verificar:** Aparecen chips de umbrales: 50%, 75%, 90%, 100%
6. Seleccionar 50% y 90%
7. Guardar presupuesto
8. Editar el mismo presupuesto
9. **Verificar:** Toggle activado y chips 50%, 90% seleccionados

#### Escenario 27.1.2: Desactivar alertas
1. Editar presupuesto con alertas activas
2. Desactivar toggle "Notificar al alcanzar límite"
3. **Verificar:** Los chips de umbrales desaparecen
4. Guardar
5. Crear gasto que cruce el 50%
6. **Verificar:** NO llega notificación push

---

### 27.2 Notificaciones por Umbral

#### Escenario 27.2.1: Umbral 50%
**Precondición:** Presupuesto $100, alertas [50%]

1. Crear gasto de $50 en categoría del presupuesto
2. **Verificar:** Notificación push: "Presupuesto \"[nombre]\" al 50%"

#### Escenario 27.2.2: Umbral 75%
**Precondición:** Presupuesto $100, alertas [75%]

1. Crear gasto de $75 en categoría del presupuesto
2. **Verificar:** Notificación push: "Presupuesto \"[nombre]\" al 75%"

#### Escenario 27.2.3: Umbral 90%
**Precondición:** Presupuesto $100, alertas [90%]

1. Crear gasto de $90 en categoría del presupuesto
2. **Verificar:** Notificación push: "Cuidado: \"[nombre]\" casi agotado"

#### Escenario 27.2.4: Umbral 100%
**Precondición:** Presupuesto $100, alertas [100%]

1. Crear gasto de $100 en categoría del presupuesto
2. **Verificar:** Notificación push: "Presupuesto \"[nombre]\" agotado"

---

### 27.3 Múltiples Umbrales

#### Escenario 27.3.1: Cruzar múltiples umbrales con un gasto
**Precondición:** Presupuesto $100, alertas [50%, 75%]

1. Crear gasto de $80 (cruza 50% y 75% a la vez)
2. **Verificar:** Llegan 2 notificaciones (50% y 75%)

#### Escenario 27.3.2: No duplicar notificaciones ya enviadas
**Precondición:** Ya se notificó 50%

1. Crear otro gasto pequeño ($5)
2. **Verificar:** NO llega nueva notificación de 50%
3. Crear gasto que cruce 75%
4. **Verificar:** Solo llega notificación de 75%

---

### 27.4 Diferentes Fuentes de Transacciones

#### Escenario 27.4.1: Via Registro Manual
1. Crear presupuesto con alertas [50%]
2. Ir a FAB > Registro manual
3. Crear gasto que cruce 50%
4. **Verificar:** Notificación push aparece

#### Escenario 27.4.2: Via Shortcuts (Siri)
**Precondición:** Shortcut configurado para agregar gasto

1. Crear presupuesto $100, alertas [50%]
2. Usar Siri: "Agregar gasto $50 en [categoría]"
3. **Verificar:** Notificación push aparece (sin abrir la app)

#### Escenario 27.4.3: Via Inbox (aprobar draft)
1. Crear presupuesto con alertas [50%]
2. Crear draft pendiente en Inbox
3. Aprobar draft con monto que cruce 50%
4. **Verificar:** Notificación push aparece

#### Escenario 27.4.4: Via Bulk Approve
1. Crear presupuesto con alertas [50%, 75%]
2. Crear múltiples drafts pendientes
3. Seleccionar todos > Aprobar
4. **Verificar:** Notificaciones para umbrales cruzados

---

### 27.5 Casos Edge

#### Escenario 27.5.1: Presupuesto inactivo no notifica
1. Crear presupuesto con alertas activas
2. Desactivar el presupuesto (toggle Activo = off)
3. Crear gasto que cruce umbral
4. **Verificar:** NO llega notificación

#### Escenario 27.5.2: Reset de período mensual
**Precondición:** Presupuesto mensual, ya notificado 50% en enero

1. Cambiar fecha del dispositivo a 1 de febrero
2. Crear gasto que cruce 50%
3. **Verificar:** Notificación SÍ llega (nuevo período)

#### Escenario 27.5.3: Editar umbrales después de notificado
1. Presupuesto con [50%] ya notificado
2. Editar presupuesto, agregar umbral 75%
3. Presupuesto ya está al 60%
4. **Verificar:** NO notifica 75% automáticamente
5. Crear gasto que cruce 75%
6. **Verificar:** Notificación de 75% llega

### 27.6 Toggle Global de Alertas (10.5.D.2)

#### Escenario 27.6.1: Toggle en onboarding
1. Iniciar onboarding (data wipe o primera instalación)
2. Avanzar hasta paso 6 (Notificaciones)
3. **Verificar:** En sección "Sistema", hay opción "Alertas de presupuesto" con icono rosa
4. Activar toggle de alertas de presupuesto
5. Completar onboarding
6. Ir a Settings > Notificaciones
7. **Verificar:** Toggle está ON (guardó preferencia del onboarding)

#### Escenario 27.6.1b: Toggle global visible y OFF por defecto
1. Completar onboarding SIN activar alertas de presupuesto
2. Ir a Settings > Notificaciones
3. **Verificar:** Sección "Alertas de presupuesto" visible AL INICIO
4. **Verificar:** Toggle está OFF (respeta preferencia del onboarding)
5. **Verificar:** Icono rosa (hotPink) con chart.bar.fill
6. **Verificar:** Hint: "Recibe avisos cuando..."

#### Escenario 27.6.2: Toggle global OFF bloquea alertas
**Precondición:** Presupuesto con alertas activas y umbral próximo a cruzar

1. Ir a Settings > Notificaciones > Desactivar toggle de alertas
2. Crear transacción que cruce umbral del presupuesto
3. **Verificar:** NO se recibe notificación push
4. Ir a editar el presupuesto
5. **Verificar:** alertEnabled del presupuesto sigue siendo true (no se modificó)

#### Escenario 27.6.3: Toggle global ON permite alertas
**Precondición:** Toggle global ON, presupuesto con alertas activas

1. Crear transacción que cruce umbral del presupuesto
2. **Verificar:** Se recibe notificación push

#### Escenario 27.6.4: Persistencia del toggle
1. Desactivar toggle global
2. Forzar cierre de app (kill desde multitarea)
3. Reabrir app > Settings > Notificaciones
4. **Verificar:** Toggle sigue OFF

#### Escenario 27.6.5: Independencia de configuración individual
1. Toggle global ON
2. Editar presupuesto A > Desactivar alertas de ESE presupuesto
3. **Verificar:** Toggle global permanece ON
4. Crear transacción que cruce umbral de presupuesto A
5. **Verificar:** NO se recibe notificación (respeta config individual)
6. Crear transacción que cruce umbral de presupuesto B (con alertas ON)
7. **Verificar:** SÍ se recibe notificación

#### Escenario 27.6.6: Sección visible sin notificaciones
1. Sin notificaciones configuradas (lista vacía)
2. Ir a Settings > Notificaciones
3. **Verificar:** Sección "Alertas de presupuesto" VISIBLE arriba del empty state
4. **Verificar:** Toggle funcional

---

### Checklist de Validación Rápida 27.x

- [ ] 27.1.1 Config alertas se guarda y persiste
- [ ] 27.1.2 Desactivar alertas previene notificaciones
- [ ] 27.2.1 Umbral 50% notifica
- [ ] 27.2.2 Umbral 75% notifica
- [ ] 27.2.3 Umbral 90% notifica
- [ ] 27.2.4 Umbral 100% notifica
- [ ] 27.3.1 Múltiples umbrales en un gasto
- [ ] 27.3.2 No duplica notificaciones
- [ ] 27.4.1 Via registro manual
- [ ] 27.4.2 Via Shortcuts/Siri
- [ ] 27.4.3 Via aprobar draft
- [ ] 27.4.4 Via bulk approve
- [ ] 27.5.1 Presupuesto inactivo no notifica
- [ ] 27.5.2 Reset de período funciona
- [ ] 27.5.3 Nuevos umbrales funcionan
- [ ] 27.6.1 Toggle en onboarding (sección Sistema)
- [ ] 27.6.1b Toggle global visible y OFF por defecto
- [ ] 27.6.2 Toggle OFF bloquea alertas
- [ ] 27.6.3 Toggle ON permite alertas
- [ ] 27.6.4 Persistencia del toggle
- [ ] 27.6.5 Independencia config individual
- [ ] 27.6.6 Sección visible sin notificaciones

---

*Última actualización: 2026-02-02 - Sección 27 (Fase 10.5.D.1)*
*Total escenarios: ~410*
*Total verificaciones: ~780+*

---

## Sección 28: Widgets iOS (WidgetKit) - Fase 10.5.G.2

### Prerrequisitos
- iPhone con iOS 17+
- App Yala instalada
- Al menos 1 cuenta creada
- Al menos 5 transacciones registradas
- Al menos 1 presupuesto activo
- Al menos 1 pago planificado

---

### 28.1 Instalación y Configuración de Widgets

#### Escenario 28.1.1: Agregar widget Balance (Small)
1. Mantener presionada la pantalla de inicio
2. Tocar (+) para agregar widget
3. Buscar "Yala"
4. Seleccionar widget "Balance" tamaño pequeño
5. **Verificar:** Widget muestra balance total formateado
6. **Verificar:** Widget muestra indicador ▲ o ▼ según tendencia

#### Escenario 28.1.2: Agregar widget Balance (Medium)
1. Agregar widget "Balance" tamaño mediano
2. **Verificar:** Widget muestra balance total
3. **Verificar:** Widget muestra mini gráfico de tendencia
4. **Verificar:** Gráfico tiene área coloreada bajo la línea

#### Escenario 28.1.3: Configurar período del widget Balance
1. Mantener presionado el widget Balance (Medium)
2. Tocar "Editar widget"
3. **Verificar:** Opción "Período" visible
4. Seleccionar "Mes" (por defecto)
5. Seleccionar "Semana"
6. **Verificar:** Gráfico actualiza a tendencia semanal

#### Escenario 28.1.4: Agregar widget Últimos Registros
1. Agregar widget "Últimos Registros" (medium)
2. **Verificar:** Lista de 3-5 transacciones recientes
3. **Verificar:** Cada fila muestra icono, nombre, monto
4. **Verificar:** Montos negativos en color diferente a positivos

#### Escenario 28.1.5: Agregar widget Pagos Planificados
1. Agregar widget "Pagos Planificados" (medium)
2. **Verificar:** Lista de pagos próximos
3. **Verificar:** Fechas en formato relativo ("Hoy", "Mañana", "3 días")

#### Escenario 28.1.6: Configurar filtro del widget Pagos Planificados
1. Editar widget "Pagos Planificados"
2. **Verificar:** Opciones: "Todos", "Recurrentes", "Suscripciones"
3. Seleccionar "Suscripciones"
4. **Verificar:** Solo muestra suscripciones

#### Escenario 28.1.7: Agregar widget Presupuestos
1. Agregar widget "Presupuestos" (medium)
2. **Verificar:** Barras de progreso de presupuestos
3. **Verificar:** Colores: verde (< 75%), amarillo (75-90%), rojo (> 90%)

#### Escenario 28.1.8: Configurar modo del widget Presupuestos
1. Editar widget "Presupuestos"
2. **Verificar:** Opciones: "Todos", "Críticos (> 75%)"
3. Seleccionar "Críticos"
4. **Verificar:** Solo muestra presupuestos con consumo > 75%

---

### 28.2 Actualización de Datos en Widgets

#### Escenario 28.2.1: Actualizar tras nuevo registro
1. Agregar widget Balance (visible en home)
2. Abrir app > Crear nuevo gasto de $100
3. Volver a pantalla de inicio
4. **Verificar:** Balance actualizado en widget (puede tardar 1-2 segundos)

#### Escenario 28.2.2: Actualizar tras aprobar draft
1. Tener draft pendiente en Inbox
2. Widget Balance visible
3. Aprobar draft
4. **Verificar:** Balance actualizado

#### Escenario 28.2.3: Actualizar tras bulk approve
1. Múltiples drafts pendientes
2. Seleccionar todos > Aprobar
3. **Verificar:** Widgets se actualizan

#### Escenario 28.2.4: Actualizar tras eliminar transacción
1. Eliminar una transacción existente
2. **Verificar:** Balance y Últimos Registros actualizados

#### Escenario 28.2.5: Actualizar en background (>4 horas)
**Nota:** Difícil de probar manualmente, requiere esperar

1. No abrir la app por 4+ horas
2. **Verificar:** Widgets aún muestran datos recientes (background refresh)

---

### 28.3 Deep Links desde Widgets

#### Escenario 28.3.1: Tap en widget Balance → Panel
1. Tocar el widget Balance
2. **Verificar:** App abre en tab Panel

#### Escenario 28.3.2: Tap en widget Últimos Registros → Records
1. Tocar el widget "Últimos Registros"
2. **Verificar:** App abre en Statistics > Records

#### Escenario 28.3.3: Tap en widget Pagos Planificados → Planning
1. Tocar el widget "Pagos Planificados"
2. **Verificar:** App abre en tab Planning

#### Escenario 28.3.4: Tap en widget Presupuestos → Budgets
1. Tocar el widget "Presupuestos"
2. **Verificar:** App abre en Planning > Presupuestos

#### Escenario 28.3.5: Deep link con app en background
1. App Yala en background (no cerrada)
2. Tocar widget Balance
3. **Verificar:** App viene al frente y navega a Panel

#### Escenario 28.3.6: Deep link con app cerrada
1. Cerrar app Yala completamente (force quit)
2. Tocar widget Últimos Registros
3. **Verificar:** App inicia y navega a Records

---

### 28.4 Estados Vacíos y Edge Cases

#### Escenario 28.4.1: Widget Balance sin cuentas
**Precondición:** Usuario nuevo, sin cuentas

1. Agregar widget Balance
2. **Verificar:** Muestra "$0" o mensaje vacío elegante

#### Escenario 28.4.2: Widget Últimos Registros sin transacciones
1. Usuario sin transacciones
2. Agregar widget
3. **Verificar:** Mensaje "Sin registros" o similar

#### Escenario 28.4.3: Widget Pagos Planificados sin pagos
1. Sin pagos planificados creados
2. Agregar widget
3. **Verificar:** Mensaje vacío apropiado

#### Escenario 28.4.4: Widget Presupuestos sin presupuestos
1. Sin presupuestos creados
2. Agregar widget
3. **Verificar:** Mensaje vacío apropiado

#### Escenario 28.4.5: Pago planificado vencido muestra indicador
1. Crear pago planificado con fecha pasada
2. Widget Pagos Planificados
3. **Verificar:** Indicador rojo de "Vencido"

#### Escenario 28.4.6: Data wipe actualiza widgets
1. Widgets visibles en home
2. Settings > Borrar todos los datos
3. **Verificar:** Widgets muestran estados vacíos tras wipe

---

### 28.5 Múltiples Widgets

#### Escenario 28.5.1: Varios widgets del mismo tipo
1. Agregar 2 widgets Balance (uno small, uno medium)
2. **Verificar:** Ambos muestran datos consistentes

#### Escenario 28.5.2: Todos los tipos de widgets a la vez
1. Agregar los 4 tipos de widgets
2. Crear transacción
3. **Verificar:** Todos se actualizan correctamente

#### Escenario 28.5.3: Configuraciones independientes
1. Widget Presupuestos A: modo "Todos"
2. Widget Presupuestos B: modo "Críticos"
3. **Verificar:** Cada uno respeta su configuración

---

### 28.6 App Groups y Persistencia

#### Escenario 28.6.1: Datos persisten tras reinicio
1. Configurar widgets
2. Reiniciar dispositivo
3. **Verificar:** Widgets muestran datos correctos sin abrir app

#### Escenario 28.6.2: Datos compartidos entre app y widget
1. Agregar transacción en app
2. Sin cerrar app, ver widgets
3. **Verificar:** Datos sincronizados

---

### Checklist de Validación Rápida 28.x

- [ ] 28.1.1 Widget Balance Small se agrega
- [ ] 28.1.2 Widget Balance Medium muestra gráfico
- [ ] 28.1.3 Configurar período funciona
- [ ] 28.1.4 Widget Últimos Registros lista transacciones
- [ ] 28.1.5 Widget Pagos Planificados lista pagos
- [ ] 28.1.6 Filtro de pagos funciona
- [ ] 28.1.7 Widget Presupuestos muestra barras
- [ ] 28.1.8 Modo críticos funciona
- [ ] 28.2.1 Actualiza tras nuevo registro
- [ ] 28.2.2 Actualiza tras aprobar draft
- [ ] 28.2.3 Actualiza tras bulk approve
- [ ] 28.2.4 Actualiza tras eliminar
- [ ] 28.3.1 Deep link Balance → Panel
- [ ] 28.3.2 Deep link Registros → Records
- [ ] 28.3.3 Deep link Pagos → Planning
- [ ] 28.3.4 Deep link Presupuestos → Budgets
- [ ] 28.3.5 Deep link con app en background
- [ ] 28.3.6 Deep link con app cerrada
- [ ] 28.4.1 Estado vacío Balance
- [ ] 28.4.2 Estado vacío Registros
- [ ] 28.4.3 Estado vacío Pagos
- [ ] 28.4.4 Estado vacío Presupuestos
- [ ] 28.4.5 Indicador vencido
- [ ] 28.4.6 Data wipe actualiza widgets
- [ ] 28.5.1 Múltiples widgets consistentes
- [ ] 28.5.2 Todos los tipos a la vez
- [ ] 28.5.3 Configuraciones independientes
- [ ] 28.6.1 Persiste tras reinicio
- [ ] 28.6.2 Datos compartidos

---

## Sección 29: Control Center y Lock Screen (10.5.G.3)

Esta sección cubre la validación de los controles de Yala en el Centro de Control de iOS 18+.

**Requisitos:**
- iOS 18.0 o superior
- Widget Extension configurada en Xcode (ver `YalaWidgets/SETUP.md`)

### 29.1 Configuración de Controles

#### Escenario 29.1.1: Añadir controles de Yala al Control Center
**Precondición:** iOS 18+ device o simulador, Widget Extension instalada

1. Ir a Settings > Control Center
2. Scroll hasta "More Controls"
3. Buscar "Yala"
4. **Verificar:** Aparecen 3 controles disponibles:
   - "Gasto rápido" (plus.circle.fill)
   - "Por voz" (mic.fill)
   - "Escanear" (camera.fill)
5. Añadir los 3 controles al Control Center
6. **Verificar:** Los 3 aparecen en el Control Center

#### Escenario 29.1.2: Reorganizar controles
1. En Settings > Control Center, mover un control de Yala
2. **Verificar:** El control se mueve correctamente
3. Abrir Control Center
4. **Verificar:** El orden refleja los cambios

---

### 29.2 Funcionalidad de Controles

#### Escenario 29.2.1: Control "Gasto rápido"
**Precondición:** Control añadido al Control Center

1. Deslizar para abrir Control Center
2. Tocar el control "Gasto rápido"
3. **Verificar:** Yala se abre
4. **Verificar:** Se muestra la pantalla de nuevo registro

#### Escenario 29.2.2: Control "Por voz"
**Precondición:** Control añadido, entrada por voz activada en Settings

1. Deslizar para abrir Control Center
2. Tocar el control "Por voz"
3. **Verificar:** Yala se abre
4. **Verificar:** Se muestra la interfaz de grabación de voz

#### Escenario 29.2.3: Control "Escanear"
**Precondición:** Control añadido, entrada por imagen activada en Settings

1. Deslizar para abrir Control Center
2. Tocar el control "Escanear"
3. **Verificar:** Yala se abre
4. **Verificar:** Se muestra la interfaz de cámara/galería

---

### 29.3 Control Center desde Lock Screen

#### Escenario 29.3.1: Usar control desde pantalla bloqueada
**Precondición:** Controles añadidos, dispositivo con Face ID/Touch ID

1. Bloquear dispositivo
2. Deslizar para abrir Control Center desde Lock Screen
3. Tocar control "Gasto rápido"
4. **Verificar:** Se solicita autenticación (Face ID/Touch ID)
5. Autenticar
6. **Verificar:** Yala se abre en el registro

#### Escenario 29.3.2: Control desde Lock Screen - Sin biometría activa
**Precondición:** Biometría desactivada en Settings > Seguridad

1. Bloquear dispositivo
2. Deslizar para abrir Control Center desde Lock Screen
3. Tocar control "Gasto rápido"
4. **Verificar:** Yala se abre directamente (sin solicitar autenticación)

---

### 29.4 Localización

#### Escenario 29.4.1: Labels en español
1. Cambiar idioma del dispositivo a Español
2. Ir a Settings > Control Center
3. **Verificar:** Labels:
   - "Gasto rápido"
   - "Registro por voz"
   - "Escanear recibo"

#### Escenario 29.4.2: Labels en inglés
1. Cambiar idioma del dispositivo a English
2. Ir a Settings > Control Center
3. **Verificar:** Labels:
   - "Quick expense"
   - "Voice entry"
   - "Scan receipt"

---

### 29.5 Casos Edge

#### Escenario 29.5.1: Voz desactivada - Usar control "Por voz"
**Precondición:** Entrada por voz desactivada en Yala Settings

1. Tocar control "Por voz" desde Control Center
2. **Verificar:** Yala se abre
3. **Verificar:** Muestra mensaje indicando que la voz no está activada

#### Escenario 29.5.2: Imagen desactivada - Usar control "Escanear"
**Precondición:** Entrada por imagen desactivada en Yala Settings

1. Tocar control "Escanear" desde Control Center
2. **Verificar:** Yala se abre
3. **Verificar:** Muestra mensaje indicando que la imagen no está activada

#### Escenario 29.5.3: iOS 17 - Sin controles disponibles
**Precondición:** Dispositivo con iOS 17 o anterior

1. Ir a Settings > Control Center
2. Buscar "Yala"
3. **Verificar:** NO aparece Yala en la lista (requiere iOS 18)

---

### Checklist de Validación Rápida 29.x

- [ ] 29.1.1 Controles aparecen en Settings > Control Center
- [ ] 29.1.2 Se pueden reorganizar
- [ ] 29.2.1 "Gasto rápido" abre registro
- [ ] 29.2.2 "Por voz" abre grabación
- [ ] 29.2.3 "Escanear" abre cámara
- [ ] 29.3.1 Funciona desde Lock Screen con auth
- [ ] 29.3.2 Funciona sin biometría
- [ ] 29.4.1 Localización ES correcta
- [ ] 29.4.2 Localización EN correcta
- [ ] 29.5.1 Maneja voz desactivada
- [ ] 29.5.2 Maneja imagen desactivada
- [ ] 29.5.3 iOS 17 no muestra controles

---

## 30. iCloud Sync (10.5.G.1)

### 30.1 Primera activación
1. Ir a Perfil > Sincronización iCloud
2. Verificar estado "Desactivado"
3. Activar toggle
4. Verificar alert de reinicio
5. Confirmar → app se cierra
6. Reabrir → verificar estado "Sincronizado" o "Sincronizando"

### 30.2 Sin cuenta iCloud
1. Cerrar sesión de iCloud en Ajustes del sistema
2. Abrir Yala > Perfil > Sincronización iCloud
3. Verificar toggle deshabilitado
4. Verificar mensaje de advertencia
5. Verificar estado "Sin cuenta iCloud"

### 30.3 Sync entre dispositivos
1. Device A: Activar iCloud sync
2. Device B: Instalar Yala con misma cuenta iCloud, activar sync
3. Device A: Crear transacción
4. Device B: Verificar transacción aparece (puede tomar 1-2 min)
5. Verificar categorías y cuentas sincronizadas

### 30.4 Desactivar sync
1. Con iCloud activo y datos sincronizados
2. Desactivar toggle
3. Confirmar reinicio
4. Verificar datos locales preservados
5. Crear nueva transacción
6. Verificar NO sincroniza a otro device

### 30.5 Conflicto (last-write-wins)
1. Device A: Editar descripción de transacción a "AAA"
2. Inmediatamente Device B: Editar misma transacción a "BBB"
3. Esperar sync
4. Ambos devices: Verificar que tienen el mismo valor (el último en sincronizar gana)

### 30.6 ExchangeRate sin duplicados
1. Verificar que tipos de cambio funcionan normalmente
2. Forzar recarga de tipos de cambio
3. Verificar no hay duplicados en la base de datos

---

### Checklist de Validación Rápida 30.x

- [ ] 30.1.1 Estado inicial "Desactivado"
- [ ] 30.1.2 Toggle muestra alert de reinicio
- [ ] 30.1.3 App reinicia correctamente
- [ ] 30.2.1 Sin cuenta: toggle deshabilitado
- [ ] 30.2.2 Sin cuenta: mensaje de advertencia visible
- [ ] 30.3.1 Transacciones sincronizan entre devices
- [ ] 30.3.2 Categorías/cuentas sincronizan
- [ ] 30.4.1 Desactivar preserva datos locales
- [ ] 30.4.2 Nuevos datos no sincronizan después de desactivar
- [ ] 30.5.1 Conflictos se resuelven (last-write-wins)
- [ ] 30.6.1 ExchangeRate no tiene duplicados

---

## Sección 31: Modo Solo Gastos (Expenses Only Mode)

### 31.1 Activación / Desactivación
- [ ] 31.1.1 Settings > Personalización: toggle "Modo solo gastos" visible
- [ ] 31.1.2 Activar: muestra diálogo de confirmación antes de cambiar
- [ ] 31.1.3 Desactivar: muestra diálogo de confirmación antes de cambiar
- [ ] 31.1.4 Preferencia persiste entre relanzamientos de la app
- [ ] 31.1.5 Activar limpia estado incompatible (selectedTrendMetric forzado a .expense)

### 31.2 Creación de Transacciones
- [ ] 31.2.1 NewTransactionView: selector de tipo muestra solo "Gasto" (oculta income/transfer)
- [ ] 31.2.2 Si solo 1 tipo disponible, selector completo se oculta
- [ ] 31.2.3 FavoriteEditorView: tipos income/transfer ocultos
- [ ] 31.2.4 ScheduledPaymentEditorView: tipo income oculto
- [ ] 31.2.5 InboxDraftEditSheet: forzado a expense

### 31.3 Panel
- [ ] 31.3.1 Cuentas muestran "Gastado" (gasto del periodo) en vez de saldo
- [ ] 31.3.2 Cambiar periodo actualiza montos de gasto por cuenta
- [ ] 31.3.3 Saldo total del header se oculta
- [ ] 31.3.4 CashFlowWidget: solo muestra barras de gasto (sin income)
- [ ] 31.3.5 TrendWidget: forzado a métrica "Gastos", selector oculto
- [ ] 31.3.6 RecentRecordsWidget: no muestra transacciones de ingreso
- [ ] 31.3.7 BalanceStatusIndicator: oculto

### 31.4 Estadísticas
- [ ] 31.4.1 TrendsTab: solo métrica "Gastos", botones balance/income ocultos
- [ ] 31.4.2 CategoriesTab: sin categorías de ingreso
- [ ] 31.4.3 RecordsTab: sin transacciones income, balance summary oculto
- [ ] 31.4.4 DetailContainerView: métrica inicial es .expense (no .balance)
- [ ] 31.4.5 Chips de nature ocultos (siempre expense, no clearable)
- [ ] 31.4.6 RecordsFiltersView: sección "Naturaleza" (income/expense) oculta

### 31.5 Settings
- [ ] 31.5.1 Cuentas: saldos ocultos en lista de cuentas activas
- [ ] 31.5.2 Cuentas: saldos ocultos en lista de cuentas archivadas
- [ ] 31.5.3 Editar cuenta: preview de saldo actual oculto
- [ ] 31.5.4 Categorías: categorías income dimmed (opacidad 0.5) con badge "(oculta)"
- [ ] 31.5.5 Categorías income siguen siendo editables (no se bloquean)

### 31.6 Búsqueda y Records
- [ ] 31.6.1 Búsqueda global: no encuentra transacciones income
- [ ] 31.6.2 RecordsStandaloneView: solo muestra gastos

### 31.7 Favoritos y Planificación
- [ ] 31.7.1 FavoritesListView: favoritos income ocultos
- [ ] 31.7.2 Empty state si solo hay favoritos income
- [ ] 31.7.3 ScheduledPayments lista: pagos income filtrados
- [ ] 31.7.4 ScheduledPayments subscriptions: income filtrados
- [ ] 31.7.5 ScheduledPayments recurring: income filtrados

### 31.8 Notificaciones
- [ ] 31.8.1 NotificationEditorSheet: tipos "Ingresos" y "Balance" ocultos
- [ ] 31.8.2 Editar notificación existente con tipo income: se fuerza a "Gastos"
- [ ] 31.8.3 Reporte diario/semanal/mensual solo muestra gastos (sin income)

### 31.9 Widgets iOS
- [ ] 31.9.1 CashFlowWidget small: solo muestra gastos
- [ ] 31.9.2 CashFlowWidget medium: barra income oculta
- [ ] 31.9.3 CashFlowWidget large: income legend oculto, chart solo expense
- [ ] 31.9.4 LatestRecordsWidget: sin transacciones income
- [ ] 31.9.5 ScheduledPaymentsWidget: sin pagos income
- [ ] 31.9.6 Desactivar modo: widgets se refrescan mostrando todo

### 31.10 Siri / Shortcuts
- [ ] 31.10.1 QuickExpenseIntent: forzado a tipo expense (no pregunta tipo)
- [ ] 31.10.2 Desactivar modo: QuickExpenseIntent permite elegir tipo again

### 31.11 Onboarding
- [ ] 31.11.1 Nuevo paso "¿Qué quieres registrar?" aparece después de periodo
- [ ] 31.11.2 Opción "Todo" seleccionada por defecto
- [ ] 31.11.3 Seleccionar "Solo gastos" y completar onboarding: app abre en modo solo gastos
- [ ] 31.11.4 Seleccionar "Todo": app abre en modo normal

### 31.12 Reversibilidad
- [ ] 31.12.1 Activar modo: datos income siguen en base de datos (no se eliminan)
- [ ] 31.12.2 Desactivar modo: todos los income/saldos reaparecen inmediatamente
- [ ] 31.12.3 Crear gastos en modo activo, desactivar: gastos siguen visibles con income
- [ ] 31.12.4 Importar CSV con income en modo activo: income queda oculto pero existe

---

---

## Sección 32: Waterfall Chart en CashFlow (EXP-1)

### 32.1 Waterfall con días mixtos (EXP-1.1)
- [ ] 32.1.1 Statistics > periodo "Esta semana" o "Este mes" con datos mixtos (ingreso y gasto)
- [ ] 32.1.2 Barras individuales por día: teal (neto positivo), pink (neto negativo)
- [ ] 32.1.3 Línea cero dashed visible como referencia
- [ ] 32.1.4 NO aparece legend (colores auto-evidentes con línea cero)

### 32.2 Solo gastos + eje diario (EXP-1.2)
- [ ] 32.2.1 Seleccionar métrica "Gastos" con periodo diario
- [ ] 32.2.2 Barras normales pink hacia ARRIBA (NO waterfall)
- [ ] 32.2.3 Sin línea cero (solo barras positivas)

### 32.3 Solo ingresos + eje diario (EXP-1.3)
- [ ] 32.3.1 Seleccionar métrica "Ingresos" con periodo diario
- [ ] 32.3.2 Barras normales teal hacia ARRIBA (NO waterfall)
- [ ] 32.3.3 Sin línea cero (solo barras positivas)

### 32.4 Vista mensual sin cambios (EXP-1.4)
- [ ] 32.4.1 Seleccionar "Este año" — barras bidireccionales (income arriba, expense abajo)
- [ ] 32.4.2 Línea neta morada visible con puntos
- [ ] 32.4.3 Legend visible con Income, Expense, Net

### 32.5 Cambio de periodo (EXP-1.5)
- [ ] 32.5.1 Cambiar de periodo semanal → anual: chart cambia de waterfall a bidireccional
- [ ] 32.5.2 Cambiar de periodo anual → mensual: chart cambia de bidireccional a waterfall
- [ ] 32.5.3 Legend aparece/desaparece correctamente al cambiar modo

### 32.6 Tooltip en waterfall (EXP-1.6)
- [ ] 32.6.1 Tocar barra en waterfall: tooltip muestra desglose ingreso/gasto/neto
- [ ] 32.6.2 Tooltip formateado correctamente con colores indicativos

### 32.7 Widget iOS large con periodo diario (EXP-1.7)
- [ ] 32.7.1 Widget large con periodo thisWeek/thisMonth: muestra waterfall (si hay ingreso y gasto)
- [ ] 32.7.2 Barras teal (neto positivo) y pink (neto negativo)
- [ ] 32.7.3 Línea cero dashed visible

### 32.8 Widget iOS large con periodo mensual (EXP-1.8)
- [ ] 32.8.1 Widget large con periodo thisYear/allTime: muestra bidireccional
- [ ] 32.8.2 Barras income arriba, expense abajo, línea neta morada

### 32.9 Día con neto exactamente 0 (EXP-1.9)
- [ ] 32.9.1 Día donde ingreso == gasto exacto: NO muestra barra fantasma en waterfall
- [ ] 32.9.2 Eje X no desperdicia espacio en barras invisibles

---

*Última actualización: 2026-02-08 - Sección 32 (Waterfall Chart CashFlow)*
*Total escenarios: ~495*
*Total verificaciones: ~920+*
