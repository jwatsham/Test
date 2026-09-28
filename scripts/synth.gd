class_name Synth
extends RefCounted
## Procedural audio. Every sound in the game is generated at runtime, so the
## prototype has zero binary assets. To use real music later, set a level's
## "music" field (see levels.gd) and this is only used for SFX.

const RATE := 22050

static var _rng := RandomNumberGenerator.new()

# Bass roots cycle every 4 bars (MIDI notes: C2, C2, F2, G2).
const ROOTS := [36, 36, 41, 43]
# Eighth-note bass pattern, semitones above the root. -99 = rest.
const BASS_A := [0, -99, -99, 0, -99, -99, 12, -99]
const BASS_B := [0, -99, 12, 0, -99, 0, 7, 12]
# Kazoo melody (eighth notes) for the "c" section, relative to root + 24.
const KAZOO := [12, 12, 10, 7, -99, 7, 10, 12]


static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


static func to_bytes(buf: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(buf.size() * 2)
	for i in buf.size():
		out.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	return out


static func to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = to_bytes(buf)
	return wav


static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


# --- Instruments. Each one mixes itself into `buf` starting at sample `at`. ---

static func kick(buf: PackedFloat32Array, at: int, vol := 0.9) -> void:
	var phase := 0.0
	for i in int(0.3 * RATE):
		var j := at + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		phase += TAU * (48.0 + 120.0 * exp(-t * 30.0)) / RATE
		buf[j] += sin(phase) * exp(-t * 10.0) * vol


static func snare(buf: PackedFloat32Array, at: int, vol := 0.45) -> void:
	for i in int(0.2 * RATE):
		var j := at + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0) * exp(-t * 22.0) * 0.8
		var body := sin(TAU * 185.0 * t) * exp(-t * 30.0) * 0.5
		buf[j] += (noise + body) * vol


static func hat(buf: PackedFloat32Array, at: int, vol := 0.16) -> void:
	var prev := 0.0
	for i in int(0.05 * RATE):
		var j := at + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		buf[j] += (x - prev) * exp(-t * 90.0) * vol
		prev = x


static func woodblock(buf: PackedFloat32Array, at: int, freq := 1200.0, vol := 0.4) -> void:
	for i in int(0.08 * RATE):
		var j := at + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		buf[j] += sin(TAU * freq * t) * exp(-t * 55.0) * vol


static func bass(buf: PackedFloat32Array, at: int, note: float, length: float, vol := 0.32) -> void:
	# A goofy "bwow": pitch starts high and drops into the note.
	var f := midi_hz(note)
	var phase := 0.0
	var n := int(length * RATE)
	for i in n + int(0.03 * RATE):
		var j := at + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		phase += TAU * f * (1.0 + 0.6 * exp(-t * 35.0)) / RATE
		var env := minf(t * 300.0, 1.0) * exp(-t * 4.0)
		if i > n:
			env *= 1.0 - float(i - n) / (0.03 * RATE)
		buf[j] += tanh(sin(phase) * 2.5) * env * vol


static func kazoo(buf: PackedFloat32Array, at: int, note: float, length: float, vol := 0.13) -> void:
	var f := midi_hz(note)
	var phase := 0.0
	var lp := 0.0
	var n := int(length * RATE)
	for i in n:
		var j := at + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		phase += f * (1.0 + 0.015 * sin(TAU * 6.0 * t)) / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		lp += (saw - lp) * 0.3
		var env := minf(t * 50.0, 1.0) * minf(float(n - i) / (0.03 * RATE), 1.0)
		buf[j] += lp * env * vol


# --- Music ---

static func render_bar(variant: String, root: int, spb_samples: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(round(spb_samples * 4.0)))
	var e := spb_samples / 2.0  # samples per eighth note
	var eighth_sec := e / RATE
	match variant:
		"count":
			for b in 4:
				woodblock(buf, int(b * spb_samples), 1500.0 if b == 0 else 1100.0)
				hat(buf, int((b + 0.5) * spb_samples), 0.08)
		"a":
			for b in 4:
				if b % 2 == 0:
					kick(buf, int(b * spb_samples))
			for s in 8:
				hat(buf, int(s * e))
				if BASS_A[s] != -99:
					bass(buf, int(s * e), root + BASS_A[s], eighth_sec * 0.9)
		"b", "c":
			for b in 4:
				kick(buf, int(b * spb_samples), 0.85 if b % 2 == 0 else 0.6)
				if b % 2 == 1:
					snare(buf, int(b * spb_samples))
			for s in 8:
				hat(buf, int(s * e), 0.2 if s % 2 == 1 else 0.12)
				if BASS_B[s] != -99:
					bass(buf, int(s * e), root + BASS_B[s], eighth_sec * 0.85)
				if variant == "c" and KAZOO[s] != -99:
					kazoo(buf, int(s * e), root + 24 + KAZOO[s], eighth_sec * 0.9)
		"end":
			kick(buf, 0)
			snare(buf, 0, 0.6)
			bass(buf, 0, 36, spb_samples * 2.0 / RATE)
	return buf


## Builds a full song from a list of bar variants ("count", "a", "b", "c",
## "end"). Returns {"stream": AudioStreamWAV, "spb": seconds_per_beat}.
## The returned spb is exact for the rendered audio, so always use it for timing.
static func build_song(bpm: float, arrangement: PackedStringArray, loop := false) -> Dictionary:
	_rng.seed = 42
	var bar_len := int(round(60.0 / bpm * RATE * 4.0))
	var spb_samples := bar_len / 4.0
	var cache := {}
	var data := PackedByteArray()
	for i in arrangement.size():
		var variant := arrangement[i]
		var root: int = ROOTS[i % ROOTS.size()]
		var key := "%s_%d" % [variant, root]
		if not cache.has(key):
			cache[key] = to_bytes(render_bar(variant, root, spb_samples))
		data.append_array(cache[key])
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	return {"stream": wav, "spb": spb_samples / RATE}


# --- Sound effects ---

static func crack_sfx() -> AudioStreamWAV:
	var buf := _buffer(0.25)
	for click_at in [0.0, 0.016, 0.037, 0.065]:
		var start := int(click_at * RATE)
		for i in int(0.03 * RATE):
			var t := float(i) / RATE
			buf[start + i] += _rng.randf_range(-1.0, 1.0) * exp(-t * 350.0) * 0.9
	for i in buf.size():
		var t := float(i) / RATE
		buf[i] += sin(TAU * 110.0 * t) * exp(-t * 25.0) * 0.5
	return to_wav(buf)


static func womp_sfx() -> AudioStreamWAV:
	# Sad trombone-ish "wah-wahhh".
	var buf := _buffer(0.7)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := 311.0 if t < 0.25 else 233.0 - (t - 0.25) * 60.0
		f *= 1.0 + 0.02 * sin(TAU * 7.0 * t)
		phase += TAU * f / RATE
		var env := minf(t * 40.0, 1.0) * minf((0.7 - t) * 8.0, 1.0)
		if absf(t - 0.25) < 0.02:
			env *= 0.3
		buf[i] = tanh(sin(phase) * 3.0) * env * 0.3
	return to_wav(buf)


static func whiff_sfx() -> AudioStreamWAV:
	var buf := _buffer(0.16)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * (0.1 + t * 3.0)
		buf[i] = lp * sin(PI * t / 0.16) * 0.5
	return to_wav(buf)


static func boing_sfx() -> AudioStreamWAV:
	var buf := _buffer(0.35)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		phase += TAU * (220.0 + 380.0 * t / 0.35 + 40.0 * sin(TAU * 18.0 * t)) / RATE
		buf[i] = sin(phase) * exp(-t * 6.0) * 0.35
	return to_wav(buf)
