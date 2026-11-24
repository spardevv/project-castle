class_name Health
extends Node

signal damaged(hit: HitData)
signal died
signal changed(current: int, maximum: int)

@export var max_health := 100

var current := 0
## Dano realmente aplicado no último golpe (já com redução de guarda).
var last_damage := 0
## Texto opcional do último golpe (ex.: "PARRY"), definido pelo hit_filter; mostrado no número de dano.
var last_tag := ""
var invulnerable := false # controlado por estados (ex.: esquiva)
## Opcional: recebe o HitData e devolve a versão modificada (ex.: guarda reduz dano).
var hit_filter: Callable
var _iframes := 0.0 # i-frames temporários (ex.: após levar dano)


func _ready() -> void:
	current = max_health


func _process(delta: float) -> void:
	if _iframes > 0.0:
		_iframes -= delta


func heal(amount: int) -> int:
	if current <= 0:
		return 0
	var before := current
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)
	return current - before


var _heal_carry := 0.0


## Cura gradual (regeneração): acumula frações e cura em pontos inteiros.
func heal_over_time(amount: float) -> void:
	_heal_carry += amount
	if _heal_carry >= 1.0:
		var whole := int(_heal_carry)
		_heal_carry -= whole
		heal(whole)


## Dano contínuo (zona arcana, aperto do golem): fere o alvo sem reação de golpe (stagger/hitstun).
## Mostra o número de dano e devolve true se causou dano.
static func dot(target: Node3D, amount: int, source: Node3D = null, color := Color.WHITE) -> bool:
	var hp := target.get_node_or_null("Health") as Health
	if hp == null or hp.current <= 0:
		return false
	var hit := HitData.new()
	hit.damage = amount
	hit.knockback = 0.0
	hit.hitstun = 0.0
	hit.hitstop = 0.0
	hit.dot = true
	hit.source = source
	if not hp.take_hit(hit):
		return false
	Fx.damage_number(target, target.global_position + Vector3(0, 2.0, 0), hp.last_damage, color)
	return true


func is_invulnerable() -> bool:
	return invulnerable or _iframes > 0.0


func grant_iframes(time: float) -> void:
	_iframes = maxf(_iframes, time)


## Retorna true se o golpe realmente causou dano.
func take_hit(hit: HitData) -> bool:
	if current <= 0 or is_invulnerable():
		return false
	last_tag = ""
	if hit_filter.is_valid():
		hit = hit_filter.call(hit)
	last_damage = hit.damage
	current = maxi(current - hit.damage, 0)
	changed.emit(current, max_health)
	damaged.emit(hit)
	if current <= 0:
		died.emit()
	return true
