#!/usr/bin/env python3
"""Builds data/astro-eclipses-<kind>-<first year>.json: every solar and
lunar eclipse from −1999 to +3000 (astronomical year numbering; 2000 BC to
3000 AD), one file per kind and millennium, for AstroEclipses.js.

Source: NASA's Five Millennium Catalogs of Solar and Lunar Eclipses
(Espenak & Meeus), the 50 century pages of each,
  https://eclipse.gsfc.nasa.gov/SEcat5/catalog.html → SE-1999--1900.html … SE2901-3000.html
  https://eclipse.gsfc.nasa.gov/LEcat5/catalog.html → LE-1999--1900.html … LE2901-3000.html
retrieved 2026-10-05 into tools/.cache/ (git-ignored). Terms on the pages:
"Permission is freely granted to reproduce this data when accompanied by an
acknowledgment: 'Eclipse Predictions by Fred Espenak (NASA's GSFC)'". The
acknowledgment goes on the Sources page.

Conventions of the catalogue, and what this does with them:
- Dates before 1582 October 15 are in the Julian calendar, later ones in
  the Gregorian; years are astronomical (0 = 1 BC, −584 = 585 BC). Each
  date is turned into a Julian Day, so the stored instant is the same
  moment JavaScript's (proleptic Gregorian) Date and AstroDate.js use.
- Greatest eclipse is in Terrestrial Dynamical Time (TD). The catalogue
  lists the ΔT it assumed (Espenak & Meeus' polynomials after Morrison &
  Stephenson 2004); UT = TD − ΔT is what is stored, with ΔT itself. ΔT is
  measured only from about 1600 to now; before that its standard error grows
  (https://eclipse.gsfc.nasa.gov/SEcat5/uncertainty.html: 139 s at 500 AD,
  265 s at 0, 3732 s at 2000 BC), and after 2100 it is extrapolated (1885 s
  at 3000 AD). The instant (and the longitudes) are therefore approximate
  outside 1600–2100; the TD instant (UT + ΔT) is exact for the model.
- Solar rows give the point on Earth nearest the shadow axis at greatest
  eclipse, lunar rows the point with the Moon in the zenith: whole degrees
  on these pages.

Output per file: { kind, key, years: [first, last], fields, stride, t0,
data }: `data` is a flat integer array, `stride` values per eclipse; the
first value of each eclipse is its UT in seconds since the previous
eclipse's (the first's since t0, Unix seconds).

Run from the repository root: python3 tools/build-astro-eclipses.py
"""
import json
import math
import os
import re
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CACHE = os.path.join(ROOT, "tools", ".cache")
BASE = {"solar": "https://eclipse.gsfc.nasa.gov/SEcat5/", "lunar": "https://eclipse.gsfc.nasa.gov/LEcat5/"}
PREFIX = {"solar": "SE", "lunar": "LE"}
MONTHS = {m: i + 1 for i, m in enumerate("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split())}
CHUNKS = [(-1999, -1000), (-999, 0), (1, 1000), (1001, 2000), (2001, 3000)]
SOLAR_CODES = {"P": 0, "A": 1, "T": 2, "H": 3}
LUNAR_CODES = {"N": 0, "P": 1, "T": 2}


def century_pages(kind):
    names = []
    for start in range(-1999, 3000, 100):
        end = start + 99
        fmt = lambda y: ("-%04d" % -y) if y < 0 else ("%04d" % y)
        names.append(PREFIX[kind] + fmt(start) + "-" + fmt(end) + ".html")
    return names


def page(kind, name):
    local = os.path.join(CACHE, name)
    if not os.path.exists(local):
        os.makedirs(CACHE, exist_ok=True)
        urllib.request.urlretrieve(BASE[kind] + name, local)
    with open(local, encoding="latin-1") as f:
        return re.sub(r"<[^>]*>", "", f.read())


def julian_day(year, month, day, gregorian):
    """Meeus, Astronomical Algorithms, ch. 7 (valid for negative years)."""
    if month <= 2:
        year -= 1
        month += 12
    b = 0
    if gregorian:
        a = math.floor(year / 100)
        b = 2 - a + math.floor(a / 4)
    return math.floor(365.25 * (year + 4716)) + math.floor(30.6001 * (month + 1)) + day + b - 1524.5


def is_gregorian(year, month, day):
    return (year, month, day) >= (1582, 10, 15)


def rows(kind):
    for name in century_pages(kind):
        for line in page(kind, name).splitlines():
            f = line.split()
            if len(f) < 15 or not re.fullmatch(r"\d{5}", f[0]) or f[2] not in MONTHS:
                continue
            year, month, day = int(f[1]), MONTHS[f[2]], int(f[3])
            h, m, s = (int(x) for x in f[4].split(":"))
            delta_t = int(f[5])
            jd = julian_day(year, month, day, is_gregorian(year, month, day))
            td_s = round((jd - 2440587.5) * 86400) + h * 3600 + m * 60 + s
            yield year, f, td_s - delta_t, delta_t


def lat_lon(lat, lon):
    la = int(lat[:-1]) * (1 if lat[-1] == "N" else -1)
    lo = int(lon[:-1]) * (1 if lon[-1] == "E" else -1)
    return la, lo


def build(kind):
    out = []
    for year, f, ut, delta_t in rows(kind):
        if kind == "solar":
            # cat y m d TD ΔT luna saros type QLE gamma mag lat long alt [width dur]
            lat, lon = lat_lon(f[12], f[13])
            out.append((year, ut, [SOLAR_CODES[f[8][0]], round(float(f[11]) * 10000),
                                   round(float(f[10]) * 10000), lat, lon, delta_t]))
        else:
            # cat y m d TD ΔT luna saros type QSE gamma penMag umMag pen par total lat lng
            lat, lon = lat_lon(f[-2], f[-1])
            out.append((year, ut, [LUNAR_CODES[f[8][0]], round(float(f[12]) * 10000),
                                   round(float(f[11]) * 10000), round(float(f[10]) * 10000), lat, lon, delta_t]))
    out.sort(key=lambda r: r[1])
    return out


FIELDS = {
    "solar": ["dt (s since the previous; UT)", "type 0 partial 1 annular 2 total 3 hybrid", "magnitude x1e4",
              "gamma x1e4", "lat (deg)", "lon (deg, east +)", "deltaT (s)"],
    "lunar": ["dt (s since the previous; UT)", "type 0 penumbral 1 partial 2 total", "umbral magnitude x1e4",
              "penumbral magnitude x1e4", "gamma x1e4", "lat (deg, Moon in the zenith)", "lon (deg, east +)",
              "deltaT (s)"],
}


def main():
    for kind in ("solar", "lunar"):
        everything = build(kind)
        total = 0
        for first, last in CHUNKS:
            chunk = [r for r in everything if first <= r[0] <= last]
            key = ("%05d" % first) if first < 0 else ("%04d" % first)
            t0 = chunk[0][1]
            data = []
            prev = t0
            for _, ut, values in chunk:
                data.append(ut - prev)
                data.extend(values)
                prev = ut
            doc = {
                "source": "Eclipse Predictions by Fred Espenak (NASA's GSFC): Five Millennium Catalog of "
                          + ("Solar" if kind == "solar" else "Lunar")
                          + " Eclipses (Espenak & Meeus), eclipse.gsfc.nasa.gov, retrieved 2026-10-05. "
                          "Built by tools/build-astro-eclipses.py.",
                "kind": kind, "key": key, "years": [first, last], "count": len(chunk),
                "fields": FIELDS[kind], "stride": len(FIELDS[kind]), "t0": t0, "data": data,
            }
            path = os.path.join(ROOT, "data", "astro-eclipses-%s-%s.json" % (kind, key))
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(doc, fh, separators=(",", ":"))
            total += len(chunk)
            print(kind, key, len(chunk), os.path.getsize(path))
        print(kind, "total", total)


if __name__ == "__main__":
    main()
