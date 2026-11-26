import xml.etree.ElementTree as ET
frames = {}   # id -> (name, binary)
bts = {}      # id -> [frame names]
threads = {}  # id -> fmt
binaries = {}


def frame_of(el):
    ref = el.get("ref")
    if ref:
        return frames.get(ref)
    name = el.get("name") or "?"
    b = el.find("binary")
    bname = None
    if b is not None:
        if b.get("ref"):
            bname = binaries.get(b.get("ref"))
        else:
            bname = b.get("name")
            binaries[b.get("id")] = bname
    frames[el.get("id")] = (name, bname)
    return frames[el.get("id")]


samples = []  # (t_s, is_main, [(name, bin)])
for ev, el in ET.iterparse(path, events=("end",)):
    if el.tag != "row":
        continue
    t = th = None
    stack = None
    for c in el:
        if c.tag == "sample-time":
            t = int(c.text) / 1e9 if c.text else None
            if c.get("id"):
                threads["st" + c.get("id")] = t
            elif c.get("ref"):
                t = threads.get("st" + c.get("ref"))
        elif c.tag == "thread":
            if c.get("ref"):
                th = threads.get(c.get("ref"))
            else:
                th = c.get("fmt")
                threads[c.get("id")] = th
        elif c.tag in ("backtrace", "tagged-backtrace"):
            if c.get("ref"):
                stack = bts.get(c.get("ref"))
            else:
                stack = [frame_of(f) for f in c.findall("frame")]
                bts[c.get("id")] = stack
    if t is not None and stack is not None:
        samples.append((t, bool(th and th.startswith("Main Thread")), stack))
    el.clear()

