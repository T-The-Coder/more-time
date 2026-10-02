import { test } from "node:test"
import assert from "node:assert"
import { execFileSync } from "node:child_process"
import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { root } from "./load.mjs"

// data/chime-tones.py writes an interval and an hour tone for each of the
// five chime tones: mono 16-bit WAV at 44.1 kHz, the length of the tone.
const lengths = { beep: 0.12, bell: 0.35, wood: 0.13, chirp: 0.11, glass: 0.25 }

test("chime tones: ten WAV files, two per tone", () => {
  const folder = mkdtempSync(join(tmpdir(), "more-time-tones-"))
  try {
    execFileSync("python3", [join(root, "data/chime-tones.py"), folder])
    const names = readdirSync(folder).sort()
    const expected = Object.keys(lengths).flatMap((tone) => [`chime-${tone}-hour.wav`, `chime-${tone}-interval.wav`]).sort()
    assert.deepEqual(names, expected)
    for (const name of names) {
      const data = readFileSync(join(folder, name))
      assert.equal(data.toString("ascii", 0, 4), "RIFF", name)
      assert.equal(data.toString("ascii", 8, 12), "WAVE", name)
      assert.equal(data.readUInt16LE(22), 1, `${name}: mono`)
      assert.equal(data.readUInt32LE(24), 44100, `${name}: rate`)
      assert.equal(data.readUInt16LE(34), 16, `${name}: 16 bit`)
      const tone = name.split("-")[1]
      const seconds = data.readUInt32LE(40) / 2 / 44100
      assert.ok(Math.abs(seconds - lengths[tone]) < 0.001, `${name}: ${seconds} s`)
      // Starts silent (no click), and is not silent throughout.
      assert.equal(data.readInt16LE(44), 0, `${name}: first sample`)
      let peak = 0
      for (let i = 44; i < data.length; i += 2) peak = Math.max(peak, Math.abs(data.readInt16LE(i)))
      assert.ok(peak > 15000, `${name}: peak ${peak}`)
    }
    // Only one tone asked for, and nothing written twice.
    const one = mkdtempSync(join(tmpdir(), "more-time-tones-"))
    execFileSync("python3", [join(root, "data/chime-tones.py"), one, "bell"])
    assert.deepEqual(readdirSync(one).sort(), ["chime-bell-hour.wav", "chime-bell-interval.wav"])
    rmSync(one, { recursive: true, force: true })
  } finally {
    rmSync(folder, { recursive: true, force: true })
  }
})
