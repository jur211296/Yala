---
description: Build rápido durante la implementación — solo compila y filtra lo tuyo
allowed-tools: Bash(xcodebuild:*), Bash(git:*), Bash(grep:*), Read
---

Bucle corto: ¿compila lo que acabo de escribir? Para verificar de verdad antes de commitear, usa `/gate` — este comando solo compila.

```bash
xcodebuild -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

Deja que el timeout de la propia herramienta corte si se cuelga; **no antepongas `timeout`**, que no existe en macOS y hace fallar el comando entero por un motivo que no tiene nada que ver con el build.

## Resultado

**BUILD SUCCEEDED** → filtra los warnings a los archivos que tocaste (`git status --porcelain`) e informa solo de esos. Los preexistentes de otros archivos no son tuyos.

```
✓ Build OK — N warnings en tus cambios (o ninguno)
```

**BUILD FAILED** → todos los errores, causa raíz en 3-6 líneas, archivo y línea más probables, y el cambio mínimo para que pase.

**Se cuelga o tarda muchísimo** → suele ser el simulador sin arrancar, Xcode indexando, o **el disco lleno**: `bash qa/scripts/disk-report.sh`.
