import { test } from "node:test"
import assert from "node:assert"
import { readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"
import { load, root } from "./load.mjs"

const I18n = load("I18n.js")
const english = I18n.catalog.en
// The product name reads the same everywhere and may fall back to English.
const universal = new Set(["appTitle"])

test("all 30 languages are there", () => {
  assert.equal(I18n.supportedLanguages().length, 30)
  for (const language of I18n.supportedLanguages())
    assert.ok(I18n.catalog[language], `no catalogue for ${language}`)
})

test("every language has every English text", () => {
  const missing = []
  for (const language of I18n.supportedLanguages()) {
    for (const key of Object.keys(english)) {
      if (universal.has(key)) continue
      if (typeof I18n.catalog[language][key] !== "string") missing.push(`${language}: ${key}`)
    }
  }
  assert.deepEqual(missing, [])
})

test("no language has texts English lacks", () => {
  const extra = []
  for (const language of I18n.supportedLanguages())
    for (const key of Object.keys(I18n.catalog[language]))
      if (!(key in english)) extra.push(`${language}: ${key}`)
  assert.deepEqual(extra, [])
})

test("placeholders survive translation", () => {
  const broken = []
  for (const [key, text] of Object.entries(english)) {
    const names = (String(text).match(/\{[a-zA-Z]+\}/g) || []).sort().join(",")
    for (const language of Object.keys(I18n.catalog)) {
      const translated = I18n.catalog[language][key]
      if (typeof translated !== "string") continue
      const found = (translated.match(/\{[a-zA-Z]+\}/g) || []).sort().join(",")
      if (found !== names) broken.push(`${language}: ${key} has ${found || "none"}, expects ${names || "none"}`)
    }
  }
  assert.deepEqual(broken, [])
})

// Every key the views ask for exists; keys built from a prefix are listed
// with the values the code uses.
test("every key used in the QML exists", () => {
  const families = {
    entry_: ["time", "seconds", "weekday", "date", "week", "cities", "nextAlarm", "timers", "stopwatches", "pomodoros", "ringing", "pomodoroTally"],
    sound_: ["alarm", "bell", "complete", "message", "phone", "none"],
    settingsPage_: ["general", "display", "sounds", "shortcuts", "sources"],
    dial_: ["classic", "minimal", "roman", "twentyFour", "dots"],
    astroBody_: ["sun", "mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune", "moon"]
  }
  const used = new Set()
  for (const file of readdirSync(root).filter((name) => name.endsWith(".qml"))) {
    const source = readFileSync(join(root, file), "utf8")
    for (const match of source.matchAll(/(?:i18n|label)\(\s*"([A-Za-z0-9_]+)"/g)) used.add(match[1])
    for (const match of source.matchAll(/(?:action|title|details): "((?:shortcut|source)[A-Za-z]+)"/g)) used.add(match[1])
    for (const match of source.matchAll(/"(mouse(?:Left|Middle|Right|Pin|PlaceName))"/g)) used.add(match[1])
  }
  for (const [prefix, names] of Object.entries(families)) {
    used.delete(prefix)
    for (const name of names) used.add(prefix + name)
  }
  for (const tab of ["world", "alarms", "timers", "stopwatches", "pomodoros", "astro"]) {
    used.add(tab + "Tab")
    used.add(tab + "TabHint")
  }
  for (const surface of ["menubar", "widget", "app"]) used.add(surface + "Settings")
  const missing = [...used].filter((key) => !(key in english)).sort()
  assert.deepEqual(missing, [])
})

test("locale resolution", () => {
  assert.equal(I18n.resolvedLanguage("auto", "de_DE.UTF-8"), "de")
  assert.equal(I18n.resolvedLanguage("auto", "zh_HK"), "zh_TW")
  assert.equal(I18n.resolvedLanguage("auto", "nn_NO"), "nb")
  assert.equal(I18n.resolvedLanguage("fr", "de_DE"), "fr")
  assert.equal(I18n.resolvedLanguage("xx", "en_US"), "en")
  assert.ok(I18n.isRightToLeft("fa"))
  assert.equal(I18n.text("de", "weekShort", { week: 40 }), "KW 40")
  assert.equal(I18n.text("xx", "weekShort", { week: 40 }), "W40")
})
