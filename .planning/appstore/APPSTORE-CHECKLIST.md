# App Store Preparation Checklist

## Overview

Este documento guía la preparación de assets y metadata para publicar Yala en App Store.

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

1. Ejecutar app en Simulator con dispositivo 6.7" (iPhone 17 Pro)
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
App Name: Yala
Subtitle: Finanzas personales claras
Promotional Text: Controla tus gastos, entiende tu dinero. Sin complicaciones.
Keywords: finanzas,gastos,presupuesto,dinero,cuentas,ahorro,balance,personal
```

### English (EN)

```
App Name: Yala
Subtitle: Clear personal finances
Promotional Text: Track expenses, understand your money. No complications.
Keywords: finance,expenses,budget,money,accounts,savings,balance,personal
```

### Deutsch (DE)

```
App Name: Yala
Subtitle: Klare persönliche Finanzen
Promotional Text: Verfolge Ausgaben, verstehe dein Geld. Ohne Komplikationen.
Keywords: finanzen,ausgaben,budget,geld,konten,sparen,bilanz,persönlich
```

### Français (FR)

```
App Name: Yala
Subtitle: Finances personnelles claires
Promotional Text: Suivez vos dépenses, comprenez votre argent. Sans complications.
Keywords: finances,dépenses,budget,argent,comptes,épargne,solde,personnel
```

### Italiano (IT)

```
App Name: Yala
Subtitle: Finanze personali chiare
Promotional Text: Traccia le spese, comprendi i tuoi soldi. Senza complicazioni.
Keywords: finanze,spese,budget,soldi,conti,risparmio,bilancio,personale
```

### Português (PT)

```
App Name: Yala
Subtitle: Finanças pessoais claras
Promotional Text: Acompanhe gastos, entenda seu dinheiro. Sem complicações.
Keywords: finanças,gastos,orçamento,dinheiro,contas,poupança,saldo,pessoal
```

---

## 4. Descripción Completa

### Español (plantilla base)

```
Yala te ayuda a entender tus finanzas personales con claridad.

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

Yala es 100% offline y tus datos se quedan en tu dispositivo.
```

### English (EN)

```
Yala helps you understand your personal finances with clarity.

TRACK YOUR EXPENSES
• Add transactions quickly with built-in calculator
• Organize by customizable categories and subcategories
• Tag expenses for detailed analysis
• Supports multiple accounts and currencies

VISUALIZE YOUR TRENDS
• Interactive charts for expenses and income
• Comparisons vs previous period
• Category breakdown with pie charts
• Flexible filters by date, account, and tags

CONTROL YOUR BUDGET
• Set budgets by category
• Visual progress tracking
• Alerts when approaching limits

PLAN YOUR PAYMENTS
• Manage subscriptions and recurring payments
• Calendar of upcoming payments
• Never miss an important payment

CUSTOMIZE YOUR EXPERIENCE
• 7 currencies supported (PEN, USD, EUR, MXN, COP, BRL, GBP)
• Light and dark mode
• Configure which widgets to display
• Export and import your data

Yala is 100% offline and your data stays on your device.
```

### Deutsch (DE)

```
Yala hilft dir, deine persönlichen Finanzen klar zu verstehen.

ERFASSE DEINE AUSGABEN
• Füge Transaktionen schnell mit integriertem Rechner hinzu
• Organisiere nach anpassbaren Kategorien und Unterkategorien
• Markiere Ausgaben für detaillierte Analyse
• Unterstützt mehrere Konten und Währungen

VISUALISIERE DEINE TRENDS
• Interaktive Diagramme für Ausgaben und Einnahmen
• Vergleiche mit vorherigem Zeitraum
• Kategorieaufschlüsselung mit Kreisdiagrammen
• Flexible Filter nach Datum, Konto und Tags

KONTROLLIERE DEIN BUDGET
• Lege Budgets nach Kategorie fest
• Visuelle Fortschrittsverfolgung
• Warnungen bei Annäherung an Limits

PLANE DEINE ZAHLUNGEN
• Verwalte Abonnements und wiederkehrende Zahlungen
• Kalender der anstehenden Zahlungen
• Verpasse nie eine wichtige Zahlung

PERSONALISIERE DEIN ERLEBNIS
• 7 Währungen unterstützt (PEN, USD, EUR, MXN, COP, BRL, GBP)
• Heller und dunkler Modus
• Konfiguriere angezeigte Widgets
• Exportiere und importiere deine Daten

Yala ist 100% offline und deine Daten bleiben auf deinem Gerät.
```

### Français (FR)

```
Yala t'aide à comprendre tes finances personnelles avec clarté.

ENREGISTRE TES DÉPENSES
• Ajoute des transactions rapidement avec calculatrice intégrée
• Organise par catégories et sous-catégories personnalisables
• Étiquette les dépenses pour une analyse détaillée
• Prend en charge plusieurs comptes et devises

VISUALISE TES TENDANCES
• Graphiques interactifs des dépenses et revenus
• Comparaisons avec la période précédente
• Répartition par catégories avec graphiques circulaires
• Filtres flexibles par date, compte et étiquettes

CONTRÔLE TON BUDGET
• Définis des budgets par catégorie
• Suivi visuel de la progression
• Alertes à l'approche des limites

PLANIFIE TES PAIEMENTS
• Gère les abonnements et paiements récurrents
• Calendrier des paiements à venir
• N'oublie jamais un paiement important

PERSONNALISE TON EXPÉRIENCE
• 7 devises prises en charge (PEN, USD, EUR, MXN, COP, BRL, GBP)
• Mode clair et sombre
• Configure les widgets affichés
• Exporte et importe tes données

Yala est 100% hors ligne et tes données restent sur ton appareil.
```

### Italiano (IT)

```
Yala ti aiuta a capire le tue finanze personali con chiarezza.

REGISTRA LE TUE SPESE
• Aggiungi transazioni rapidamente con calcolatrice integrata
• Organizza per categorie e sottocategorie personalizzabili
• Etichetta le spese per un'analisi dettagliata
• Supporta più conti e valute

VISUALIZZA LE TUE TENDENZE
• Grafici interattivi di spese e entrate
• Confronti con il periodo precedente
• Suddivisione per categorie con grafici a torta
• Filtri flessibili per data, conto ed etichette

CONTROLLA IL TUO BUDGET
• Imposta budget per categoria
• Monitoraggio visivo dei progressi
• Avvisi all'avvicinarsi dei limiti

PIANIFICA I TUOI PAGAMENTI
• Gestisci abbonamenti e pagamenti ricorrenti
• Calendario dei prossimi pagamenti
• Non perdere mai un pagamento importante

PERSONALIZZA LA TUA ESPERIENZA
• 7 valute supportate (PEN, USD, EUR, MXN, COP, BRL, GBP)
• Modalità chiara e scura
• Configura quali widget visualizzare
• Esporta e importa i tuoi dati

Yala è 100% offline e i tuoi dati rimangono sul tuo dispositivo.
```

### Português (PT)

```
Yala te ajuda a entender suas finanças pessoais com clareza.

REGISTRE SEUS GASTOS
• Adicione transações rapidamente com calculadora integrada
• Organize por categorias e subcategorias personalizáveis
• Etiquete gastos para análise detalhada
• Suporta múltiplas contas e moedas

VISUALIZE SUAS TENDÊNCIAS
• Gráficos interativos de gastos e receitas
• Comparações com período anterior
• Detalhamento por categorias com gráficos de pizza
• Filtros flexíveis por data, conta e etiquetas

CONTROLE SEU ORÇAMENTO
• Defina orçamentos por categoria
• Acompanhamento visual do progresso
• Alertas ao se aproximar dos limites

PLANEJE SEUS PAGAMENTOS
• Gerencie assinaturas e pagamentos recorrentes
• Calendário de próximos pagamentos
• Nunca perca um pagamento importante

PERSONALIZE SUA EXPERIÊNCIA
• 7 moedas suportadas (PEN, USD, EUR, MXN, COP, BRL, GBP)
• Modo claro e escuro
• Configure quais widgets exibir
• Exporte e importe seus dados

Yala é 100% offline e seus dados ficam no seu dispositivo.
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
| Metadata corta (6 idiomas) | Completado |
| Descripción completa ES | Completado |
| Descripción completa EN | Completado |
| Descripción completa DE | Completado |
| Descripción completa FR | Completado |
| Descripción completa IT | Completado |
| Descripción completa PT | Completado |
| Privacy Policy | Completado (ver PRIVACY-POLICY.md) |
| Screenshots | Pendiente (manual) |

---

*Última actualización: 2026-01-20*
