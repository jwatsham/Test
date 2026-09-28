class_name Levels
extends RefCounted
## Level data. Each chart string is one bar of 4 beats:
##   x = a one-crack patient arrives on this beat
##   d = a two-crack patient (cracks on the beat AND the next half-beat)
##   . = nobody
## Chart bar 0 lines up with song bar `intro_bars`.
##
## "arrangement" is the procedural song, one word per bar:
##   count = woodblock count-in, a = light groove, b = full groove,
##   c = full groove + kazoo, end = final hit.
## To use a real track instead: set "music" to a res:// path (ogg/wav/mp3),
## set "bpm" to the track's tempo and "music_offset" to the time in seconds of
## the first beat. Keep "arrangement" so the game knows how long the song is.

const ALL := [
	{
		"title": "Monday Morning Adjustments",
		"bpm": 108.0,
		"seed": 7,
		"music": "",
		"music_offset": 0.0,
		"intro_bars": 2,
		"arrangement": "count count a a a a b b b b b b b b c c c c c c c c b b b b c c c c end end",
		"chart": [
			"x...", "x...", "x.x.", "x.x.",
			"x.x.", "x.x.", "xxx.", "x.x.",
			"x.xx", "x.x.", "xxx.", "xxxx",
			"d...", "x.d.", "d.x.", "x.x.",
			"d.d.", "xx.x", "d.xx", "xxxx",
			"x.x.", "d.x.", "xxd.", "d.d.",
			"xxxx", "d.xd", "xdx.", "d...",
		],
	},
]
