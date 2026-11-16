# Préstamos y conectores de IA frente a Vuelto, Neto y Qalta (16-nov-2026)

El informe es una página visual: https://claude.ai/artifact/QzRNwaoVQqWtFhixL3q7wy. Su fuente es `informe.html`, en esta misma carpeta.
Las tres elecciones de Jürgen se guardan en la base de datos de la página (colección `decisiones`, documentos
`prestamos`, `panel` y `directorio`). Solo él puede escribir ahí. Para leerlas: `ArtifactData list`.

## Fuentes medidas el 16-nov

- **Vuelto 1.0.7** (13-nov). Ficha de la App Store de Perú, id6816194818. Las notas de la versión traen, textual: préstamos con personas,
  cobros y pagos, el estado «te debe / le debes / saldado», y «préstamos de banco con cuotas e intereses». La ficha no dice
  cómo calcula los intereses ni si los préstamos son Premium.
- **Neto 2.4.28** (15-nov). Ficha de la App Store de Perú, id6757704061. Conecta Claude y ChatGPT, «En Ajustes › Conexiones ves qué ha
  hecho y lo desconectas». Solo para Neto Pro. Los pasos para conectar no están publicados: ni la ficha, ni netoapp.es,
  ni su guía de uso los traen.
- **Qalta AI 2.2.0** (15-nov; la conexión con IA llegó en la 2.1.0, del 30-oct). Ficha id6756010294 y qalta.app/es/mcp. En ChatGPT tiene
  una app publicada (instalar → conectar → iniciar sesión → aprobar). Para los demás asistentes, hay que pegar `mcp.qalta.app/mcp` a mano.
  Solo funciona con espacios en la nube. No se ve que tenga un panel de conexiones en la app. Sus «Deudas» existen desde la 1.17.
- **Yala, en la rama 2.3.** Grupos (saldos, liquidar, simplificar, recordatorio de deudas, partes de préstamo del puente). El
  tipo de cuenta «Préstamo» es solo una etiqueta. Del conector salen `mcp/CONECTAR-TU-IA.md` y el ticket de backlog
  `claude-mcp-connected-apps-in-the-app`. También las cards de la 2.3 y la 2.4 del tablero.

## Hallazgo que corrige el encargo

El encargo decía que los préstamos de banco con cuotas e intereses no tenían card. En realidad aparecen en la nota de **dos**
cards de la 2.4 («Seguimiento de deudas personales» y «Pagos en cuotas»), pero ninguna de las dos los tiene a su cargo. Además, las dos
siguen diciendo «implementada en 2.2» en su criterio de cierre.

## Cifras del ejemplo

Préstamo de S/ 10 000 a una TEA de 18,5 % en 24 cuotas: la TEM es (1,185)^(1/12) − 1 = 1,425 %. La cuota francesa da S/ 494,88. Tras 7 cuotas,
el saldo queda en S/ 7 425,08, y los intereses totales suman S/ 1 877,09.
