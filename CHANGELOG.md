# Changelog

All notable changes to More Time are documented here.

## 1.0.0 — 2026-10-02

First release.

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
- **Sun:** sunrise and sunset, the golden and the blue hour in the clock (on
  in the app, off in the widget) and per city the sunrise, the sunset and the
  next of the two (with More Weather's arrow icon); the map and the globe
  mark the twilight as a gold band on the day side of the day/night line and
  a blue one on the night side, under a clearly darker night side.
- **World clock:**
  - A map of the real time zones in zebra stripes, in the Equal Earth
    projection, with the night side, the sun, an hour ruler and your cities.
  - Or a globe (Settings → Display → Map style): the same zones and cities
    in an orthographic view, with the golden and blue hour as bands along the
    day/night line; it turns to the picked place, by drag or sideways wheel,
    and optionally by itself after 5, 10 or 30 idle seconds, one turn in 1, 2,
    4 or 8 minutes.
  - Optionally the Moon at its sub-lunar point with its phase, on the map and
    the globe, with More Weather's phase numbers.
  - Your own place is shown with More Weather's location pin, not a word.
  - A city list with the day and the difference to here.
  - Five clock face styles (classic, minimal, roman, 24 hours with the night
    shaded, dots), chosen per place with `e` or the pencil on any row; small
    faces in the list; one style for the clock on top if you like.
  - City search offline from the tz database and online through the place
    search shared with More Weather (Open-Meteo, else Nominatim, with the
    nearest zone for its places), with More Weather's keys.
  - Import of More Weather's saved places as cities (Settings → General →
    Places).
- **Scrolling:** wheel and touchpad scroll as in More Weather (a fixed step
  per notch, touchpad deltas scaled up), in the view and in the settings;
  the globe and the editors' values keep the wheel where they use it.
- **Alarms:** as many as you like, once or on weekdays, with a name and a
  snooze length. Missed alarms are announced, and alarms up to ten minutes late
  still ring. The last check is kept on disk, so an alarm due while the
  computer was off is announced as missed after a reboot, and a once-alarm is
  switched off instead of ringing the next day.
- **Timers:** as many as you like, from presets or typed lengths, with
  pause, ±1 minute and progress. A name can follow the typed length
  (`10 Tea`).
- **Stopwatches:** as many as you like, with laps and hundredths.
- **Pomodoros:** as many as you like, with focus and break lengths (25/5 to
  begin with), an optional long break and auto continue.
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
