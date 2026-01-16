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
   xcodebuild -scheme Neto \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -derivedDataPath build \
     build

   xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Neto.app
   xcrun simctl launch --console booted com.tuapp.Neto
   ```

5. Inicia captura de logs en background:
   ```bash
   xcrun simctl spawn booted log stream --level debug --predicate 'processImagePath contains "Neto"' > /tmp/neto-sim-logs.txt &
   ```

6. Guarda el PID del proceso de logging
