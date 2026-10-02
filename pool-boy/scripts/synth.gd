class_name Synth
extends RefCounted
## Procedural audio: the lounge music loop and every sound effect are
## generated at startup, so the project ships with zero audio files.

const RATE := 22050

static var _rng := RandomNumberGenerator.new()


static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


static func to_wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


# --- Instruments (mix into buf at sample `at`, wrapping so loops stay seamless) ---

static func _kick(buf: PackedFloat32Array, at: int, vol: float) -> void:
	var phase := 0.0
	for i in int(0.25 * RATE):
		var t := float(i) / RATE
		phase += TAU * (50.0 + 90.0 * exp(-t * 35.0)) / RATE
		buf[(at + i) % buf.size()] += sin(phase) * exp(-t * 12.0) * vol


static func _shaker(buf: PackedFloat32Array, at: int, vol: float) -> void:
	var prev := 0.0
	for i in int(0.07 * RATE):
		var t := float(i) / RATE
		var x := _rng.randf_range(-1.0, 1.0)
		var env := minf(t * 200.0, 1.0) * exp(-t * 55.0)
		buf[(at + i) % buf.size()] += (x - prev) * env * vol
		prev = x


static func _marimba(buf: PackedFloat32Array, at: int, note: float, vol: float) -> void:
	var f := midi_hz(note)
	for i in int(0.6 * RATE):
		var t := float(i) / RATE
		var s := sin(TAU * f * t) * exp(-t * 7.0) + 0.35 * sin(TAU * f * 4.0 * t) * exp(-t * 30.0)
		buf[(at + i) % buf.size()] += s * minf(t * 400.0, 1.0) * vol


static func _bass(buf: PackedFloat32Array, at: int, note: float, length: float, vol: float) -> void:
	var f := midi_hz(note)
	var n := int(length * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t * 150.0, 1.0) * exp(-t * 2.5) * minf(float(n - i) / (0.02 * RATE), 1.0)
		buf[(at + i) % buf.size()] += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * vol


## A lazy 4-bar bossa-ish loop. Uses a whole number of samples per beat so it
## loops forever without drifting.
static func music_loop(bpm := 104.0) -> AudioStreamWAV:
	_rng.seed = 11
	var beat := int(round(60.0 / bpm * RATE))
	var e := beat / 2
	var buf := PackedFloat32Array()
	buf.resize(beat * 16)
	var chords := [[57, 60, 64, 67], [55, 59, 62, 65], [53, 57, 60, 64], [52, 56, 59, 62]]
	var roots := [45, 43, 41, 40]
	for bar in 4:
		var b0: int = bar * beat * 4
		var root: int = roots[bar]
		for k in 4:
			_kick(buf, b0 + k * beat, 0.45 if k % 2 == 0 else 0.25)
		for s in 8:
			_shaker(buf, b0 + s * e, 0.10 if s % 2 == 0 else 0.16)
		# Bossa bass: root, fifth on the "and" of 2, root, fifth.
		for step: Array in [[0, 0, 1.4], [3, 7, 0.4], [4, 0, 1.4], [7, 7, 0.4]]:
			_bass(buf, b0 + int(step[0]) * e, root + int(step[1]), float(step[2]) * 60.0 / bpm, 0.30)
		# Marimba chord stabs on a lopsided rhythm.
		for pos: int in [0, 3, 6]:
			for note: int in chords[bar]:
				_marimba(buf, b0 + pos * e, note + 12, 0.045)
	# Gentle limiter so stacked notes never clip harshly.
	for i in buf.size():
		buf[i] = tanh(buf[i] * 1.2)
	return to_wav(buf, true)


# --- Sound effects ---

static func scoop() -> AudioStreamWAV:
	# Cartoon "bloop": a quick upward pitch sweep.
	var buf := _buffer(0.18)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		phase += TAU * (300.0 + 900.0 * t / 0.18) / RATE
		buf[i] = sin(phase) * sin(PI * t / 0.18) * 0.5
	return to_wav(buf)


static func splash() -> AudioStreamWAV:
	_rng.seed = 3
	var buf := _buffer(0.45)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * (0.5 - t * 0.9)
		buf[i] = lp * minf(t * 80.0, 1.0) * exp(-t * 7.0) * 0.9
	return to_wav(buf)


static func dump() -> AudioStreamWAV:
	# Metal trash-can clang: a few inharmonic partials.
	var buf := _buffer(0.6)
	for i in buf.size():
		var t := float(i) / RATE
		var s := 0.0
		for f: float in [310.0, 497.0, 731.0, 1180.0]:
			s += sin(TAU * f * t) * exp(-t * (6.0 + f / 200.0))
		buf[i] = s * 0.18
	return to_wav(buf)


static func hey() -> AudioStreamWAV:
	# Grumpy "HEY!": a buzzy descending blat.
	var buf := _buffer(0.4)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		phase += TAU * (260.0 - t * 200.0) / RATE
		buf[i] = tanh(sin(phase) * 5.0) * minf(t * 60.0, 1.0) * minf((0.4 - t) * 12.0, 1.0) * 0.25
	return to_wav(buf)


static func ribbit() -> AudioStreamWAV:
	var buf := _buffer(0.32)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var croak := 1.0 if fmod(t, 0.16) < 0.09 else 0.0
		phase += TAU * (140.0 + 60.0 * sin(TAU * 30.0 * t)) / RATE
		buf[i] = tanh(sin(phase) * 4.0) * croak * 0.3
	return to_wav(buf)


static func whistle() -> AudioStreamWAV:
	# End-of-shift lifeguard whistle.
	var buf := _buffer(0.8)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		phase += TAU * (2300.0 + 120.0 * sin(TAU * 28.0 * t)) / RATE
		buf[i] = sin(phase) * minf(t * 40.0, 1.0) * minf((0.8 - t) * 10.0, 1.0) * 0.25
	return to_wav(buf)


static func womp() -> AudioStreamWAV:
	var buf := _buffer(1.0)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := 330.0 if t < 0.2 else (311.0 if t < 0.4 else (294.0 if t < 0.6 else 277.0 - (t - 0.6) * 40.0))
		phase += TAU * f * (1.0 + 0.02 * sin(TAU * 6.0 * t)) / RATE
		var gap := 0.3 if fmod(t, 0.2) < 0.015 and t < 0.65 else 1.0
		buf[i] = tanh(sin(phase) * 3.0) * gap * minf((1.0 - t) * 5.0, 1.0) * 0.28
	return to_wav(buf)


static func gust() -> AudioStreamWAV:
	_rng.seed = 5
	var buf := _buffer(1.2)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.05
		buf[i] = lp * sin(PI * t / 1.2) * 1.4
	return to_wav(buf)
