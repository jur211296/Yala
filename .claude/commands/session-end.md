Finaliza la sesión actual y genera resumen.

PASOS:
1. Lee el session log actual desde /tmp/current-session

2. Analiza el contenido completo del log para generar resumen:
   - ¿Se logró el objetivo declarado al inicio?
   - Cuántos builds/tests se ejecutaron y resultados
   - Cuántos commits se realizaron
   - Problemas encontrados y si se resolvieron
   - Tiempo aproximado invertido (diferencia entre primer y último timestamp)

3. Agrega sección de Outcomes al log:
   ```markdown
   ## Outcomes
   - Goal achieved: [Yes/No/Partial]
   - Commits: [número y lista con hashes]
   - Builds: [successful/failed count]
   - Tests: [passed/failed count]
   - Time invested: [aproximado]
   - Key learnings:
     * [algo importante que descubriste]
     * [decisión tomada]
   - Unfinished work: [si quedó algo pendiente]
   ```

4. Presenta este resumen al usuario

5. Pregunta: "¿Quieres agregar alguna nota final a esta sesión?"

6. Si el usuario agrega notas, inclúyelas en Outcomes

7. Limpia el archivo temporal:
   ```bash
   rm /tmp/current-session
   ```

8. Informa: "Sesión cerrada. Log guardado en [ruta]"
