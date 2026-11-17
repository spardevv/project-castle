class_name GuardProfile
extends Resource
## Como a guarda (LT) se comporta. Sem escudo: reduz pouco o dano e ainda sofre colisão.
## Com escudo: bloqueia tudo, sem colisão, e permite parry no início da guarda.

@export var display_name := "Postura defensiva"
## 1.0 = sem redução; 0.0 = nega todo o dano.
@export_range(0.0, 1.0) var damage_multiplier := 0.75
@export_range(0.0, 1.0) var knockback_multiplier := 1.0
## Verdadeiro: o golpe não causa hitstun/colisão (o jogador continua na guarda).
@export var cancels_hitstun := false
## > 0: nos primeiros segundos da guarda o golpe é negado por completo (parry).
@export var parry_window := 0.0
@export var move_speed_multiplier := 0.6
## Pose de guarda com escudo à frente.
@export var uses_shield := false


static func bare() -> GuardProfile:
	return GuardProfile.new()


static func shield() -> GuardProfile:
	var g := GuardProfile.new()
	g.display_name = "Escudo"
	g.damage_multiplier = 0.0
	g.knockback_multiplier = 0.3
	g.cancels_hitstun = true
	g.parry_window = 0.2
	g.move_speed_multiplier = 0.75
	g.uses_shield = true
	return g
