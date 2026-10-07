# Original VAI texture artwork generator (deterministic). Outputs SVG fragments (paths) as Python strings.
import math, random

def f(x): return ("%.1f" % x).rstrip("0").rstrip(".")
def P(*pts): return " ".join(f(p) for p in pts)

# ---------------- A. SIGNATURE GEOMETRY (viewBox 0 0 1000 800) ----------------
def signature():
    V0x, V0y = 600, 770
    out = {"wing": [], "blade": [], "arcs": [], "crescent": "", "gold": ""}
    # leaf-like sweeps from the upper-left converging on the vertex (echo of the mark's flared left arm)
    for i in range(8):
        y0 = 40 + i*36
        end_x = V0x + (i-3.5)*6
        out["wing"].append("M-80 %s C150 %s %s %s %s %s" % (f(y0), f(y0-100), f(430-i*5), f(300+i*14), f(end_x), f(V0y)))
    # blade: fan of hairlines at 65deg -> 57deg from the vertex (echo of the mark's tapered blade)
    for ang in (65, 63.4, 61.8, 60.2, 58.6, 57):
        a = math.radians(ang); L = 1100
        out["blade"].append("M%s %s L%s %s" % (f(V0x), f(V0y), f(V0x + L*math.cos(a)), f(V0y - L*math.sin(a))))
    out["gold"] = out["blade"][0]            # the leading edge of the blade carries the single gold hairline
    # arcs centred on the vertex, crossing sweeps and blade
    for r in (170, 290, 430, 590, 770):
        a1, a2 = math.radians(24), math.radians(158)
        x1, y1 = V0x + r*math.cos(a1), V0y - r*math.sin(a1)
        x2, y2 = V0x + r*math.cos(a2), V0y - r*math.sin(a2)
        out["arcs"].append("M%s %s A%s %s 0 0 0 %s %s" % (f(x1), f(y1), r, r, f(x2), f(y2)))
    # crescent notch (negative-space echo of the mark's comma)
    out["crescent"] = "M452 560 A104 104 0 0 0 556 664 A76 76 0 0 1 452 560Z"
    return out

# ---------------- B. REASONING LINES ----------------
def flow():   # viewBox 0 0 1440 420 : two long crossing lines, sparse nodes, short branches (atmospheric, not a diagram)
    paths = [
        "M-60 270 C190 90 430 340 660 215 S1040 120 1500 200",
        "M-60 340 C250 260 470 372 700 292 S1090 262 1500 124",
    ]
    branches = ["M300 196 L352 140", "M786 252 L842 316", "M1052 156 L1110 98", "M520 306 L566 360"]
    nodes_ring = [(352, 140, 4.5), (842, 316, 4), (1110, 98, 4.5)]
    nodes_dot = [(300, 196, 2), (786, 252, 2), (1052, 156, 2), (566, 360, 2.2), (520, 306, 1.6)]
    return paths, branches, nodes_ring, nodes_dot

def network():  # viewBox 0 0 1200 700 : ONE sparse evidence cluster (top right); faint threads drift to a single ring node (lower left)
    A = {"n1": (1090, 96), "n2": (968, 176), "n3": (1128, 246), "n4": (896, 70)}
    links = [("n1", "n2"), ("n2", "n3"), ("n4", "n2")]
    link_paths = []
    for a_, b_ in links:
        (x1, y1), (x2, y2) = A[a_], A[b_]
        mx, my = (x1+x2)/2 + (y2-y1)*0.08, (y1+y2)/2 - (x2-x1)*0.08
        link_paths.append("M%s %s Q%s %s %s %s" % (f(x1), f(y1), f(mx), f(my), f(x2), f(y2)))
    drift = "M968 176 C800 270 600 500 190 560"
    drift2 = "M1128 246 C930 330 700 520 190 560"
    link_b = []
    rings = [(1090, 96, 5), (968, 176, 4), (1128, 246, 3.6), (190, 560, 5)]
    dots = [(896, 70, 2), (190, 560, 1.8)]
    papers = [(1076, 120), (954, 196), (172, 580)]
    return link_paths, drift, drift2, link_b, rings, dots, papers

def converge():  # viewBox 0 0 900 700 : many faint evidence paths -> fewer -> one conclusion node
    R = [60, 150, 240, 340, 440, 530, 640]
    A, B, C = (640, 170), (632, 340), (640, 566)
    D, E = (470, 262), (480, 462)
    F = (330, 362)
    def link(x1, y1, x2, y2, k=0.45):
        dx = (x2 - x1) * k
        return "M%s %s C%s %s %s %s %s %s" % (f(x1), f(y1), f(x1 + dx), f(y1), f(x2 - dx), f(y2), f(x2), f(y2))
    lv1 = []
    groups = {0: A, 1: A, 2: B, 3: B, 4: B, 5: C, 6: C}
    for i, y in enumerate(R):
        mx, my = groups[i]; lv1.append(link(930, y, mx, my, 0.5))
    lv2 = [link(*A, *D), link(*B, *D), link(*C, *E)]
    lv3 = [link(*D, *F), link(*E, *F)]
    final = "M%s %s L%s %s" % (f(F[0]), f(F[1]), f(F[0] - 96), f(F[1]))
    nodes_dot = [A, B, C, D, E]
    return lv1, lv2, lv3, final, nodes_dot, F

# ---------------- C. ANATOMICAL GHOST: canine thoracic limb (lateral), original linework (viewBox 0 0 600 1000) ----------------
def limb():
    S = {}
    # scapula: fan blade with spine line
    S["scapula"] = "M236 30 C300 18 372 44 404 110 C418 142 410 176 392 206 C372 196 352 188 336 176 C290 150 252 100 236 30Z"
    S["spine"] = "M250 52 C292 98 328 144 372 194"
    S["glenoid"] = "M352 196 C360 214 382 220 398 210"
    # humerus: head, S-curved shaft, condyles
    S["humerus"] = "M338 216 C318 206 292 222 292 252 C292 276 306 290 322 292 C314 340 306 392 312 452 C316 476 308 488 296 494 C300 512 330 520 352 514 C384 508 402 494 392 474 C380 468 372 460 368 448 C364 388 372 330 366 284 C386 262 376 226 338 216Z"
    S["humerus_t"] = "M330 300 C324 352 322 406 328 446"          # shaft contour (fine)
    S["humerus_t2"] = "M350 292 C354 340 356 398 352 440"
    S["head"] = "M322 292 C336 300 352 298 366 284"
    # ulna: olecranon + long shaft
    S["ulna"] = "M264 456 C250 462 246 484 258 498 C268 508 284 510 296 504 C302 560 298 640 292 716 C290 740 298 760 306 772 C314 770 320 756 318 736 C322 660 326 570 330 514 C318 508 304 500 296 494 C288 476 280 462 264 456Z"
    S["ulna_t"] = "M300 520 C300 600 298 680 300 744"
    # radius: head, shaft, distal expansion
    S["radius"] = "M346 516 C334 520 332 536 340 546 C352 552 372 550 384 540 C388 530 380 516 346 516Z M350 548 C346 610 350 690 348 748 C346 770 340 784 342 800 C350 812 384 812 394 798 C394 780 388 764 386 744 C384 680 384 600 378 546"
    S["radius_t"] = "M362 560 C362 630 364 700 364 770"
    # carpus: small block row, metacarpals
    S["carpus"] = "M332 826 C336 816 354 814 362 820 L366 846 C356 852 340 852 330 846Z M370 820 C378 814 394 816 398 824 L396 848 C388 852 374 852 368 846Z M312 840 C312 832 322 828 330 832 L330 850 C322 852 314 850 312 840Z"
    S["meta"] = ["M326 862 L316 960", "M346 858 L342 970", "M368 858 L372 972", "M390 856 L402 960"]
    # plate marks: axis, dimension lines, leader circles (no text)
    S["axis"] = "M330 20 L330 990"
    S["dim"] = ["M470 214 L470 494", "M462 214 L478 214", "M462 494 L478 494", "M470 516 L470 800", "M462 516 L478 516", "M462 800 L478 800"]
    S["leaders"] = [("M404 258 L486 258 L504 244", (508, 241, 5)), ("M392 556 L486 556 L504 570", (508, 573, 5)), ("M300 604 L190 604 L172 590", (168, 587, 5))]
    return S

# ---------------- D. ORGANIC SCIENCE (viewBox 0 0 1200 800) ----------------
def i0(x): return str(int(round(x)))
def catmull_closed(pts):
    f = i0
    n = len(pts); d = "M%s %s" % (f(pts[0][0]), f(pts[0][1]))
    for i in range(n):
        p0, p1, p2, p3 = pts[(i-1) % n], pts[i], pts[(i+1) % n], pts[(i+2) % n]
        c1 = (p1[0] + (p2[0]-p0[0])/6, p1[1] + (p2[1]-p0[1])/6)
        c2 = (p2[0] - (p3[0]-p1[0])/6, p2[1] - (p3[1]-p1[1])/6)
        d += " C%s %s %s %s %s %s" % (f(c1[0]), f(c1[1]), f(c2[0]), f(c2[1]), f(p2[0]), f(p2[1]))
    return d + "Z"

def organic():
    rnd = random.Random(7)
    cx, cy = 980, 470
    rings = []
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    for k in range(1, 9):
        base = 46 + k*52 + k*k*2.4
        pts = []
        for j in range(22):
            th = j / 22 * 2*math.pi
            wob = 1 + 0.10*math.sin(2*th + ph[0] + k*0.18) + 0.07*math.sin(3*th + ph[1] + k*0.27) + 0.04*math.sin(5*th + ph[2] + k*0.4)
            pts.append((cx + base*wob*1.12*math.cos(th), cy + base*wob*0.92*math.sin(th)))
        rings.append(catmull_closed(pts))
    cells = []
    for (x, y, r) in [(560, 250, 20), (610, 292, 12), (520, 330, 15), (700, 160, 11)]:
        pts = [(x + r*(1 + 0.16*math.sin(2*t + x)) * math.cos(t), y + r*(1 + 0.16*math.cos(3*t + y)) * math.sin(t)) for t in [j/18*2*math.pi for j in range(18)]]
        cells.append((catmull_closed(pts), (x + r*0.12, y - r*0.1, r*0.28)))
    return rings, cells

# ====================== v2 REDESIGNS (replace the first drafts above) ======================
def shift(d_nums, dx, dy):
    out = []
    for i, v in enumerate(d_nums): out.append(v + (dx if i % 2 == 0 else dy))
    return out

def signature():  # ribbon of translated sweeps + a narrow blade family crossing it + two OFFSET (non-concentric) arcs + a crescent
    out = {"wing": [], "blade": [], "arcs": [], "crescent": "", "gold": ""}
    base = [-120, 190, 190, 20, 540, 90, 650, 400, 700, 540, 700, 690, 676, 860]   # M p0  C p1 p2 p3  C p4 p5 p6
    for i in range(9):
        n = shift(base, i*13, i*26)
        out["wing"].append("M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s" % tuple(f(v) for v in n))
    for j in range(3):
        x = 420 + j*46
        out["blade"].append("M%s 900 Q%s 430 %s -170" % (f(x), f(640 + j*46), f(930 + j*46)))
    out["gold"] = out["blade"][0]
    def arc(cx, cy, R, a1, a2):
        p1 = (cx + R*math.cos(math.radians(a1)), cy - R*math.sin(math.radians(a1)))
        p2 = (cx + R*math.cos(math.radians(a2)), cy - R*math.sin(math.radians(a2)))
        return "M%s %s A%s %s 0 0 0 %s %s" % (f(p1[0]), f(p1[1]), R, R, f(p2[0]), f(p2[1]))
    out["arcs"] = [arc(1090, 930, 610, 100, 196), arc(-170, 650, 540, -38, 44)]
    out["crescent"] = "M598 402 A118 118 0 0 0 700 528 A86 86 0 0 1 598 402Z"
    return out

def converge():  # streamlines: many faint paths blend tangentially into fewer, no junction nodes, no tree
    import math as m
    def bez(p0, p1, p2, p3, t):
        u = 1 - t
        x = u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0]
        y = u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]
        dx = 3*u*u*(p1[0]-p0[0]) + 6*u*t*(p2[0]-p1[0]) + 3*t*t*(p3[0]-p2[0])
        dy = 3*u*u*(p1[1]-p0[1]) + 6*u*t*(p2[1]-p1[1]) + 3*t*t*(p3[1]-p2[1])
        l = m.hypot(dx, dy); return (x, y), (dx/l, dy/l)
    T1 = ((330, 362), (430, 362), (500, 352), (590, 328))
    T2 = ((590, 328), (680, 304), (770, 252), (940, 224))
    trunk = "M330 362 C430 362 500 352 590 328 C680 304 770 252 940 224"
    joins = [(30, T2, .86, 150), (118, T2, .62, 120), (214, T2, .34, 110), (332, T2, .06, 120), (432, T1, .88, 100), (526, T1, .6, 110), (648, T1, .3, 130)]
    streams = []
    for ys, T, t, k in joins:
        (jx, jy), (tx, ty) = bez(*T, t)
        k = max(28, min(k, (915 - jx) / max(tx, 0.25) * 0.7))
        c2 = (jx + k*tx, jy + k*ty)
        c1 = (900 - 150, ys)
        streams.append("M960 %s C%s %s %s %s %s %s" % (f(ys), f(c1[0]), f(c1[1]), f(c2[0]), f(c2[1]), f(jx), f(jy)))
    final = "M330 362 L262 362"
    return streams, trunk, final, (330, 362)

def limb_extra():   # engraver-style hatching on the long-bone shafts
    h = []
    for y in range(306, 440, 11): h.append("M%s %s l7 4" % (298 + (y-306)*0.02, y))
    for y in range(560, 740, 12): h.append("M%s %s l6 4" % (351 + (y-560)*0.01, y))
    for y in range(520, 720, 13): h.append("M%s %s l6 3" % (303 - (y-520)*0.015, y))
    return h

def organic():
    rnd = random.Random(7)
    cx, cy = 980, 470
    rings = []
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    N = 22
    for k in range(1, 9):
        base = 46 + k*52 + k*k*2.4
        pts = []
        for j in range(N):
            th = j / N * 2*math.pi
            wob = 1 + 0.10*math.sin(2*th + ph[0] + k*0.18) + 0.07*math.sin(3*th + ph[1] + k*0.27) + 0.04*math.sin(5*th + ph[2] + k*0.4)
            pts.append((cx + base*wob*1.12*math.cos(th), cy + base*wob*0.92*math.sin(th)))
        if k in (3, 6):    # open growth arcs (not every ring is closed): drop a third of the ring
            sub = pts[0:15]
            d = "M%s %s" % (i0(sub[0][0]), i0(sub[0][1]))
            for i in range(len(sub)-1):
                p0 = sub[max(i-1, 0)]; p1 = sub[i]; p2 = sub[i+1]; p3 = sub[min(i+2, len(sub)-1)]
                c1 = (p1[0]+(p2[0]-p0[0])/6, p1[1]+(p2[1]-p0[1])/6); c2 = (p2[0]-(p3[0]-p1[0])/6, p2[1]-(p3[1]-p1[1])/6)
                d += " C%s %s %s %s %s %s" % (i0(c1[0]), i0(c1[1]), i0(c2[0]), i0(c2[1]), i0(p2[0]), i0(p2[1]))
            rings.append(d)
        else:
            rings.append(catmull_closed(pts))
    cells = []
    for (x, y, r) in [(560, 250, 20), (610, 292, 12), (520, 330, 15), (700, 160, 11)]:
        pts = [(x + r*(1 + 0.16*math.sin(2*t + x)) * math.cos(t), y + r*(1 + 0.16*math.cos(3*t + y)) * math.sin(t)) for t in [j/18*2*math.pi for j in range(18)]]
        cells.append((catmull_closed(pts), (x + r*0.12, y - r*0.1, r*0.28)))
    return rings, cells
