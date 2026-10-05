#!/usr/bin/env python3
"""Builds data/astro-stars.json and data/astro-constellations.json for the
Astro tab's star background (AstroStars.js).

Sources (downloaded into tools/.cache/, which git ignores; all retrieved
2026-10-05):

- Stars: the Yale Bright Star Catalogue, 5th revised ed. (Hoffleit &
  Warren 1991), CDS catalogue V/50,
  https://cdsarc.cds.unistra.fr/ftp/V/50/catalog.gz (format in
  https://cdsarc.cds.unistra.fr/ftp/V/50/ReadMe). NASA HEASARC publishes it
  as a U.S. Government Work, public domain
  (https://catalog.data.gov/dataset/bright-star-catalog).
- Star names: the IAU Catalog of Star Names (WGSN),
  https://www.pas.rochester.edu/~emamajek/WGSN/IAU-CSN.txt (names are
  facts; the IAU releases its products under CC BY, so credit the IAU WGSN).
- Constellation figures and Latin names: d3-celestial by Olaf Frohn,
  BSD 3-Clause (https://github.com/ofrohn/d3-celestial, data/
  constellations.lines.json and constellations.json), lines after the IAU
  constellation charts. BSD is compatible with this MIT project; the
  copyright notice goes on the Sources page. Stellarium's
  constellationship.fab is GPL and was not used.
- Constellation boundaries: Roman (1987), "Identification of a
  Constellation from a Position", PASP 99, 695, CDS catalogue VI/42,
  https://cdsarc.cds.unistra.fr/ftp/VI/42/data.dat: the IAU 1930
  (Delporte) boundaries in B1875 coordinates, arranged for lookup.
  Prepared at NASA's Astronomical Data Center.

Run from the repository root: python3 tools/build-astro-stars.py
"""
import gzip
import json
import math
import os
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CACHE = os.path.join(ROOT, "tools", ".cache")
URLS = {
    "catalog.gz": "https://cdsarc.cds.unistra.fr/ftp/V/50/catalog.gz",
    "IAU-CSN.txt": "https://www.pas.rochester.edu/~emamajek/WGSN/IAU-CSN.txt",
    "d3c-constellations.lines.json": "https://raw.githubusercontent.com/ofrohn/d3-celestial/master/data/constellations.lines.json",
    "d3c-constellations.json": "https://raw.githubusercontent.com/ofrohn/d3-celestial/master/data/constellations.json",
    "vi42-data.dat": "https://cdsarc.cds.unistra.fr/ftp/VI/42/data.dat",
}
LIMIT_MAG = 5.0
NAMED_MAG = 2.5   # proper names for the stars this bright (about 90)
SNAP_DEG = 0.15   # a figure's vertex is a catalogue star this close


def fetch(name):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        urllib.request.urlretrieve(URLS[name], path)
    return path


def colour_class(bv, sp):
    """0 blue (B−V < 0), 1 white (< 0.3), 2 yellow-white (< 0.6),
    3 yellow (< 1.1), 4 orange-red; from the spectral class without B−V."""
    if bv is None:
        letter = sp.strip()[:1].upper() if sp.strip() else "A"
        return {"O": 0, "B": 0, "A": 1, "F": 2, "G": 3, "K": 4, "M": 4, "C": 4, "S": 4, "N": 4, "R": 4}.get(letter, 1)
    if bv < 0.0:
        return 0
    if bv < 0.3:
        return 1
    if bv < 0.6:
        return 2
    if bv < 1.1:
        return 3
    return 4


def read_bsc():
    stars = []
    with gzip.open(fetch("catalog.gz"), "rt", encoding="latin-1") as f:
        for line in f:
            line = line.rstrip("\n").ljust(197)
            if not line[75:77].strip() or not line[102:107].strip():
                continue  # novae and other objects without data
            hr = int(line[0:4])
            ra = (int(line[75:77]) + int(line[77:79]) / 60 + float(line[79:83]) / 3600) * 15
            dec = int(line[84:86]) + int(line[86:88]) / 60 + int(line[88:90]) / 3600
            if line[83] == "-":
                dec = -dec
            vmag = float(line[102:107])
            bv = float(line[109:114]) if line[109:114].strip() else None
            sp = line[127:147]
            stars.append({"hr": hr, "ra": ra, "dec": dec, "mag": vmag, "cls": colour_class(bv, sp),
                          "con": line[11:14].strip()})
    return stars


def read_names():
    names = {}
    with open(fetch("IAU-CSN.txt"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or line.startswith("$") or not line.strip():
                continue
            # Fixed columns: Name/ASCII 0–17, Designation 36–48 ("HR 897").
            name = line[0:18].strip()
            designation = line[36:49].split()
            if len(designation) == 2 and designation[0] == "HR":
                names.setdefault(int(designation[1]), name)
    return names


def unit(ra, dec):
    a, d = math.radians(ra), math.radians(dec)
    return (math.cos(d) * math.cos(a), math.cos(d) * math.sin(a), math.sin(d))


def sep(u, v):
    c = max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1] + u[2] * v[2]))
    return math.degrees(math.acos(c))


def main():
    bsc = read_bsc()
    names = read_names()
    vectors = [unit(s["ra"], s["dec"]) for s in bsc]

    def nearest(ra, dec):
        u = unit(ra, dec)
        best, bd = None, 99.0
        for i, v in enumerate(vectors):
            if abs(bsc[i]["dec"] - dec) > 1:
                continue
            d = sep(u, v)
            if d < bd:
                best, bd = i, d
        return best, bd

    lines = json.load(open(fetch("d3c-constellations.lines.json"), encoding="utf-8"))
    figures = {}
    needed = set()
    missed = 0
    for feat in lines["features"]:
        polylines = []
        for poly in feat["geometry"]["coordinates"]:
            chain = []
            for lon, lat in poly:
                i, d = nearest(lon % 360, lat)
                if d > SNAP_DEG:
                    missed += 1
                    if len(chain) > 1:
                        polylines.append(chain)
                    chain = []
                    continue
                needed.add(i)
                chain.append(i)
            if len(chain) > 1:
                polylines.append(chain)
        figures.setdefault(feat["id"], []).extend(polylines)

    keep = [i for i, s in enumerate(bsc) if s["mag"] <= LIMIT_MAG or i in needed]
    keep.sort(key=lambda i: bsc[i]["mag"])  # brightest first: a prefix is a magnitude cut
    index = {old: new for new, old in enumerate(keep)}
    out = {
        "source": "Yale Bright Star Catalogue 5th rev. ed. (Hoffleit & Warren 1991, CDS V/50, public domain); "
                  "names: IAU WGSN Catalog of Star Names. Built by tools/build-astro-stars.py.",
        "epoch": "J2000",
        "limitMag": LIMIT_MAG,
        "units": "ra, dec: 0.001 deg; mag: 0.01 mag; color: 0 blue, 1 white, 2 yellow-white, 3 yellow, 4 orange-red",
        "count": len(keep),
        "hr": [bsc[i]["hr"] for i in keep],
        "ra": [round(bsc[i]["ra"] * 1000) for i in keep],
        "dec": [round(bsc[i]["dec"] * 1000) for i in keep],
        "mag": [round(bsc[i]["mag"] * 100) for i in keep],
        "color": [bsc[i]["cls"] for i in keep],
        "names": [[index[i], names[bsc[i]["hr"]]] for i in keep
                  if bsc[i]["mag"] <= NAMED_MAG and bsc[i]["hr"] in names],
    }
    with open(os.path.join(ROOT, "data", "astro-stars.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"), ensure_ascii=False)

    meta = json.load(open(fetch("d3c-constellations.json"), encoding="utf-8"))
    latin = {}
    genitive = {}
    for feat in meta["features"]:
        latin[feat["id"]] = feat["properties"]["name"]
        genitive[feat["id"]] = feat["properties"]["gen"]
    bounds = []
    with open(fetch("vi42-data.dat"), encoding="ascii") as f:
        for line in f:
            if line.strip():
                bounds.append([float(line[1:8]), float(line[9:16]), float(line[17:25]), line[26:29]])
    abbrs = sorted(latin.keys(), key=lambda s: s.lower())
    cons = {
        "source": "Figures and Latin names: d3-celestial (c) 2015 Olaf Frohn, BSD 3-Clause, after the IAU charts; "
                  "boundaries: Roman 1987 (CDS VI/42), IAU 1930 boundaries in B1875. Built by tools/build-astro-stars.py.",
        "abbr": abbrs,
        "latin": [latin[a] for a in abbrs],
        "genitive": [genitive[a] for a in abbrs],
        # Per constellation (same order): polylines of indices into astro-stars.json.
        "figures": [[[index[i] for i in chain] for chain in figures.get(a, [])] for a in abbrs],
        # [RA low (h), RA high (h), Dec low (deg), index into abbr], equinox B1875, in Roman's order.
        "bounds": [[b[0], b[1], b[2], abbrs.index(b[3]) if b[3] in latin else abbrs.index(b[3].capitalize())]
                   for b in bounds],
    }
    with open(os.path.join(ROOT, "data", "astro-constellations.json"), "w", encoding="utf-8") as f:
        json.dump(cons, f, separators=(",", ":"), ensure_ascii=False)
    print("stars", len(keep), "of which figure-only", len([i for i in keep if bsc[i]["mag"] > LIMIT_MAG]),
          "named", len(out["names"]), "figure vertices missed", missed)


if __name__ == "__main__":
    main()
