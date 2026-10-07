import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "components", "texture")
os.makedirs(OUT, exist_ok=True)
def path(d, cls, extra=""): return '<path class="%s" d="%s"%s/>' % (cls, d, extra)
SVG_OPEN = '<svg viewBox="%s" preserveAspectRatio="%s" aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg">'

def svg_signature():
    s = gen.signature()
    g = [SVG_OPEN % ("0 0 1000 800", "xMaxYMax slice")]
    g.append('<g>')
    for i, d in enumerate(s["wing"]): g.append(path(d, "s" + (" dense" if i % 2 else "")))
    g.append('</g><g>')
    for i, d in enumerate(s["blade"][1:]): g.append(path(d, "s2" + (" dense" if i % 2 else "")))
    for i, d in enumerate(s["arcs"]): g.append(path(d, "s2" + (" dense" if i in (1, 3) else "")))
    g.append('</g>')
    g.append(path(s["gold"], "g"))
    g.append(path(s["crescent"], "fl"))
    g.append('</svg>')
    return "".join(g)

def svg_flow():
    paths, br, rings, dots = gen.flow()
    g = [SVG_OPEN % ("0 0 1440 420", "xMidYMid slice")]
    for i, d in enumerate(paths): g.append(path(d, "s2" if i == 0 else "s"))
    for d in br: g.append(path(d, "s dense"))
    for (x, y, r) in rings: g.append('<circle class="s2" cx="%s" cy="%s" r="%s"/>' % (gen.f(x), gen.f(y), gen.f(r)))
    for (x, y, r) in dots: g.append('<circle class="nd" cx="%s" cy="%s" r="%s"/>' % (gen.f(x), gen.f(y), gen.f(r)))
    g.append('</svg>'); return "".join(g)

def svg_network():
    links, drift, drift2, link_b, rings, dots, papers = gen.network()
    g = [SVG_OPEN % ("0 0 1200 700", "xMidYMid slice")]
    g.append('<defs><linearGradient id="txn-fade" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="currentColor" stop-opacity="1"/><stop offset="1" stop-color="currentColor" stop-opacity="0"/></linearGradient></defs>')
    for d in links: g.append(path(d, "s2"))
    g.append(path(drift, "s drift")); g.append(path(drift2, "s drift dense"))
    for d in link_b: g.append(path(d, "s dense"))
    for (x, y, r) in rings: g.append('<circle class="s2" cx="%s" cy="%s" r="%s"/>' % (gen.f(x), gen.f(y), gen.f(r)))
    for (x, y, r) in dots: g.append('<circle class="nd" cx="%s" cy="%s" r="%s"/>' % (gen.f(x), gen.f(y), gen.f(r)))
    for (x, y) in papers:
        g.append('<rect class="s dense" x="%s" y="%s" width="15" height="19" rx="1.5"/>' % (x, y))
        g.append('<path class="s dense" d="M%s %s h8 M%s %s h6"/>' % (x+3.5, y+7, x+3.5, y+12))
    g.append('<path class="g" d="M968 176 C830 250 640 470 190 560"/>')
    g.append('</svg>'); return "".join(g)

def svg_converge():
    streams, trunk, final, F = gen.converge()
    g = [SVG_OPEN % ("0 0 900 700", "xMaxYMid slice")]
    for i, d in enumerate(streams): g.append(path(d, "s" + (" dense" if i in (1, 3, 5) else "")))
    g.append(path(trunk, "s2"))
    g.append(path(final, "g"))
    g.append('<circle class="s2" cx="%s" cy="%s" r="6.5"/><circle class="nd" cx="%s" cy="%s" r="2.4"/>' % (F[0], F[1], F[0], F[1]))
    g.append('</svg>'); return "".join(g)

def svg_limb():
    S = gen.limb()
    g = [SVG_OPEN % ("0 0 600 1000", "xMaxYMid slice")]
    for k in ("scapula", "humerus", "ulna", "radius", "carpus"): g.append(path(S[k], "s"))
    for k in ("spine", "glenoid", "head", "humerus_t", "humerus_t2", "ulna_t", "radius_t"): g.append(path(S[k], "s2 dense"))
    for d in S["meta"]: g.append(path(d, "s"))
    for d in gen.limb_extra(): g.append(path(d, "s2 dense"))
    g.append(path(S["axis"], "s2 dash"))
    for d in S["dim"]: g.append(path(d, "s2 dense"))
    for d, (cx, cy, r) in S["leaders"]:
        g.append(path(d, "s2 dense")); g.append('<circle class="s2 dense" cx="%s" cy="%s" r="%s"/>' % (cx, cy, r))
    g.append('</svg>'); return "".join(g)

def svg_organic():
    rings, cells = gen.organic()
    g = [SVG_OPEN % ("0 0 1200 800", "xMaxYMid slice")]
    for i, d in enumerate(rings): g.append(path(d, "gr" if i == 4 else ("s2" if i % 2 else "s") + (" dense" if i in (1, 5) else "")))
    for d, (nx, ny, nr) in cells:
        g.append(path(d, "s2")); g.append('<circle class="nd" cx="%s" cy="%s" r="%s"/>' % (gen.f(nx), gen.f(ny), gen.f(nr)))
    g.append('</svg>'); return "".join(g)

ART = {"signature": svg_signature(), "flow": svg_flow(), "network": svg_network(), "converge": svg_converge(), "limb": svg_limb(), "organic": svg_organic()}

if __name__ == "__main__":
    for k, v in ART.items(): print(k, len(v), "bytes")
