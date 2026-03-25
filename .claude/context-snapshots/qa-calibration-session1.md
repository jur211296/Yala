# Context Snapshot: QA Automation + Visual Audit

## Estado actual
- **Task #1 COMPLETADA**: Fixture onboarding-complete.json calibrado y funcionando
- **Tasks #2-10 PENDIENTES**: Calibrar suites 01-14 y validación final
- **Commits**: `6ecdd302` (105 scripts iniciales) + `2c7fbbb7` (calibración fixture onboarding)

## Técnicas descubiertas (CRÍTICO para próximas sesiones)

### Para text fields en batch:
```json
{ "command": "find", "positionals": ["a11y_identifier_name", "click"], "flags": {} },
{ "command": "type", "positionals": ["texto a escribir"], "flags": {} }
```
- **NO usar `fill`** — inyecta texto pero no trigerea onChange de SwiftUI
- **Usar `find "a11y_id" click` + `type`** — simula teclado real

### Para dismiss keyboard:
```json
{ "command": "press", "positionals": ["200", "150"], "flags": {} },
{ "command": "wait", "positionals": ["1000"], "flags": {} }
```
- `keyboard dismiss` NO soportado en iOS
- Tap en coordenadas de área vacía funciona

### Para batches largos:
```bash
AGENT_DEVICE_DAEMON_TIMEOUT_MS=180000 agent-device batch --steps-file ...
```
- Default 90s es insuficiente para flujos de 20+ pasos
- Usar `wait 2500` entre transiciones de pantalla

### Para textos ambiguos:
- `find "Cuenta Corriente"` falla si hay botón + texto con mismo nombre
- Usar `snapshot` + `press @ref` para desambiguar
- O agregar accessibilityIdentifier

### Paywall post-onboarding:
```json
{ "command": "find", "positionals": ["Quizás después", "click"], "flags": {} }
```

## Accessibility Identifiers agregados
| ID | Archivo | Campo |
|----|---------|-------|
| `onboarding_name_field` | OnboardingView.swift | Nombre de usuario |
| `onboarding_account_name` | OnboardingView.swift | Nombre de cuenta |
| `onboarding_balance` | OnboardingView.swift | Balance inicial |
| `fab_new_transaction` | PanelView.swift | FAB button |
| `new_transaction_amount` | NewTransactionView.swift | Campo monto |
| `new_transaction_save` | NewTransactionView.swift | Botón guardar |
| `toolbar_save_button` | StandardButtons.swift | YalaSaveButton |
| `primary_button` | StandardButtons.swift | YalaPrimaryButton |
| `account_name_field` | AccountFormView.swift | Nombre de cuenta |

## Textos reales de la UI (descubiertos)
- Modos: "Solo gastos", "Día a día" (Recomendado), "Saldo real"
- Categorías: "Empezar con estas categorías" / "Empezar desde cero"
- Budget: "Quiero darle seguimiento" / "Ahora no, gracias" (default)
- Privacidad: botón "Empezar"
- Tabs: "Panel", "Estadísticas", "Planificación", "Más"
- Tipos cuenta: "General", "Efectivo", "Cuenta Corriente", "Ahorros"

## Navegación real del Panel (post-onboarding)

### Tab Bar
- `find "Panel" click` — pero ambiguous (button + other). Usar snapshot + `press @e16`
- `find "Estadísticas" click` — button
- `find "Planificación" click` — button
- `find "Más" click` — ambiguous. Usar snapshot + press
- `find "Buscar" click` — button

### Navegación a Profile
- El icono de Perfil está arriba a la derecha del Panel
- `find "Perfil" click` funciona (matchea el avatar)
- Cierra con `find "Cerrar" click`

### Menú Profile — Textos EXACTOS de botones
| Sección | Botones |
|---------|---------|
| Organización | Cuentas, Categorías, Etiquetas, Presupuestos favoritos, Pagos planificados, Pagos favoritos |
| Preferencias | Personalización, Notificaciones, Divisa y Cambio, Icono de aplicación, Temas |
| IA | Entrada con voz, Entrada con imágenes, Resumen inteligente |
| Datos | Sincronización iCloud, Importar archivo, Exportar datos, Vaciar datos |
| Seguridad | Contraseña, Siri y Atajos, Permisos, Administrar suscripciones |

### Coach marks post-onboarding
- Aparecen al abrir Perfil por primera vez
- `find "Omitir guía" click` los cierra

### Paywall
- Aparece tras completar onboarding
- `find "Quizás después" click` lo cierra

## QA Calibration — COMPLETADA
- Tasks #1-10 todas completadas
- 105 scripts calibrados, dry-run 105/105 PASS
- Commits: 6ecdd302, 2c7fbbb7, b488874d, e57609ab, 6e812d08, b3351689
- Validación real pendiente (ejecutar `bash qa/runner.sh`)

## Próximo paso: Auditoría Visual
Plan aprobado en `.claude/plans/cryptic-stargazing-comet.md`
- Recorrer ~41 pantallas con agent-device
- Screenshot cada una → Claude analiza visualmente
- Reporte de hallazgos en `.planning/VISUAL-AUDIT-REPORT.md`
- Prerequisitos: app con datos de prueba (onboarding + cuentas + transacciones)
- Flujo: screenshot → Read → analizar → anotar → siguiente vista
- agent-device ya conectado, usar `AGENT_DEVICE_DAEMON_TIMEOUT_MS=180000`

### Navegación para la auditoría
- **Profile avatar**: `press 370 84` o `find "profile_avatar" click`
- **Tabs**: Panel, Estadísticas, Planificación, Más (algunos ambiguos, usar snapshot+ref)
- **Profile rows**: profile_accounts, profile_categories, profile_tags (a11y IDs)
- **Forms**: account_name_field, new_transaction_amount, etc.
- **Keyboard dismiss**: `press 200 150`
- **Paywall**: `find "Quizás después" click`
- **Coach marks**: `find "Omitir guía" click`
