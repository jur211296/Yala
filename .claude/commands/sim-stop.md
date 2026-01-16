Detiene la captura de logs y cierra el simulador.

PASOS:
1. Termina el proceso de captura de logs (usa el PID guardado)

2. Cierra la app en el simulador:
   ```bash
   xcrun simctl terminate booted com.tuapp.Neto
   ```

3. Opcionalmente apaga el simulador:
   ```bash
   xcrun simctl shutdown "iPhone 17 Pro Max"
   ```

4. Informa: "Simulador detenido, logs guardados en /tmp/neto-sim-logs.txt"

Estos comandos te permiten un flujo más ágil: inicias el simulador con logs automáticos, cuando ves algo raro ejecutas `/sim-logs` para entender qué pasó, y cuando terminas ejecutas `/sim-stop` para limpiar.
