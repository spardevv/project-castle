extends Node
## Sons do jogo (autoload Sfx). Não há arquivos de áudio no projeto: todos os efeitos são
## SINTETIZADOS em código (ruído filtrado, senoides, varreduras) na primeira vez que tocam e ficam
## em cache. Para trocar por áudio de verdade depois, basta mudar _build() para carregar arquivos.
##
## Sfx.play(&"hit")                    -> som sem posição (UI / jogador)
## Sfx.play(&"boom", pos, vol_db, pitch) -> som 3D na posição do mundo

const RATE := 22050
const MAX_VOICES := 20
## Volume geral (dB). Baixe mais se ainda estiver alto; suba se estiver baixo.
const MASTER_DB := -10.0
## Nível de pico dos sons gerados (0..1). Menos que 1 deixa folga para vários sons somarem sem estourar.
const PEAK := 0.5
## Intervalo mínimo (s) entre dois sons idênticos: evita empilhar o mesmo som no mesmo instante.
const MIN_REPEAT := 0.05

var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _voices := 0


func play(id: StringName, pos := Vector3.INF, volume_db := 0.0, pitch := 1.0) -> void:
	if _voices >= MAX_VOICES:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -1.0)) < MIN_REPEAT:
		return
	_last_played[id] = now
	var stream := _stream(id)
	if stream == null:
		return
	volume_db = minf(volume_db, 3.0) + MASTER_DB # reforços de volume ficam limitados
	var p: Node
	if pos.is_finite():
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db
		p3.pitch_scale = pitch * randf_range(0.96, 1.04)
		p3.unit_size = 14.0
		p3.max_distance = 70.0
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.volume_db = volume_db
		p2.pitch_scale = pitch * randf_range(0.97, 1.03)
		p = p2
	add_child(p)
	if p is AudioStreamPlayer3D:
		(p as AudioStreamPlayer3D).global_position = pos
	_voices += 1
	p.finished.connect(func() -> void:
		_voices -= 1
		p.queue_free())
	p.play()


func _stream(id: StringName) -> AudioStreamWAV:
	if not _cache.has(id):
		_cache[id] = _build(id)
	return _cache[id]


func _build(id: StringName) -> AudioStreamWAV:
	match id:
		&"swing": return _whoosh(0.2, 0.55, 0.5)
		&"swing_heavy": return _whoosh(0.34, 0.3, 0.8)
		&"whoosh": return _whoosh(0.22, 0.6, 0.45)
		&"hit": return _thud(0.16, 160.0, 0.9, 38.0)
		&"hit_heavy": return _thud(0.34, 85.0, 1.0, 16.0)
		&"hit_kill": return _thud(0.5, 60.0, 1.0, 10.0)
		&"punch": return _thud(0.22, 110.0, 1.0, 24.0)
		&"land": return _thud(0.14, 70.0, 0.8, 30.0)
		&"bow": return _thud(0.25, 240.0, 0.8, 20.0)
		&"clink": return _metal(0.5)
		&"boom": return _boom(0.8)
		&"jump": return _sweep(220.0, 420.0, 0.12, 0.45, 0.0)
		&"fire": return _mix(_whoosh(0.4, 0.4, 0.6), _sweep(260.0, 720.0, 0.4, 0.4, 0.1))
		&"art_use": return _mix(_sweep(180.0, 1400.0, 0.4, 0.5, 0.25), _boom(0.5))
		&"zap": return _sweep(1800.0, 150.0, 0.28, 0.6, 0.35)
		&"debuff": return _sweep(420.0, 140.0, 0.45, 0.6, 0.0, 14.0)
		&"heal": return _chime([784.0, 988.0, 1319.0], 0.7, 0.08)
		&"buff": return _chime([523.0, 659.0, 784.0, 1046.0], 0.55, 0.07)
		&"summon_priest": return _mix(_chime([659.0, 880.0, 1175.0, 1568.0], 0.95, 0.06), _sweep(500.0, 2200.0, 0.5, 0.15, 0.1))
		&"dismiss_priest": return _mix(_sweep(400.0, 1800.0, 0.7, 0.4, 0.0), _chime([1175.0, 1568.0], 0.7, 0.1))
		&"meteor_fall": return _mix(_sweep(1400.0, 180.0, 0.9, 0.4, 0.3), _whoosh(0.9, 0.5, 0.7))
		&"dismiss_golem": return _crumble(0.8)
		&"roar": return _roar(0.7)
		&"denied": return _beeps(0.3)
	return null


# --- Geradores ---------------------------------------------------------------------------------

func _make(dur: float, gen: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		# Limitador suave (tanh): picos altos são arredondados em vez de cortados (sem "estalo").
		var v := tanh(float(gen.call(float(i) / RATE, dur)))
		data.encode_s16(i * 2, int(v * PEAK * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## Soma dois sons (o resultado tem a duração do maior).
func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var da := a.data
	var db := b.data
	var n := maxi(da.size(), db.size()) / 2
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var va := da.decode_s16(i * 2) if i * 2 < da.size() else 0
		var vb := db.decode_s16(i * 2) if i * 2 < db.size() else 0
		# Soma com limitador suave, mantendo o mesmo pico dos sons individuais.
		var sum := tanh(float(va + vb) / (PEAK * 32000.0))
		data.encode_s16(i * 2, int(sum * PEAK * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


static func _noise() -> float:
	return randf() * 2.0 - 1.0


## Ruído filtrado que abre e fecha (golpe no ar). lp_max controla o quão "agudo" é.
func _whoosh(dur: float, lp_max: float, amp: float) -> AudioStreamWAV:
	var lp := [0.0]
	return _make(dur, func(t: float, d: float) -> float:
		var env := sin(PI * clampf(t / d, 0.0, 1.0))
		env *= env
		lp[0] += (_noise() - lp[0]) * lerpf(0.04, lp_max, env)
		return lp[0] * env * amp * 2.0)


## Pancada: senoide grave que cai de frequência + estalo de ruído.
func _thud(dur: float, freq: float, amp: float, decay: float) -> AudioStreamWAV:
	return _make(dur, func(t: float, _d: float) -> float:
		var body := sin(TAU * freq * (1.0 - t * 0.6) * t) * exp(-t * decay)
		var click := _noise() * exp(-t * decay * 3.0) * 0.5
		return (body + click) * amp)


## Metal: parciais inarmônicas que decaem (escudo/parry).
func _metal(dur: float) -> AudioStreamWAV:
	return _make(dur, func(t: float, _d: float) -> float:
		var v := 0.0
		for f in [1800.0, 2650.0, 3900.0, 5200.0]:
			v += sin(TAU * f * t) * exp(-t * 11.0) * 0.28
		return v + _noise() * exp(-t * 60.0) * 0.3)


func _boom(dur: float) -> AudioStreamWAV:
	var lp := [0.0]
	return _make(dur, func(t: float, d: float) -> float:
		lp[0] += (_noise() - lp[0]) * lerpf(0.25, 0.03, t / d)
		return lp[0] * 2.0 * exp(-t * 5.0) + sin(TAU * 48.0 * t) * exp(-t * 7.0) * 0.6)


## Varredura de frequência (f0 -> f1) com mistura de ruído e tremolo opcional.
func _sweep(f0: float, f1: float, dur: float, amp: float, noise_mix: float, tremolo := 0.0) -> AudioStreamWAV:
	var phase := [0.0]
	return _make(dur, func(t: float, d: float) -> float:
		var k := t / d
		phase[0] += TAU * lerpf(f0, f1, k) / RATE
		var env := sin(PI * clampf(k, 0.0, 1.0)) * (1.0 - k * 0.4)
		var trem := 1.0 if tremolo <= 0.0 else 0.6 + 0.4 * sin(TAU * tremolo * t)
		return (sin(phase[0]) * (1.0 - noise_mix) + _noise() * noise_mix) * env * amp * trem)


## Notas em sequência (arpejo) com brilho.
func _chime(freqs: Array, dur: float, step: float) -> AudioStreamWAV:
	return _make(dur, func(t: float, _d: float) -> float:
		var v := 0.0
		for i in freqs.size():
			var tt := t - i * step
			if tt > 0.0:
				var f: float = freqs[i]
				v += (sin(TAU * f * tt) + 0.35 * sin(TAU * f * 2.0 * tt)) * exp(-tt * 5.0) * 0.32
		return v)


func _roar(dur: float) -> AudioStreamWAV:
	var lp := [0.0]
	return _make(dur, func(t: float, d: float) -> float:
		var env := sin(PI * clampf(t / d, 0.0, 1.0))
		var f := 85.0 + sin(TAU * 7.0 * t) * 8.0
		var saw := fposmod(t * f, 1.0) * 2.0 - 1.0
		lp[0] += (_noise() - lp[0]) * 0.18
		return (saw * 0.55 + lp[0] * 1.6) * env * 0.8)


func _crumble(dur: float) -> AudioStreamWAV:
	var lp := [0.0]
	return _make(dur, func(t: float, _d: float) -> float:
		lp[0] += (_noise() - lp[0]) * 0.12
		var gate := 1.0 if sin(t * 41.0) > 0.4 else 0.25
		return lp[0] * 4.0 * gate * exp(-t * 3.0))


func _beeps(dur: float) -> AudioStreamWAV:
	return _make(dur, func(t: float, _d: float) -> float:
		var on := (t < 0.1) or (t > 0.16 and t < 0.26)
		return (1.0 if sin(TAU * 170.0 * t) > 0.0 else -1.0) * 0.25 if on else 0.0)
