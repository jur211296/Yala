---
description: Inicia el simulador con la app y captura logs en tiempo real.
---

Inicia el simulador con la app y captura logs en tiempo real.

PASOS:
1. Verifica que el build esté pasando (ejecuta /verify-quick)

2. Identifica el simulador disponible:
   ```bash
   xcrun simctl list devices | grep "iPhone 17 Pro"
   ```

3. Si está apagado, enciéndelo:
   ```bash
   xcrun simctl boot "iPhone 17 Pro"
   ```

4. Instala y lanza la app:
   ```bash
   xcodebuild -scheme Yala \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -derivedDataPath build \
     build

   xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Yala.app
   xcrun simctl launch --console booted com.jur.Yala
   ```

5. Inicia captura de logs en background:
   ```bash
   xcrun simctl spawn booted log stream --level debug --predicate 'processImagePath contains "Yala"' > /tmp/yala-sim-logs.txt &
   ```

6. Guarda el PID del proceso de logging
