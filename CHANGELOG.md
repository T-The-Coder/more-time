# Changelog

All notable changes to More Time are documented here.

## 1.1.0 — 2026-10-11

- **New Astro tab: the solar system as a clock.** The Sun and the eight
  planets where they stand now (JPL's approximate Keplerian elements,
  computed on this computer), at a slant from above, distances as r^0.45 so
  all orbits fit. A drag turns and tilts the view, `Ctrl` + arrows too;
  `+` `−`, `Ctrl` + wheel or the buttons at the top right switch between
  the whole system, the inner system and Earth's neighbourhood, `0` resets;
  it can turn by itself like the globe. A month ring around Earth's orbit
  makes Earth the hand of the year, with the equinoxes and solstices marked;
  the pointer on a body shows its distances, period, day and axial tilt. On
  in the app, off in the widget; `tab astro` over IPC.
- **Astro: the real star sky.** Behind everything (on by default) the stars
  to magnitude 5 from the Yale Bright Star Catalogue where they stand on the
  sky, turning with the view; a bright star under the pointer is named with
  its constellation. Constellations (off by default) add the stick figures
  with their Latin names (d3-celestial, BSD licence, credited on the Sources
  page); hovering a figure highlights and names it.
- **Astro: Earth, the Moon and the planets turning.** Earth is a real globe
  in the Earth–Moon zoom and in a corner inset (a click zooms there): its
  land and its night, turned and tilted as it is now; the Moon circles it lit
  by the Sun, its near side always towards Earth. The planets show their
  tilt and turning, Uranus lies on its side, Saturn wears its rings in their
  plane.
- **Astro: belts, dwarf planets, Halley, moons and spacecraft.** The
  asteroid and Kuiper belts and Ceres, Pluto and Eris (on by default),
  Halley's Comet with its tail, the large moons of Jupiter and Saturn close
  up on the planet under the pointer or clicked, Voyager 1 and 2 and New
  Horizons as arrows at the edge with their distance and JWST near L2; each
  group has its own switch.
- **Astro: the ISS,** an option off by default: the space station over its
  place in the Earth and Moon view and the inset, with its ground track and,
  on hover, where it is, its height and its orbit. Its orbit data come from
  CelesTrak (at most twice a day, only while the option is on and the tab
  shows) and are propagated with SGP4 on this computer.
- **Astro: timeline, time lapse and Go to date.** Under the model a
  timeline over the year either side of today (drag it, `,` `.` a day, `n`
  now) plays as a time lapse (`Space`, ▶) at a speed from real time to a
  year in a minute; the shown date and time count beside it, and Play on
  opening starts it with the tab. Go to date (`g`) travels to any moment
  from 3000 BC to 3000 AD and stays there until Now (outside 1800–2050 from
  JPL's long-range elements, marked approximate). Everything in the view
  follows the shown moment.
- **Astro: sky events,** behind `e` (on by default in the app): eclipses from
  NASA's five-millennium catalogues (with whether they can be seen from the
  current place), the Moon's phases, the seasons, oppositions, conjunctions,
  greatest elongations, close planet pairs, perihelion and aphelion around
  the shown moment, filtered and paged with ‹ ›; a click travels there. A
  solar eclipse shows the Moon's shadow on Earth, a lunar one a copper Moon.
- **Astro: the info, folded.** One line under the model (`i` or a click
  unfolds it) names the Moon's phase with the next new and full moon, the
  Moon at the current place, the next equinox or solstice, opposition and
  eclipses, and the planets in the evening and the morning sky; the model
  keeps at least 55 % of the visible height. The pointer on the Sun, a
  planet or the Moon names the zodiac constellation it stands in.
- **World and Places, two tabs:** the World tab is the map or the globe
  with its chips, timeline and zoom; the new Places tab holds here and your
  cities (their time, the day and the difference to here, sunrise and
  sunset, a clock face each), the city search, `+`, moving and removing,
  with its own Display card. The map marks the place selected in Places,
  and a click on the map selects it. Settings saved with the old city list
  off keep Places hidden. The tabs after World move one number on: `1`–`9`
  count Places as the second tab.
- **World: a timeline under the map,** on by default in the app: a day in
  a minute, a day in ten seconds or the seasons (a year in a minute at the
  same clock time); the night, the twilight, the Sun and the Moon follow
  it, a label on the map names the instant, Places keeps the real time.
  `,` `.` a day, `Space` play, `⌫` now.
- **World: zoom, chips and a globe that fills the window.** A cluster at
  the top right (crosshair, −, +), `+` `−`, `Ctrl` + wheel at the pointer
  or a double click zoom the globe and the map in three steps (to about
  1,600 km across); zoomed in, a drag turns and tilts the globe to any
  latitude or pans the map, `0` shows the whole earth. The globe takes the
  height visible in the app or the popup (at least 240 points) and follows
  the window; the flat map narrows, centred, when it would not fit. Chips
  under the view switch the shape, the night, the twilight bands, the Moon,
  the labels and the ruler.
- **The globe and the map on the GPU:** where the graphics allow it, the
  zones, the land, the coast, the grid, the night and the golden and blue
  bands are drawn by a shader (shared with More Weather) from a picture
  painted once per change, so while the globe turns only the Sun, the Moon
  and the places are drawn per frame. Without GPU drawing, and zoomed in to
  the last step, it draws as before. The IPC status reports the globe's
  frames and processor share.
- **Motion that rests when nobody looks:** the globe and the solar system
  turn by themselves only while you can see them, with the popup open or
  the app window shown, focused or not; on another workspace or with the
  monitor off (both asked of Hyprland) the turns, the time lapses and the
  ISS refresh rest and use next to no CPU, and go on at once when you are
  back. Each step is timed from the last frame shown, so the pace stays
  even; a tilted globe turns round its axis. While turning the globe is
  drawn more simply, and one Motion group in General sets the delay, the
  speed and the frames per second (8, 15, 24 or 30; 15 by default) for
  every view that turns.
- **The Moon as seen from here:** Display → Moon view → "As seen from here"
  draws the Moon on the map and the globe as it stands in the sky of the
  current place at that moment: its lit side tilted as you see it there, a
  thin crescent's dark side lit by earthshine, dimmed while it is below the
  horizon. Its hover, the Astro Moon label and the info add its height and
  direction and when it rises and sets there.
- **One Sun, drawn as in More Weather:** the map, the globe, Astro and the
  sun icons draw the Sun in the same gold, softened towards the text colour
  until it reads at 3:1; sunrise and sunset are a horizon with an arrow, in
  the clock's sun line and in Places. On the map and the globe the blue
  hour deepens from the day/night line towards the night.
- **Settings, reorganised:** a search across every page (`/`), finding
  settings in the interface language or in English, above the pages;
  General in sections (language and format, location, defaults for new
  items, motion, app, back up and restore); sub-headings in the long cards
  (World: map, sky; Astro: shown, objects, time; Clock: clock, sun, more);
  "Copy to the widget / app" in Display; the map's choice is now called
  Shape and Astro's "Info line" Info.
- **What's new in the settings:** a sixth page shows this change log, a card
  per version, newest first, read from the installed plugin.
- **Control hints,** a switch in Settings › General › App (on by default):
  off, the lines that explain keys and gestures disappear and leave their room to
  the content; the Shortcuts page stays.
- **Chimes are off by default:** for fresh settings, the hour chime too;
  settings saved before keep their chimes.
- **Fewer words on buttons, clearer chips:** "+" for a new city, alarm,
  stopwatch or pomodoro and ‹ › for the sky events' pages, with their full
  names as tooltips (also on ▶ and the zoom buttons) and for screen
  readers. A chip that is on has the selected fill and accent text, readable
  on light themes too; buttons and fields share the dropdowns' height.
- **Tooltip on hover:** a new menu bar option (off by default) shows the
  bar's tooltip with every entry of the clock, the hover ones included, one
  per line with a word for each symbol, updated while it is shown.
- **Shared with More Weather:** the sun and sky calculations (`Sky.js`),
  the tilting and zooming globe (`Globe.js`, `data/globe-land.json`), the
  Equal Earth map (`EqualEarth.js`), the Moon (`Moon.js`, `MoonView.js`),
  the GPU surface, the change log reader (`Changelog.js`) and the motion and screen helpers
  (`MotionGate.qml`, `ScreenState.qml`) are the same files in both plugins,
  with their tests.

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
