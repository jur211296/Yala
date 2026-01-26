# Auditoría de Brand Voice - Yala

*Fecha: 2026-01-26*

## Resumen Ejecutivo

Se auditaron **1066 strings** en `es.lproj/Localizable.strings` contra las directrices de `BRAND-VOICE.md`.

### Estadísticas Generales

| Categoría | Cantidad | % del Total |
|-----------|----------|-------------|
| Strings OK (cumplen brand voice) | ~850 | 80% |
| Strings a mejorar (tono/estilo) | ~150 | 14% |
| Strings críticos (violan brand voice) | ~66 | 6% |

---

## Hallazgos por Categoría

### 1. CRÍTICO: Tono Frío/Técnico en Errores

**Problema:** Los mensajes de error suenan a sistema, no a amigo.

| Actual | Debería ser |
|--------|-------------|
| `"Error desconocido"` | `"Algo salió mal. Intenta de nuevo en un momento."` |
| `"No se pudo cargar el tipo de cambio para este periodo. Inténtalo más tarde."` | `"No pudimos obtener el tipo de cambio. Intenta de nuevo en un momento."` |
| `"No se pudo obtener la URL del archivo seleccionado."` | `"Hmm, no pudimos leer ese archivo. ¿Puedes seleccionarlo de nuevo?"` |
| `"No se pudieron guardar los cambios. Intenta de nuevo."` | `"Los cambios no se guardaron. ¿Puedes intentarlo de nuevo?"` |
| `"No se pudo eliminar. Intenta de nuevo."` | `"No se pudo eliminar. Intenta una vez más."` |
| `"Error al importar"` | `"Hubo un problema al importar"` |
| `"Error al eliminar datos"` | `"Hubo un problema al eliminar los datos"` |
| `"Error de exportación"` | `"Hubo un problema al exportar"` |

**Líneas afectadas:** 148, 241, 248, 438, 548, 549, 550, 720, 721

---

### 2. CRÍTICO: Estados Vacíos Sin Personalidad

**Problema:** Mensajes genéricos que no invitan a la acción ni dan ánimo.

| Actual | Debería ser |
|--------|-------------|
| `"Aún no hay datos para mostrar"` | `"Aquí aparecerán tus datos cuando empieces a registrar"` |
| `"Aún no hay transacciones"` | `"Aquí aparecerán tus movimientos. ¡Registra el primero!"` |
| `"Aún no hay favoritos"` | `"Aún no tienes favoritos. ¡Crea el primero!"` |
| `"Sin registros"` | `"Aún no hay registros en este periodo"` |
| `"Sin resultados"` | `"No encontramos resultados"` |
| `"Sin presupuestos"` | `"Aún no tienes presupuestos"` |
| `"Sin favoritos"` | `"Aún no tienes favoritos"` |
| `"Sin pagos planificados"` | `"Aún no tienes pagos planificados"` |
| `"Sin suscripciones"` | `"Aún no tienes suscripciones"` |

**Líneas afectadas:** 152-158, 277, 362, 502, 905, 981

---

### 3. MEDIO: Uso de "Transacción" vs "Gasto/Ingreso/Registro"

**Problema:** Brand voice indica usar "gasto" o "ingreso" en lugar de "transacción" (término técnico).

| Actual | Contexto | Sugerencia |
|--------|----------|------------|
| `"Nueva transacción"` | General | `"Nuevo registro"` ✅ (ya existe) |
| `"Editar transacción"` | General | `"Editar registro"` ✅ (ya existe) |
| `"transacciones seleccionadas"` | Bulk edit | OK en contexto técnico |
| `"transacciones asociadas"` | Delete warning | OK en contexto técnico |

**Evaluación:** El uso está parcialmente correcto. La app ya usa "registro" en muchos lugares. Los usos técnicos son aceptables.

---

### 4. MEDIO: Alertas de Eliminación Muy Frías

**Problema:** Tono de "sistema de base de datos" en lugar de conversacional.

| Actual | Debería ser |
|--------|-------------|
| `"Confirmar eliminación"` | `"¿Seguro que quieres eliminar?"` |
| `"Esta acción no se puede deshacer."` | `"Esta acción no se puede deshacer"` (sin punto = más conversacional) |
| `"¿Eliminar %d registro(s)?"` | `"¿Eliminar estos %d registros?"` |
| `"Cambios sin guardar"` | `"Tienes cambios sin guardar"` |

**Líneas afectadas:** 90, 224-228, 370, 733, 769, 777, 919

---

### 5. BAJO: Onboarding Podría Ser Más Cálido

**Problema:** El onboarding es funcional pero no transmite la personalidad de "amigo financiero".

| Actual | Debería ser |
|--------|-------------|
| `"Bienvenido a Yala"` | `"¡Hola! Soy Yala"` |
| `"Configura tu app de finanzas personales en unos segundos."` | `"Vamos a organizar tus finanzas juntos. Solo unos pasos."` |
| `"¿Cómo te llamas?"` | OK ✅ (ya es cercano) |
| `"Comenzar"` | `"¡Empecemos!"` |

**Líneas afectadas:** 1046-1057

---

### 6. BAJO: Falta de Emojis Moderados

**Problema:** Brand voice permite emojis moderados para dar calidez, pero casi no se usan.

**Lugares donde podrían agregarse:**
- Estados vacíos de widgets
- Mensaje de éxito al guardar
- Onboarding
- Tips y ayudas

**Nota:** Los emojis deben usarse con moderación (1-2 por mensaje máximo).

---

### 7. POSITIVO: Lo Que Está Bien

Muchos strings ya cumplen el brand voice:

- ✅ `"¿Cómo te llamas?"` - Cercano
- ✅ `"Tu nombre"` - Directo
- ✅ `"Tus datos nunca salen de tu dispositivo"` - Claro y tranquilizador
- ✅ `"Listo"` - Simple
- ✅ `"Siguiente"` - Directo
- ✅ `"Crear etiquetas para organizar tus transacciones de forma flexible."` - Explica el beneficio
- ✅ Uso de "tú" en todo el proyecto
- ✅ Términos financieros simples (saldo, gasto, ingreso)
- ✅ Español neutro sin regionalismos

---

## Plan de Corrección

### Incremento 1: Errores y Estados Vacíos Críticos (~30 strings)
- Mensajes de error más empáticos
- Estados vacíos con call-to-action
- **Impacto:** Alto (experiencia en momentos frustrantes)

### Incremento 2: Alertas y Confirmaciones (~15 strings)
- Tono más conversacional en eliminaciones
- Confirmaciones menos frías
- **Impacto:** Medio

### Incremento 3: Onboarding (~10 strings)
- Primera impresión más cálida
- Agregar personalidad de "amigo financiero"
- **Impacto:** Alto (primera experiencia)

### Incremento 4: Emojis y Celebraciones (~20 strings)
- Agregar emojis moderados donde aporten
- Mensajes de celebración por logros
- **Impacto:** Medio (diferenciación de marca)

---

## Strings a Modificar (Lista Completa)

### Errores (Prioridad 1)
```
exchangeRate.loadError
import.error
import.fileUrlError
export.exportError
common.unknownError
common.saveError
common.deleteError
settings.deleteDataError
settings.deleteDataUnknownError
settings.iconChangeFailed
account.deleteError
```

### Estados Vacíos (Prioridad 1)
```
empty.noData
empty.noTransactions
empty.noFavorites
empty.noTags
empty.noAccounts
empty.noCategories
empty.noSubcategories
search.noResults
records.noRecords
budgets.empty.title
budgets.empty.message
budgets.widget.noFavorites.title
budgets.widget.noFavorites.message
favorites.noFavorites
scheduled.empty.title
scheduled.empty.message
scheduled.widget.empty.title
scheduled.widget.empty.message
subscriptions.empty.title
subscriptions.empty.message
widget.noExpensesPeriod
widget.noRecordsForFilters
statistics.noRecordsFiltered
statistics.noDataToShow
```

### Alertas (Prioridad 2)
```
alert.unsavedChanges
alert.confirmDelete
alert.deleteWarning
records.deleteConfirmTitle
budgets.delete.confirm.title
budgets.delete.confirm.message
tag.deleteConfirmation
category.deleteConfirmTitle
category.deleteConfirmMessage
subcategory.deleteConfirmTitle
subcategory.deleteConfirmMessage
scheduled.delete.confirm.title
scheduled.delete.confirm.message
settings.deleteDataConfirmation
settings.deleteDataWarning
```

### Onboarding (Prioridad 3)
```
onboarding.welcomeTitle
onboarding.welcomeSubtitle
onboarding.finish
```

---

*Este documento sirve como guía para la implementación de correcciones de brand voice.*
