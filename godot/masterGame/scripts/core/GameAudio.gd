extends Node
# Original procedural cues; no third-party sampled recordings.
var voices: Array[AudioStreamPlayer] = []
var music_voice: AudioStreamPlayer
var cues: Dictionary = {}
var last_shot := 0.0
func _exit_tree() -> void:
	stop_all()
	cues.clear()
	voices.clear()

func stop_all() -> void:
	if music_voice != null:
		music_voice.stop()
		music_voice.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
func _ready() -> void:
	ensure_bus("Music", -23.0)
	ensure_bus("SFX", -18.0)
	for index in range(8):
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		voices.append(voice)
	music_voice = AudioStreamPlayer.new()
	music_voice.bus = "Music"
	add_child(music_voice)
	cues.shot = synth(180, 70, 0.065, 0.25)
	cues.hit = synth(120, 45, 0.1, 0.5)
	cues.upgrade = synth(440, 880, 0.3, 0.0)
	cues.nova = synth(70, 280, 0.45, 0.3)
	cues.reward = synth(660, 990, 0.2, 0.0)
	music_voice.stream = ambient_loop()
	music_voice.play()

func ensure_bus(name: String, volume: float) -> void:
	if AudioServer.get_bus_index(name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, name)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(name), volume)

func ambient_loop() -> AudioStreamWAV:
	var stream := synth(82, 110, 8.0, 0.0)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	return stream

func set_music_enabled(enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not enabled)

func synth(start: float, finish: float, duration: float, noise: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var samples := PackedByteArray()
	var count := int(sample_rate * duration)
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var phase := 0.0
	for index in range(count):
		var fraction := float(index) / count
		phase += TAU * lerpf(start, finish, fraction) / sample_rate
		var envelope := minf(1, fraction * 30) * pow(1 - fraction, 2)
		var sample := (sin(phase) * (1 - noise) + rng.randf_range(-1, 1) * noise) * envelope
		samples.encode_s16(index * 2, int(sample * 20000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = samples
	return stream

func play_cue(id: String) -> void:
	if not cues.has(id): return
	if id == "shot":
		var now := Time.get_ticks_msec() / 1000.0
		if now - last_shot < 0.07: return
		last_shot = now
	for voice in voices:
		if not voice.playing:
			voice.stream = cues[id]
			voice.play()
			return
