class_name AnimClip
extends RefCounted
## Clipe de animação de captura de movimento já no esqueleto do HumanoidRig (gerado por
## tools/blender/mixamo_to_clip.py a partir do Mixamo). Rotações locais das juntas em graus (Euler YXZ,
## mesmo formato das poses de Poses.gd), raiz em "alturas de quadril" e contato de cada pé por quadro.

const DIR := "res://characters/anims/"

static var _cache: Dictionary = {}

var name := ""
var fps := 30.0
var loop := false
var frames := 0
## Ciclos: velocidade natural e distância de um ciclo (2 passos), em alturas de quadril.
var speed := 0.0
var cycle_dist := 0.0
## Ciclos: quanto à frente do quadril o pé pousa (alturas de quadril).
var touch_ahead := 0.0
## Não-ciclos: frações 0..1 (takeoff/apex/land no pulo; start/end = trecho ativo).
var markers: Dictionary = {}
## Ciclos: início (u) de cada ciclo no clipe (o Mixamo às vezes grava vários ciclos seguidos).
var cycle_starts := PackedFloat32Array([0.0])
var _ch: Dictionary = {} # junta -> PackedVector3Array
var _pitch := PackedFloat32Array()
var _root := PackedVector3Array()
var _contact_l := PackedByteArray()
var _contact_r := PackedByteArray()


## Clipe pelo nome (ex.: "walk"); null se o arquivo não existe. Fica em cache.
static func get_clip(clip_name: String) -> AnimClip:
	if _cache.has(clip_name):
		return _cache[clip_name]
	var path := DIR + clip_name + ".json"
	var clip: AnimClip = null
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			clip = AnimClip.new()
			clip._load(data)
	_cache[clip_name] = clip
	return clip


static func clear_cache() -> void:
	_cache.clear()


func _load(d: Dictionary) -> void:
	name = d.get("name", "")
	fps = float(d.get("fps", 30.0))
	loop = bool(d.get("loop", false))
	frames = int(d.get("frames", 0))
	speed = float(d.get("speed", 0.0))
	cycle_dist = float(d.get("cycle_dist", 0.0))
	touch_ahead = float(d.get("touch_ahead", 0.0))
	markers = d.get("markers", {})
	if d.has("cycle_starts") and not (d["cycle_starts"] as Array).is_empty():
		cycle_starts = PackedFloat32Array(d["cycle_starts"])
	var chans: Dictionary = d.get("channels", {})
	for j in chans:
		var arr := PackedVector3Array()
		for v in chans[j]:
			arr.append(Vector3(v[0], v[1], v[2]))
		_ch[j] = arr
	for v in d.get("pitch", []):
		_pitch.append(float(v))
	for v in d.get("root", []):
		_root.append(Vector3(v[0], v[1], v[2]))
	for v in d.get("contact_l", []):
		_contact_l.append(int(v))
	for v in d.get("contact_r", []):
		_contact_r.append(int(v))
	frames = mini(frames, _pitch.size()) if frames > 0 else _pitch.size()


## Fração do ciclo com o pé no chão (média dos dois pés). Correndo é bem menos que andando (fase de voo).
func stance_frac() -> float:
	var n := _contact_l.size() + _contact_r.size()
	if n == 0:
		return 0.5
	var c := 0
	for v in _contact_l:
		c += v
	for v in _contact_r:
		c += v
	return float(c) / n


func duration() -> float:
	return frames / fps


## Índices e peso entre os dois quadros vizinhos de u (0..1).
func _at(u: float) -> Vector3:
	var f: float
	if loop:
		f = fposmod(u, 1.0) * frames
	else:
		f = clampf(u, 0.0, 1.0) * (frames - 1)
	var i0 := int(floor(f))
	var w := f - i0
	var i1 := i0 + 1
	if loop:
		i0 %= frames
		i1 %= frames
	else:
		i0 = mini(i0, frames - 1)
		i1 = mini(i1, frames - 1)
	return Vector3(i0, i1, w)


## u do clipe para a fase do passo (radianos, crescendo sem limite): o ciclo k do clipe é tocado na
## volta k da fase, então clipes com vários ciclos continuam com o passo do tamanho certo.
func gait_u(phase: float) -> float:
	var turns := phase / TAU
	var n := cycle_starts.size()
	var k := posmod(int(floor(turns)), n)
	var a := cycle_starts[k]
	var b := cycle_starts[k + 1] if k + 1 < n else 1.0
	return a + fposmod(turns, 1.0) * (b - a)


## Fração do clipe ocupada pelo ciclo que contém u (para converter distâncias em u para fase).
func cycle_span(u: float) -> float:
	var n := cycle_starts.size()
	for k in n:
		var b := cycle_starts[k + 1] if k + 1 < n else 1.0
		if u < b:
			return maxf(b - cycle_starts[k], 0.01)
	return maxf(1.0 - cycle_starts[n - 1], 0.01)


## Pose em u (0..1 do clipe): juntas do rig (graus), "pitch" (giro do corpo inteiro) e "root" (raiz em
## alturas de quadril; multiplique por hip_y). Ciclos: o fim emenda no começo.
func sample(u: float) -> Dictionary:
	var a := _at(u)
	var i0 := int(a.x)
	var i1 := int(a.y)
	var w := a.z
	var out := {}
	for j in _ch:
		var arr: PackedVector3Array = _ch[j]
		var v0 := arr[i0]
		var v1 := arr[i1]
		if loop and i1 < i0: # volta do ciclo: o último quadro pode estar 360° à frente
			v1 = v0 + _wrap_delta(v1 - v0)
		out[j] = v0.lerp(v1, w)
	var p0 := _pitch[i0]
	var p1 := _pitch[i1]
	if loop and i1 < i0:
		p1 = p0 + wrapf(p1 - p0, -180.0, 180.0)
	out["pitch"] = Vector3(lerpf(p0, p1, w), 0, 0)
	out["root"] = _root[i0].lerp(_root[i1], w)
	return out


## Contato do pé (0 ou 1) em u; side 0 = esquerdo, 1 = direito. Quadro mais próximo (sem misturar):
## contact, until_contact e until_liftoff usam o mesmo quadro, então nunca se contradizem.
func contact(u: float, side: int) -> float:
	var arr := _contact_l if side == 0 else _contact_r
	if arr.is_empty() or frames == 0:
		return 0.0
	return float(arr[_frame_of(u)])


func _frame_of(u: float) -> int:
	var f := fposmod(u, 1.0) * frames if loop else clampf(u, 0.0, 1.0) * (frames - 1)
	return int(round(f)) % frames


## Quanto de u falta até o pé tocar o chão de novo (0 se já está apoiado). Só ciclos.
func until_contact(u: float, side: int) -> float:
	var arr := _contact_l if side == 0 else _contact_r
	if arr.is_empty() or frames == 0:
		return 1.0
	var f := fposmod(u, 1.0) * frames
	var start := _frame_of(u)
	for k in frames:
		if arr[(start + k) % frames] == 1:
			return maxf(start + k - f, 0.0) / frames
	return 1.0


## Quanto de u falta até o pé sair do chão (0 se já está no ar). Só ciclos.
func until_liftoff(u: float, side: int) -> float:
	var arr := _contact_l if side == 0 else _contact_r
	if arr.is_empty() or frames == 0:
		return 0.0
	var f := fposmod(u, 1.0) * frames
	var start := _frame_of(u)
	for k in frames:
		if arr[(start + k) % frames] == 0:
			return maxf(start + k - f, 0.0) / frames
	return 1.0


static func _wrap_delta(d: Vector3) -> Vector3:
	return Vector3(wrapf(d.x, -180.0, 180.0), wrapf(d.y, -180.0, 180.0), wrapf(d.z, -180.0, 180.0))
