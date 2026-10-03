#!/usr/bin/env python3
"""Builds data/globe-land.json, the land outline for the globes, from
data/worldmap.json (tools/build-worldmap.py): every land ring taken back from
Equal Earth to latitude and longitude, no download needed.

Output:
  { "version": 1, "scale": 100, "land": [ring, ...] }
  ring = [lon0, lat0, lon1, lat1, ...] in hundredths of a degree (integers).
  Every ring runs counter-clockwise in longitude/latitude (east = right,
  north = up), so its land lies to the left, as seen from outside the earth.
  Points a rounding step outside the map are pulled onto ±180°, points
  beyond ±89° onto the poles; repeated points are dropped. Edges are at most about 2° long (the
  map's own densifying), and a ring along the south pole (Antarctica) keeps
  its edge along latitude −90°.

Shared by the More plugins (tools/sync-shared.sh): Globe.prepareVectors()
reads it.

Run: python3 tools/build-globe-land.py
"""

import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, "..", "data", "worldmap.json")
OUT = os.path.join(HERE, "..", "data", "globe-land.json")
SCALE = 100

A1, A2, A3, A4 = 1.340264, -0.081106, 0.000893, 0.003796
M = math.sqrt(3) / 2


def unproject(x, y):
    """Equal Earth back to (lon, lat), as WorldMap.unproject; None outside."""
    theta = y
    for _ in range(12):
        t2 = theta * theta
        t6 = t2 * t2 * t2
        fy = theta * (A1 + A2 * t2 + t6 * (A3 + A4 * t2)) - y
        fpy = A1 + 3 * A2 * t2 + t6 * (7 * A3 + 9 * A4 * t2)
        delta = fy / fpy
        theta -= delta
        if abs(delta) < 1e-12:
            break
    u2 = theta * theta
    u6 = u2 * u2 * u2
    lam = M * x * (A1 + 3 * A2 * u2 + u6 * (7 * A3 + 9 * A4 * u2)) / math.cos(theta)
    s = math.sin(theta) / M
    if abs(s) > 1 or abs(lam) > math.pi + 1e-9:
        return None
    return math.degrees(lam), math.degrees(math.asin(s))


def ring_lonlat(ring, scale):
    points = []
    for i in range(0, len(ring), 2):
        x, y = ring[i] / scale, ring[i + 1] / scale
        p = unproject(x, y) or unproject(x * 0.9999, y * 0.9999)
        if p is None:
            continue
        lon = max(-180.0, min(180.0, p[0]))
        lat = max(-90.0, min(90.0, p[1]))
        if abs(lon) > 179.95:
            lon = -180.0 if lon < 0 else 180.0
        # The map's flat poles come back a little off them (Equal Earth is
        # steep there): no coast lies that far south or north.
        if abs(lat) > 89.0:
            lat = -90.0 if lat < 0 else 90.0
        q = (round(lon * SCALE), round(lat * SCALE))
        if not points or points[-1] != q:
            points.append(q)
    if len(points) > 1 and points[0] == points[-1]:
        points.pop()
    return points


def signed_area(points):
    total = 0
    for i in range(len(points)):
        x0, y0 = points[i - 1]
        x1, y1 = points[i]
        total += x0 * y1 - x1 * y0
    return total / 2


def main():
    with open(SOURCE, encoding="utf-8") as f:
        data = json.load(f)
    scale = data.get("scale", 10000)
    land = []
    for ring in data["land"]:
        points = ring_lonlat(ring, scale)
        if len(points) < 3:
            continue
        if signed_area(points) < 0:
            points.reverse()
        land.append([v for p in points for v in p])
    out = {"version": 1, "scale": SCALE, "land": land}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
        f.write("\n")
    print(f"{OUT}: {len(land)} rings, {sum(len(r) // 2 for r in land)} points, {os.path.getsize(OUT)} bytes")


if __name__ == "__main__":
    main()
