extends SummonState
## Skills de lançar parado no lugar (comandadas ou passivas), de todos os summons:
##  Golem:     quake (terremoto), taunt (provocar).
##  Sacerdote: heal, ward, bless, haste (buffs no jogador) | hex, slow (debuffs nos inimigos)
##             | smite (coluna de luz), nova (explosão de luz).
## Socos, Lançar pedra e Agarrar têm estados próprios (Strike em cadeia, Rock, Grab).

const TAUNT_TIME := 4.0
const HEAL_AMOUNT := 35
const DEBUFF_RADIUS := 9.0
const PRIEST_TIMES := {"anim": "priest_cast", "windup": 0.45, "active": 0.1, "recovery": 0.3}
const TIMES := {
	&"quake": {"anim": "e_smash", "windup": 0.55, "active": 0.12, "recovery": 0.5},
	&"taunt": {"anim": "taunt", "windup": 0.5, "active": 0.4, "recovery": 0.3},
}
## Passivas do sacerdote reaproveitam o efeito da skill comandada equivalente.
const ALIAS := {&"p_heal": &"heal", &"p_renew": &"renew", &"p_bless": &"bless", &"p_ward": &"ward", &"p_slow": &"slow", &"p_smite": &"smite"}
const COLORS := {
	&"heal": Color(0.4, 1.0, 0.55), &"renew": Color(0.5, 1.0, 0.7), &"ward": Color(0.4, 0.75, 1.0), &"bless": Color(1.0, 0.85, 0.3),
	&"haste": Color(0.5, 1.0, 0.6), &"hex": Color(0.7, 0.3, 0.9), &"slow": Color(0.5, 0.6, 1.0),
	&"smite": Color(1.0, 0.9, 0.5), &"nova": Color(1.0, 0.95, 0.7), &"taunt": Color(1.0, 0.6, 0.2),
	&"quake": Color(0.7, 0.6, 0.4),
}

var _id: StringName = &"quake"
var _t := 0.0
var _applied := false


func enter(msg: Dictionary = {}) -> void:
	var raw: StringName = msg.get("id", &"quake")
	_id = ALIAS.get(raw, raw)
	_t = 0.0
	_applied = false


func exit() -> void:
	s.rig.set_glow(Color.BLACK)


func _times() -> Dictionary:
	return TIMES[_id] if TIMES.has(_id) else PRIEST_TIMES


func physics_update(delta: float) -> void:
	var c := s
	var tm := _times()
	var windup: float = tm["windup"]
	var active: float = tm["active"]
	var recovery: float = tm["recovery"]
	_t += delta
	c.apply_gravity(delta)
	c.accelerate(Vector3.ZERO, 0.0, 40.0, delta)
	c.rig.set_attack(tm["anim"], windup, active, recovery, _t)
	var glow: Color = COLORS.get(_id, Color.WHITE)
	c.rig.set_glow(glow * minf(_t / windup, 1.0) * 0.6 if _t < windup + active else Color.BLACK)

	if not _applied and _t >= windup:
		_applied = true
		_cast()
	c.move_and_slide()
	if _t >= windup + active + recovery:
		machine.change_to(&"Chase")


func _cast() -> void:
	var color: Color = COLORS.get(_id, Color.WHITE)
	var at := s.global_position + Vector3(0, 1.2, 0)
	match _id:
		&"taunt":
			Sfx.play(&"roar", at, 3.0, 0.9)
		&"heal", &"renew":
			Sfx.play(&"heal", at)
		&"smite":
			Sfx.play(&"zap", at)
		&"nova":
			Sfx.play(&"heal", at, 0.0, 1.3)
	match _id:
		&"quake":
			_quake()
		&"taunt":
			_taunt()
		&"heal":
			_heal()
		&"ward", &"bless", &"haste":
			_buff_player(_id, _id)
		&"renew":
			_buff_player(&"regen", &"renew") # cura gradual: efeito "regen" do StatusEffects
		&"hex", &"slow":
			_debuff_enemies(_id)
		&"smite":
			_smite()
		&"nova":
			_nova()
	s.rig.flash(color, 0.35)


# --- Golem ---------------------------------------------------------------------------------

## Puxa e provoca todos os inimigos no raio; eles passam a atacar o golem por alguns segundos.
func _taunt() -> void:
	var c := s
	for e in c.get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		if en.global_position.distance_to(c.global_position) <= c.grab_radius:
			en.taunt(c, TAUNT_TIME)
			en.pull_toward(c.global_position)
	GameFeel.shake(0.2)
	GameFeel.rumble(0.3, 0.4, 0.2)
	Fx.spark(c, c.global_position + Vector3(0, 1.6, 0), Color(1.0, 0.7, 0.3))


## Terremoto: onda de choque marrom em volta do golem, lança os inimigos.
func _quake() -> void:
	var c := s
	_explode(c.global_position + Vector3(0, 0.3, 0), 5.0, 16, 7.0, 6.5, Color(0.6, 0.45, 0.28), c.owner_player)


# --- Sacerdote -----------------------------------------------------------------------------

func _heal() -> void:
	var c := s
	var p := c.owner_player
	if not is_instance_valid(p):
		return
	var player_health := p.get_node_or_null("Health") as Health
	if player_health != null:
		var got := player_health.heal(HEAL_AMOUNT)
		var color: Color = COLORS[&"heal"]
		Fx.damage_number(c, p.global_position + Vector3(0, 2.2, 0), got, color, "+%d" % got)
		Fx.spark(c, p.global_position + Vector3(0, 1.0, 0), color)
		if p.get("rig") != null:
			p.rig.flash(color, 0.5)


func _buff_player(effect: StringName, color_id: StringName) -> void:
	var p := s.owner_player
	if is_instance_valid(p):
		StatusEffects.apply(p, effect)
		Fx.spark(s, p.global_position + Vector3(0, 1.0, 0), COLORS[color_id])


func _debuff_enemies(id: StringName) -> void:
	var c := s
	for e in c.get_tree().get_nodes_in_group("enemy"):
		var en := e as Enemy
		if en.global_position.distance_to(c.global_position) <= DEBUFF_RADIUS:
			StatusEffects.apply(en, id)
			Fx.spark(c, en.global_position + Vector3(0, 1.0, 0), COLORS[id])


## Coluna de luz sobre o inimigo travado pelo jogador (ou o mais próximo do sacerdote).
func _smite() -> void:
	var c := s
	var target: Node3D = null
	if is_instance_valid(c.owner_player):
		var locked = c.owner_player.get("lock_target")
		if locked is Enemy and is_instance_valid(locked):
			target = locked
	if target == null:
		target = c.nearest_enemy_within(16.0)
	if target == null:
		return
	_explode(target.global_position + Vector3(0, 0.3, 0), 1.9, 22, 3.0, 2.5, COLORS[&"smite"], c)


## Nova sagrada: onda de luz em volta do sacerdote que empurra os inimigos para longe.
func _nova() -> void:
	var c := s
	_explode(c.global_position + Vector3(0, 0.3, 0), 4.2, 14, 10.0, 0.0, COLORS[&"nova"], c)


func _explode(pos: Vector3, radius: float, damage: int, knock: float, launch: float, color: Color, instigator: Node3D) -> void:
	var ex := Explosion.new()
	ex.radius = radius
	ex.damage = damage
	ex.knockback = knock
	ex.launch = launch
	ex.color = color
	ex.instigator = instigator
	ex.position = pos
	s.get_parent().add_child(ex)
