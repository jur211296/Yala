---
name: desarmar-desde-mas-sitios-reparte-lo-compartido
description: Al ampliar desde dónde se llama un desarme/clear, lee qué más retira por dentro — el 27-sep `clearICloudCorpusWipeArm` se llevaba un neutro durable que también era del cierre de sesión
metadata:
  type: feedback
---

**Cuando un arreglo hace que un desarme corra en más sitios (quitar su condición, llamarlo desde más fases), abre el
desarme y lista cada key que toca, y para cada una: ¿quién más la arma?** El 27-sep (#279) `leaveGate()` pasó a desarmar
desde todas las fases. Mis tests, mis mutantes y el build estaban verdes; la lente de estados durables cazó que
`clearICloudCorpusWipeArm` retira también el neutro durable, que arma igual el cierre de sesión. Antes eso solo pasaba
desde los fallos; ahora pasaba al volver desde «Encontramos datos» tras un kill.

Mi primer parche fue un guard en el llamador («sin arm, no desarmes»). No cubría el caso con los dos dueños puestos.
Lo que sirvió fue una marca de dueño en el escritor, y entonces el guard sobraba (ver
[[el-guard-va-dentro-del-escritor]]).

**Why:** un clear con varias keys dentro parece una sola operación desde fuera, y una de esas keys puede tener otro
dueño. Ampliar los llamadores amplía a quién le quita lo compartido. Ningún test del llamador lo ve.

**How to apply:** antes de quitar una condición o añadir llamadas a un `clear…`/`disarm…`, haz grep del cuerpo del
clear y de cada `arm…` de sus keys. Si alguna tiene dos escritores, decide la propiedad en el escritor, no con un guard
en el llamador. Y un «dejarlo huérfano no cuelga a nadie» se mide: aquí seis sitios reseteaban el flag que lo volvía inerte.
