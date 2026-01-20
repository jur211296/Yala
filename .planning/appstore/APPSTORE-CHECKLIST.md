# App Store Preparation Checklist

## Overview

Este documento guía la preparación de assets y metadata para publicar Neto en App Store.

**Idiomas soportados:** ES (principal), EN, DE, FR, IT, PT

---

## 1. Screenshots

### Tamaños Requeridos (iOS)

| Dispositivo | Resolución | Requerido |
|-------------|------------|-----------|
| iPhone 6.9" (16 Pro Max) | 1320 x 2868 px | Recomendado |
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 px | **Obligatorio** |
| iPhone 6.5" (11 Pro Max) | 1284 x 2778 px | Alternativa |
| iPhone 5.5" (8 Plus) | 1242 x 2208 px | Opcional |

**Nota:** App Store Connect acepta 6.7" y escala automáticamente para dispositivos menores.

### Screenshots Sugeridos (5-10 por idioma)

| # | Pantalla | Qué mostrar |
|---|----------|-------------|
| 1 | Panel | Vista principal con balance, widgets de gastos y presupuestos |
| 2 | Trends | Gráfica de tendencia con tooltip activo |
| 3 | Categories | Pie chart de categorías con detalle |
| 4 | Records | Lista de transacciones con filtros activos |
| 5 | Nueva transacción | Formulario con calculadora visible |
| 6 | Presupuestos | Lista de presupuestos con progreso |
| 7 | Pagos planificados | Calendario de suscripciones |
| 8 | Configuración | Personalización de moneda/periodo |

### Checklist Screenshots

- [ ] Crear datos de demo atractivos (balances realistas, variedad de categorías)
- [ ] Capturar en modo claro (principal)
- [ ] Capturar en modo oscuro (opcional, como screenshots adicionales)
- [ ] Verificar que no haya datos personales visibles
- [ ] Exportar en PNG sin compresión

### Cómo Capturar (Xcode)

1. Ejecutar app en Simulator con dispositivo 6.7" (iPhone 15 Pro Max)
2. Navegar a la pantalla deseada
3. `Cmd + S` para guardar screenshot
4. Screenshots se guardan en Desktop por defecto

---

## 2. App Metadata

### Campos Requeridos

| Campo | Límite | Descripción |
|-------|--------|-------------|
| App Name | 30 chars | Nombre en App Store |
| Subtitle | 30 chars | Descripción corta bajo el nombre |
| Promotional Text | 170 chars | Texto destacado (editable sin review) |
| Description | 4000 chars | Descripción completa |
| Keywords | 100 chars | Palabras clave separadas por coma |
| What's New | 4000 chars | Notas de versión |
| Support URL | URL | Enlace a soporte |
| Privacy Policy URL | URL | **Obligatorio** |

### Categorías App Store

- **Categoría principal:** Finance
- **Categoría secundaria:** Productivity (opcional)

---

## 3. Metadata por Idioma

### Español (ES) - Principal

```
App Name: Neto
Subtitle: Finanzas personales claras
Promotional Text: Controla tus gastos, entiende tu dinero. Sin complicaciones.
Keywords: finanzas,gastos,presupuesto,dinero,cuentas,ahorro,balance,personal
```

### English (EN)

```
App Name: Neto
Subtitle: Clear personal finances
Promotional Text: Track expenses, understand your money. No complications.
Keywords: finance,expenses,budget,money,accounts,savings,balance,personal
```

### Deutsch (DE)

```
App Name: Neto
Subtitle: Klare persönliche Finanzen
Promotional Text: Verfolge Ausgaben, verstehe dein Geld. Ohne Komplikationen.
Keywords: finanzen,ausgaben,budget,geld,konten,sparen,bilanz,persönlich
```

### Français (FR)

```
App Name: Neto
Subtitle: Finances personnelles claires
Promotional Text: Suivez vos dépenses, comprenez votre argent. Sans complications.
Keywords: finances,dépenses,budget,argent,comptes,épargne,solde,personnel
```

### Italiano (IT)

```
App Name: Neto
Subtitle: Finanze personali chiare
Promotional Text: Traccia le spese, comprendi i tuoi soldi. Senza complicazioni.
Keywords: finanze,spese,budget,soldi,conti,risparmio,bilancio,personale
```

### Português (PT)

```
App Name: Neto
Subtitle: Finanças pessoais claras
Promotional Text: Acompanhe gastos, entenda seu dinheiro. Sem complicações.
Keywords: finanças,gastos,orçamento,dinheiro,contas,poupança,saldo,pessoal
```

---

## 4. Descripción Completa

### Español (plantilla base)

```
Neto te ayuda a entender tus finanzas personales con claridad.

REGISTRA TUS GASTOS
• Añade transacciones rápidamente con calculadora integrada
• Organiza por categorías y subcategorías personalizables
• Etiqueta gastos para análisis detallado
• Soporta múltiples cuentas y monedas

VISUALIZA TUS TENDENCIAS
• Gráficas interactivas de gastos e ingresos
• Comparativas vs periodo anterior
• Desglose por categorías con pie charts
• Filtros flexibles por fecha, cuenta y etiquetas

CONTROLA TU PRESUPUESTO
• Define presupuestos por categoría
• Seguimiento visual del progreso
• Alertas cuando te acercas al límite

PLANIFICA TUS PAGOS
• Gestiona suscripciones y pagos recurrentes
• Calendario de próximos pagos
• Nunca olvides un pago importante

PERSONALIZA TU EXPERIENCIA
• 7 monedas soportadas (PEN, USD, EUR, MXN, COP, BRL, GBP)
• Modo claro y oscuro
• Configura qué widgets ver en tu panel
• Exporta e importa tus datos

Neto es 100% offline y tus datos se quedan en tu dispositivo.
```

---

## 5. Privacy Policy

### Opciones

1. **GitHub Pages** (gratis) - Crear repo con página estática
2. **Notion** (gratis) - Página pública con política
3. **Sitio propio** - Si ya existe dominio

### Contenido Mínimo

La política debe cubrir:
- [ ] Qué datos recopila la app (ninguno - todo local)
- [ ] Cómo se almacenan los datos (en dispositivo)
- [ ] Si se comparten datos con terceros (no)
- [ ] Derechos del usuario sobre sus datos
- [ ] Contacto para preguntas de privacidad

---

## 6. Checklist Final

### Assets
- [ ] Screenshots 6.7" en 6 idiomas (mínimo 3 por idioma)
- [ ] App Icon 1024x1024 (ya existe en Assets.xcassets)

### Metadata
- [ ] App Name verificado en todos los idiomas
- [ ] Subtitle en 6 idiomas
- [ ] Keywords optimizados por idioma (100 chars max)
- [ ] Descripción completa en 6 idiomas
- [ ] Promotional Text en 6 idiomas

### Legal
- [ ] Privacy Policy URL activa y accesible
- [ ] Support URL (puede ser email o página)

### App Store Connect
- [ ] Cuenta de desarrollador activa ($99/año)
- [ ] App creada en App Store Connect
- [ ] Build subido desde Xcode
- [ ] TestFlight configurado para beta

---

## Progreso

| Item | Status |
|------|--------|
| Estructura de carpetas | Completado |
| Documentación de requisitos | Completado |
| Metadata ES | Pendiente revisión |
| Metadata EN/DE/FR/IT/PT | Pendiente revisión |
| Descripción completa | Pendiente revisión |
| Privacy Policy | Pendiente |
| Screenshots | Pendiente (manual) |

---

*Última actualización: 2026-01-20*
