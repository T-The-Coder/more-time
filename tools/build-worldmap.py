#!/usr/bin/env python3
"""Builds data/worldmap.json, the world map of the World tab.

Sources (Natural Earth, public domain), downloaded once into tools/.cache:
  ne_50m_land.geojson        coastlines
  ne_10m_time_zones.geojson  nominal time zones (standard time, as offsets)

Everything is projected here with Equal Earth (Šavrič, Patterson, Jenny
2018), so the plugin only scales and draws. Coordinates are projected units
times SCALE, rounded to integers; y grows to the north. The x range is about
±27066 and the y range ±13173 at SCALE 10000. WorldMap.js holds the same
projection for cities and the day/night line; tests/worldmap.test.mjs checks
that both agree.

Output:
  { "version": 1, "projection": "equal-earth", "scale": 10000,
    "land": [ring, ...],                      ring = [x0, y0, x1, y1, ...]
    "zones": [{ "o": minutes east of UTC, "r": [ring, ...] }, ...] }
  Zone rings include holes; fill each zone with the even-odd rule.

Run: python3 tools/build-worldmap.py
"""

import json
import math
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
OUT = os.path.join(HERE, "..", "data", "worldmap.json")
BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
SCALE = 10000
# Douglas-Peucker tolerance in projected units: 0.002 is about a pixel at
# 2700 px map width, finer than the app ever draws.
LAND_TOLERANCE = 0.002
ZONE_TOLERANCE = 0.0025
# Segments are split so no piece spans more than this many degrees: the
# edges that run along the 180th meridian or a parallel are straight in
# longitude and latitude but curved in Equal Earth.
DENSIFY_DEGREES = 2.0
# Rings smaller than this (projected units squared) are dropped: specks.
MIN_AREA = 0.00002

A1, A2, A3, A4 = 1.340264, -0.081106, 0.000893, 0.003796
M = math.sqrt(3) / 2


def project(lon, lat):
    lam = math.radians(lon)
    phi = math.radians(max(-90.0, min(90.0, lat)))
    theta = math.asin(M * math.sin(phi))
    t2 = theta * theta
    t6 = t2 * t2 * t2
    x = 2 * math.sqrt(3) * lam * math.cos(theta) / (3 * (A1 + 3 * A2 * t2 + t6 * (7 * A3 + 9 * A4 * t2)))
    y = theta * (A1 + A2 * t2 + t6 * (A3 + A4 * t2))
    return x, y


def fetch(name):
    path = os.path.join(CACHE, name + ".geojson")
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        print("downloading", name, file=sys.stderr)
        urllib.request.urlretrieve(BASE + name + ".geojson", path)
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def densify(ring):
    out = []
    for i in range(len(ring) - 1):
        (x0, y0), (x1, y1) = ring[i][:2], ring[i + 1][:2]
        steps = max(1, int(math.ceil(max(abs(x1 - x0), abs(y1 - y0)) / DENSIFY_DEGREES)))
        for s in range(steps):
            t = s / steps
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    out.append(tuple(ring[-1][:2]))
    return out


def perpendicular(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    if dx == 0 and dy == 0:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))


def simplify(points, tolerance):
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        first, last = stack.pop()
        worst, index = 0.0, -1
        for i in range(first + 1, last):
            d = perpendicular(points[i], points[first], points[last])
            if d > worst:
                worst, index = d, i
        if index >= 0 and worst > tolerance:
            keep[index] = True
            stack.append((first, index))
            stack.append((index, last))
    return [p for p, k in zip(points, keep) if k]


def area(points):
    total = 0.0
    for i in range(len(points)):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % len(points)]
        total += x0 * y1 - x1 * y0
    return abs(total) / 2


def encode(ring, tolerance):
    projected = [project(lon, lat) for lon, lat in densify(ring)]
    if area(projected) < MIN_AREA:
        return None
    simple = simplify(projected, tolerance)
    if len(simple) < 4:
        return None
    flat = []
    last = None
    for x, y in simple:
        point = (int(round(x * SCALE)), int(round(y * SCALE)))
        if point != last:
            flat.extend(point)
            last = point
    return flat if len(flat) >= 8 else None


def polygons(geometry):
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"]]
    if geometry["type"] == "MultiPolygon":
        return geometry["coordinates"]
    return []


def main():
    land = []
    for feature in fetch("ne_50m_land")["features"]:
        for polygon in polygons(feature["geometry"]):
            for ring in polygon:
                encoded = encode(ring, LAND_TOLERANCE)
                if encoded:
                    land.append(encoded)

    by_offset = {}
    for feature in fetch("ne_10m_time_zones")["features"]:
        zone = feature["properties"].get("zone")
        if zone is None:
            continue
        minutes = int(round(float(zone) * 60))
        for polygon in polygons(feature["geometry"]):
            # Holes go in as plain rings: one zone's rings never overlap,
            # so the plugin fills each zone with the even-odd rule and an
            # enclave of another offset stays open.
            for ring in polygon:
                encoded = encode(ring, ZONE_TOLERANCE)
                if encoded:
                    by_offset.setdefault(minutes, []).append(encoded)

    zones = [{"o": minutes, "r": by_offset[minutes]} for minutes in sorted(by_offset)]
    data = {"version": 1, "projection": "equal-earth", "scale": SCALE, "land": land, "zones": zones}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(data, handle, separators=(",", ":"))
        handle.write("\n")
    points = sum(len(r) for r in land) // 2 + sum(len(r) for z in zones for r in z["r"]) // 2
    print("wrote", OUT, os.path.getsize(OUT), "bytes,", len(land), "land rings,",
          len(zones), "offsets,", points, "points", file=sys.stderr)


if __name__ == "__main__":
    main()
