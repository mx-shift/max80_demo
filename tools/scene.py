#!/usr/bin/env python3
"""Ray-trace the demo's pictures.

Usage: scene.py OUTDIR [FRAMES]

A sphere with a checkered skin spins over a checkered floor that
mirrors it, under a sky that darkens upwards, lit from the upper left
with a shadow on the floor. FRAMES pictures (default 14) take the
sphere round one period of its checks, so they loop. Each is written as
OUTDIR/spinNN.pbm, 160 x 216, 1 bit a dot, dithered with an 8 x 8
ordered matrix so the parts that do not move are the same bits in every
picture. to_grey makes a pair of pictures in three levels, to be
shown in turn, which on the machine only flickered, and the
still the demo once had is gone: neither is made now.

The MAX-80 shows a dot of this picture 2 dots wide in 40 column mode: a
dot is about 0.81 as wide as it is tall (15.2 MHz dots, 52.6 us across
4 units, 242 lines down 3).
"""
import math
import os
import sys
from multiprocessing import Pool

W, H = 160, 216
ASPECT = 0.807                  # a dot's width over its height
SEGS = 16                       # checks round the sphere
BAYER = [[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
         [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
         [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
         [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]


def norm(v):
    d = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    return (v[0] / d, v[1] / d, v[2] / d)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


LIGHT = norm((-0.6, 1.0, -0.5))


class Scene:
    def __init__(self, spin, cy, r, cam, look, fov):
        self.spin, self.c, self.r = spin, (0.0, cy, 0.0), r
        self.cam = cam
        f = norm((look[0] - cam[0], look[1] - cam[1], look[2] - cam[2]))
        rt = norm((f[2], 0.0, -f[0]))
        up = (f[1] * rt[2] - f[2] * rt[1], f[2] * rt[0] - f[0] * rt[2],
              f[0] * rt[1] - f[1] * rt[0])
        self.f, self.rt, self.up = f, rt, up
        self.th = math.tan(fov / 2)

    def hit_sphere(self, o, d):
        oc = (o[0] - self.c[0], o[1] - self.c[1], o[2] - self.c[2])
        b = dot(oc, d)
        q = dot(oc, oc) - self.r * self.r
        disc = b * b - q
        if disc < 0:
            return None
        t = -b - math.sqrt(disc)
        return t if t > 1e-4 else None

    def sphere_shade(self, p, d):
        n = norm((p[0] - self.c[0], p[1] - self.c[1], p[2] - self.c[2]))
        # the skin turns about a tilted axis
        tilt = 0.35
        x, y, z = n
        y, z = y * math.cos(tilt) - z * math.sin(tilt), y * math.sin(tilt) + z * math.cos(tilt)
        lon = math.atan2(z, x) + self.spin
        lat = math.asin(max(-1.0, min(1.0, y)))
        check = (int(math.floor(lon / (2 * math.pi / SEGS))) + int(math.floor(lat / (math.pi / 8)))) & 1
        base = 1.0 if check else 0.03
        diff = max(0.0, dot(n, LIGHT))
        refl = (d[0] - 2 * dot(d, n) * n[0], d[1] - 2 * dot(d, n) * n[1], d[2] - 2 * dot(d, n) * n[2])
        spec = max(0.0, dot(refl, LIGHT)) ** 40
        return min(1.0, base * (0.12 + 0.95 * diff) + 0.8 * spec)

    def sky(self, d):
        return 0.85 * math.exp(-9.0 * max(0.0, d[1]))

    def floor(self, p, d, depth):
        check = (int(math.floor(p[0] * 1.6)) + int(math.floor(p[2] * 1.6))) & 1
        base = 0.85 if check else 0.0
        # the sphere's shadow
        if self.hit_sphere(p, LIGHT) is not None:
            base *= 0.25
        fade = math.exp(-0.05 * max(0.0, p[2] + 3))
        v = base * fade + 0.85 * (1 - fade)
        if depth < 1:
            r = (d[0], -d[1], d[2])
            v = 0.7 * v + 0.3 * self.trace(p, r, depth + 1)
        return v

    def trace(self, o, d, depth=0):
        ts = self.hit_sphere(o, d)
        tf = -o[1] / d[1] if d[1] < -1e-6 else None
        if ts is not None and (tf is None or ts < tf):
            return self.sphere_shade((o[0] + ts * d[0], o[1] + ts * d[1], o[2] + ts * d[2]), d)
        if tf is not None:
            return self.floor((o[0] + tf * d[0], 0.0, o[2] + tf * d[2]), d, depth)
        return self.sky(d)

    def pixel(self, x, y):
        v = 0.0
        for sy in (0.25, 0.75):
            for sx in (0.25, 0.75):
                u = ((x + sx) / W * 2 - 1) * self.th * W * ASPECT / H
                w = (1 - (y + sy) / H * 2) * self.th
                d = norm((self.f[0] + u * self.rt[0] + w * self.up[0],
                          self.f[1] + u * self.rt[1] + w * self.up[1],
                          self.f[2] + u * self.rt[2] + w * self.up[2]))
                v += self.trace(self.cam, d)
        return v / 4


def render_row(args):
    sc, y = args
    return [sc.pixel(x, y) for x in range(W)]


def to_pbm(rows, path):
    out = bytearray()
    for y, row in enumerate(rows):
        bits = 0
        for x, v in enumerate(row):
            v = v ** 0.8                # the monitor's dots are bold
            on = v * 64 > BAYER[y & 7][x & 7] + 0.5
            bits = bits << 1 | on
            if x & 7 == 7:
                out.append(bits)
                bits = 0
    open(path, 'wb').write(b'P4\n%d %d\n' % (W, H) + bytes(out))


def to_grey(rows, path_a, path_b):
    """Three levels, black, half and white, as two pictures shown in
    turn: a half dot is lit in one of them, by a checkerboard, so each
    frame has half the half dots and the screen does not pulse"""
    outs = (bytearray(), bytearray())
    for y, row in enumerate(rows):
        bits = [0, 0]
        for x, v in enumerate(row):
            v = v ** 0.8
            lv = min(2, int(v * 2 + (BAYER[y & 7][x & 7] + 0.5) / 64))
            for k in (0, 1):
                on = lv == 2 or (lv == 1 and (x + y + k) & 1 == 0)
                bits[k] = bits[k] << 1 | on
            if x & 7 == 7:
                for k in (0, 1):
                    outs[k].append(bits[k])
                bits = [0, 0]
    for out, path in zip(outs, (path_a, path_b)):
        open(path, 'wb').write(b'P4\n%d %d\n' % (W, H) + bytes(out))


def render(pool, sc):
    return pool.map(render_row, [(sc, y) for y in range(H)])


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    out = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) == 3 else 14
    os.makedirs(out, exist_ok=True)
    cam, look = (0.0, 2.0, -8.0), (0.0, 0.9, 0.0)
    with Pool() as pool:
        for i in range(n):
            # one period is two checks: they swap black and white after one
            sc = Scene(2 * (2 * math.pi / SEGS) * i / n, 1.05, 1.0, cam, look, 0.78)
            to_pbm(render(pool, sc), os.path.join(out, 'spin%02d.pbm' % i))
        # no still any more: the spin follows straight on


if __name__ == '__main__':
    main()
