"""Genera index.html incrustando las capturas de capturas/ en fuente/pagina.html."""
import base64, pathlib, re
aqui = pathlib.Path(__file__).resolve().parent
raiz = aqui.parent
html = (aqui / "pagina.html").read_text(encoding="utf-8")
def img(m):
    datos = (raiz / "capturas" / f"{m.group(1)}.jpg").read_bytes()
    return "data:image/jpeg;base64," + base64.b64encode(datos).decode()
(raiz / "index.html").write_text(re.sub(r"\{\{IMG:([\w-]+)\}\}", img, html), encoding="utf-8")
print("index.html", (raiz / "index.html").stat().st_size, "bytes")
