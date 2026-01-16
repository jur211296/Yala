Muestra logs recientes del simulador filtrados por severidad.

PARÁMETROS OPCIONALES:
- timeframe: últimos N minutos (default: 1)
- level: debug|info|error (default: all)

PASOS:
1. Lee /tmp/neto-sim-logs.txt
2. Filtra últimos N minutos basándote en timestamps
3. Si se especificó level, filtra por ese nivel
4. Formatea salida:
   ```
   [TIMESTAMP] [LEVEL] [Mensaje]
   ```
5. Presenta los logs más relevantes al usuario
6. Si hay errores, resáltalos claramente

EJEMPLO DE USO:
Usuario: "Ejecuta /sim-logs timeframe=2 level=error"
Respuesta: Logs de errores de los últimos 2 minutos
