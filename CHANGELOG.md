# Changelog

All notable changes to More Time are documented here.

## Unreleased

- **Astro: the ISS** (an option, off by default): the space station over
  its place in the Earth and Moon view and the inset, with its ground track
  and on hover where it is, its height and its orbit. Its orbit data come
  from CelesTrak (at most twice a day, only while the option is on and the
  tab shows) and are propagated with SGP4 on this computer.
- **Astro: belts, dwarf planets, Halley, moons and spacecraft.** The
  asteroid and Kuiper belts and Ceres, Pluto and Eris (on by default),
  Halley's Comet with its tail, the large moons of Jupiter and Saturn close
  up on the planet under the pointer or clicked, Voyager 1 and 2 and New
  Horizons as arrows at the edge with their distance and JWST near L2 in
  the Earth and Moon view; each group has its own switch, and the pointer
  names each body with its distances, period or speed.
- **The globe and the map on the GPU:** where the graphics allow it, the
  World tab's globe and map draw the zones, the land and the night with a
  shader (shared with More Weather) from a picture painted once per change,
  so turning by itself costs little; lines, the golden and blue bands, the
  Sun, the Moon and the places stay as they were. Without GPU drawing, and
  zoomed in to the last step, it draws as before. The IPC status reports the
  globe's frames and processor share. The coast, the grid and the golden and blue
  bands are part of the GPU picture too, so while the globe turns only the
  Sun, the Moon and the places are drawn per frame.
- **Astro: timeline, Go to date and the info line.** A timeline under the
  solar system plays the year either side of today at a day, a week or a
  month a second, with a track to drag and `,` `.` `Space` `n` keys; **Go
  to date** (`g`) travels in a time lapse to any moment from 3000 BC to
  3000 AD and stays there until **Now** brings it back (outside 1800–2050
  from JPL's long-range elements, marked approximate). An info line names
  the Moon's phase and its next new and full moon, the next equinox or
  solstice, the next opposition and the planets in the evening and the
  morning sky. Everything in the view follows the shown moment.
- **Zoom on the globe and the map, buttons in the Astro tab:** a small
  cluster at the top right (crosshair, −, +) as on More Weather's globe. The
  globe and the flat map zoom in three steps (to about 1,600 km across) with
  the buttons, `+` `−`, `Ctrl` + wheel at the pointer or a double click; the
  zoomed globe turns and tilts to any latitude under a drag, the zoomed map
  pans; `0` shows the whole earth. In the World tab `+` now zooms (`/` and
  `n` still add a city). In the Astro tab the crosshair returns to the start
  view and − + step between the whole system, the inner system and Earth.
- **Astro: Earth, Moon and the bodies turning.** Earth is a real globe in
  the Earth–Moon zoom and in a new corner inset (a click zooms there): its
  land, its night, turned and tilted as it is now and seen from the
  camera's side; the Moon circles it lit by the Sun, its near side always
  towards Earth, with phase, distance and age on hover. The planets show
  their tilt and turning (latitude bands, a meridian), Uranus lies on its
  side, Saturn wears its rings in their plane; hover adds the day's length
  and the axial tilt. The Sun is drawn in warm gold. New options: rotation
  and tilt, the Earth and Moon inset.
- **Tooltip on hover:** a new menu bar option (off by default) shows the
  bar's tooltip with every entry of the clock, the hover ones included, one
  per line with a word for each symbol, updated while it is shown.
- **The turning globe no longer keeps a processor core busy:** it (and the
  solar system) turns by itself only while you can see it, with the popup
  open or the app window focused, not while the app sits unfocused or on
  another workspace; it starts again after the delay when you come back.
  While turning it is drawn more simply (flat zones, a coarser coast, the
  fills at a third of the resolution and refreshed eight times a second),
  and a new setting picks the frames per second (8, 15, 24 or 30; 15 by
  default). At 840 px and 15 frames a second it takes about a third of one
  core, still about 1 % when nothing turns.
- **New Astro tab: the solar system as a clock.** The Sun and the eight
  planets where they stand now (JPL's approximate Keplerian elements,
  computed on this computer, redrawn every minute), at a slant from above,
  distances as r^0.45 so all orbits fit. A drag turns and tilts the view,
  `Ctrl` + arrows too, `+` `−` or `Ctrl` + wheel zoom between the whole
  system, the inner system and Earth's neighbourhood, `0` resets; it can turn
  by itself like the globe. A month ring around Earth's orbit makes Earth the
  hand of the year, with the equinoxes and solstices marked; the pointer on a
  body shows its distances and period. On in the app, off in the widget;
  `tab astro` over IPC.
- **The globe fills the window:** instead of stopping at a fixed size, it
  takes the height visible below it in the app or the popup (the popup's
  full height), at most the page's width and at least 240 points, and
  follows the window as you resize it. The flat map narrows, centred and in
  its proportions, when it would not fit the visible height.
- **The blue hour deepens towards the night:** on the map and the globe the
  blue band is now lightest at the day/night line and deepest towards the
  night, running into the night steps; the golden band stays strongest at
  the line.
- **The Moon as seen from here:** a new choice under Display → Moon draws
  it as you see it in the sky from the current place (lit on the right
  while waxing and on the left while waning, mirrored south of the
  equator) instead of lit from the Sun's direction as seen from space; on
  the map and the globe alike.
- **Groundwork for More Weather's globe (nothing changes in More Time):**
  the sun and sky calculations moved to `Sky.js`; `Globe.js` gained a view
  that tilts to any latitude, the poles included, and zooms, with the land
  outline in latitude and longitude (`data/globe-land.json`, built by
  `tools/build-globe-land.py`). The flat map's Equal Earth projection and
  its twilight polygons moved to `EqualEarth.js`, which can also put that
  land on a flat map. These files and their tests are shared with More
  Weather.

## 1.0.1 — 2026-10-03

- **Names are shown as plain text:** place names from the search, the cities
  file, Omarchy's weather location and the IP lookup, alarm places and every
  label you type no longer pass through Qt's rich-text detection, so a crafted
  name with HTML cannot load a remote image (which would reveal your IP
  address). Every text in the widget, the popup and the app is plain now.
- **Notifications carry no markup:** in the titles and texts handed to
  `notify-send` and Omarchy's notification (alarms, timers, missed alarms,
  pomodoro phases, the bar's status on right-click), `<`, `>` and `&` become
  the look-alikes ‹ › ＆, which no notification server reads as markup.

## 1.0.0 — 2026-10-02

First release.

> **Chimes are on by default:** a short beep every quarter hour (one at :15,
> two at :30, three at :45, four on the hour). Mute them with `m` in the
> widget or the app, the bell next to the clock, Settings → Sounds → Mute the
> chimes, or `qs ipc -p /usr/share/omarchy/shell call more-time muteChimes`;
> Settings → Sounds → Chime → Off turns them off.

- **Clock in the bar:**
  - Time, seconds, weekday, date, week number, cities, the next alarm, running
    timers, stopwatches and pomodoros, and a bell while something rings.
  - Each entry shows always, when relevant or on hover, in your order.
  - The text turns bold at once under the pointer (switchable), and the popup
    can open on hover.
  - Values can be coloured, while hovered (default) or always: the time in the
    colour of the sky (day, golden hour, blue hour, night), running timers
    and pomodoros in the accent colour and red in their last minute, the next
    alarm within an hour, cities by day and night.
- **Current place and here:** the clock on top shows here or one of your
  cities (pin, name and ▾ above the time; `Alt 0`–`9`, `Alt ← →`, IPC `here`,
  `city`, `nextCity`, `previousCity`), kept across restarts and shared by bar
  and app, with a line for the time here; alarms,
  chimes and the bar stay on this computer's clock. Here is Omarchy's weather
  location, else (opt-in "Detect my location") IP geolocation cached for six
  hours, else the time zone's city.
- **Sun:** sunrise and sunset (on in the app, off in the widget), the golden
  and the blue hour (off by default) in the clock and per city the sunrise,
  the sunset and the next of the two (with More Weather's arrow icon); the
  map and the globe mark the twilight as a gold band on the day side of the
  day/night line and a blue one on the night side, under a clearly darker
  night side.
- **World clock:**
  - A map of the real time zones in zebra stripes, in the Equal Earth
    projection, with the night side, the sun, an hour ruler and your cities.
  - Or a globe (Settings → Display → Map style): the same zones and cities
    in an orthographic view, with the golden and blue hour as bands along the
    day/night line; it turns to the picked place, by drag or sideways wheel,
    and optionally by itself after 5, 10 or 30 idle seconds, one turn in 1, 2,
    4 (default) or 8 minutes; a click, drag or the wheel stops it, hovering does not.
  - Optionally the Moon at its sub-lunar point with its phase, on the map and
    the globe, with More Weather's phase numbers: a small shaded sphere
    floating above its shadow. The Sun's zenith point is a rayed sun.
  - The night side in three steps (civil, nautical, astronomical twilight);
    the golden and blue bands fade at their outer edges.
  - Your own place is shown with More Weather's location pin, not a word.
  - A city list with the day and the difference to here.
  - Five clock face styles (classic, minimal, roman, 24 hours with the night
    shaded, dots), chosen per place with `e` or the pencil on any row; small
    faces in the list; one style for the clock on top if you like.
  - City search offline from the tz database and online through the place
    search shared with More Weather (Open-Meteo while typing; Nominatim only
    on Enter, at most once a second, with the nearest zone for its places),
    with More Weather's keys.
  - Import of More Weather's saved places as cities (Settings → General →
    Places).
- **Scrolling:** wheel and touchpad scroll as in More Weather (a fixed step
  per notch, touchpad deltas scaled up), in the view and in the settings;
  the globe and the editors' values keep the wheel where they use it.
- **Alarms:** as many as you like, once or on weekdays, with a name and a
  snooze length, optionally at a city's time (its zone, summer time included). Missed alarms are announced, and alarms up to ten minutes late
  still ring. The last check is kept on disk, so an alarm due while the
  computer was off is announced as missed after a reboot, and a once-alarm is
  switched off instead of ringing the next day.
- **Timers:** as many as you like, from presets (your own list) or typed
  lengths, with pause, ±1 minute and progress. A name can follow the typed
  length (`10 Tea`).
- **Stopwatches:** as many as you like, with laps and hundredths.
- **Pomodoros:** as many as you like, with focus and break lengths (25/5 to
  begin with), an optional long break and auto continue; a tally of focus
  rounds today and this week (list, clock, bar).
- **Ringing:** sound through PipeWire, notifications with Stop and Snooze, and a
  banner in the popup and the app. Only one instance rings, even with the app
  and several monitors.
- **Chimes:** a beep every quarter hour by default (1 to 4 beeps), or every
  minute, every hour, once a day or every *N* minutes, and an optional hour
  chime in a lower tone (12- or 24-hour dial). Five tones (beep, bell, wood,
  chirp, glass), own volume and test buttons.
  Mute with a switch, `m`, the bell in the clock's corner or IPC
  (`muteChimes`, `unmuteChimes`, `toggleChimes`), for bar and app at once;
  the right-click notification mentions it. Played once by the ringing
  instance, never while something rings, never caught up after a suspend.
  The tones are generated locally.
- **App and settings:**
  - A standalone app sharing everything with the bar; a click on the time in
    the popup opens it.
  - Settings per surface (menu bar, widget, app), a Sounds page for the
    ringing sounds and the chimes, and export and import.
  - 30 languages, right to left included.
  - Full keyboard control, settings included; Settings → Shortcuts lists
    every key and click.
  - Key hints in the tabs sit on the right, next to the add button, as in
    More Weather; a tab strip too narrow for names shows only the glyphs, with
    the name on hover.
  - An IPC interface, including `city`, `nextCity` and `previousCity`.
