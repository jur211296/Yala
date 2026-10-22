# QA Automation — Yala iOS

Automated QA scripts using [agent-device](https://github.com/callstackincubator/agent-device) for iOS simulator testing.

## Tanda pendiente

Los tickets de `tickets/qa/` **no se drenan de uno en uno**: se acumulan y se hacen juntos (decisión del
owner, 2026-09-03). El guion agrupado por montaje está en **[`guion-tanda.md`](guion-tanda.md)** — hoy
son 20 tickets en 4 montajes, y siete de ellos comparten los mismos dos teléfonos.

Al mover un ticket a `qa/` o sacarlo de ahí, actualiza también ese guion.

## Prerequisites

- `agent-device` v0.9+ (`npm install -g agent-device`)
- Xcode + iOS Simulator (iPhone 17 Pro)
- Yala app built and installed on simulator

## Quick Start

```bash
# Run all suites
./qa/runner.sh

# Run single suite
./qa/runner.sh --suite 05

# Run single scenario
./qa/runner.sh --suite 01 --scenario s1.1

# Start from suite 06
./qa/runner.sh --from 06

# Preview what would run
./qa/runner.sh --dry-run
```

## Structure

```
qa/
├── runner.sh          # Master runner
├── manifest.json      # Automation coverage classification
├── fixtures/          # Reusable precondition scripts
│   ├── fresh-install.json
│   ├── onboarding-complete.json
│   ├── with-accounts.json
│   └── with-transactions.json
└── suites/            # Test scripts by section
    ├── 01-onboarding/
    ├── 02-accounts/
    ├── ...
    └── 14-edge-cases/
```

## Naming Convention

`s{section}.{number}-{slug}.json` maps to `QA-SCENARIOS.md` escenario numbers.

## Writing Scripts

Each script is a JSON array of agent-device batch steps:

```json
[
  { "command": "find", "positionals": ["Guardar", "click"], "flags": {} },
  { "command": "wait", "positionals": ["1500"], "flags": {} },
  { "command": "is", "positionals": ["visible", "label=\"Cuenta\""], "flags": {} },
  { "command": "screenshot", "positionals": ["{{SCREENSHOT_DIR}}/result.png"], "flags": {} }
]
```

### Rules
- Use `find "text"` instead of `@eN` refs (stable across UI changes)
- Use `id="..."` for elements with accessibilityIdentifier
- Max 20 steps per file — split larger scenarios
- Always `wait` after navigation/taps
- Always `screenshot` at verification points
- `{{SCREENSHOT_DIR}}` and `{{APP_PATH}}` are replaced by runner.sh

## Results

Results are saved to `/tmp/qa/{timestamp}/`:
- `screenshots/` — visual evidence per suite
- `reports/` — JSON results per scenario

## Coverage

**SSOT de cobertura: `coverage-index.json`** (validar: `bash qa/validate-coverage.sh`). `manifest.json` quedó deprecado (solo cubría secciones 1-15). 39 fixtures con JSON inválido movidas a `_deprecated/` (ver su README). Los scripts agent-device restantes (70) cubren flujos visuales/exploratorios; lo determinístico migra a XCUITest (`YalaUITests`).
