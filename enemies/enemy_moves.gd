class_name EnemyMoves
extends RefCounted
## Tabelas de golpes por arquétipo (Enemy.move_set). Cada golpe:
##   anim, windup, active, recovery, cooldown, weight (chance relativa), damage, knockback, hitstun,
##   hitstop, lunge, size/offset (hitbox), glow (cor da telegrafia).
## Opcionais: "explosion" (raio de uma onda de choque contra o player no início da fase ativa),
##            "shake" (tremor ao fim do golpe).

const SETS := {
	&"grunt": {
		"swing": {
			"anim": "e_swing", "weight": 0.6, "windup": 0.45, "active": 0.18, "recovery": 0.6, "cooldown": 1.1,
			"damage": 10, "knockback": 7.0, "hitstun": 0.35, "hitstop": 0.06, "lunge": 4.0,
			"size": Vector3(2.8, 1.6, 1.8), "offset": Vector3(0, 1.0, 1.0), "glow": Color(1.0, 0.55, 0.0),
		},
		"smash": {
			"anim": "e_smash", "weight": 0.4, "windup": 0.75, "active": 0.14, "recovery": 0.85, "cooldown": 1.5,
			"damage": 16, "knockback": 10.0, "hitstun": 0.5, "hitstop": 0.09, "lunge": 2.5,
			"size": Vector3(1.6, 2.0, 2.4), "offset": Vector3(0, 0.9, 1.4), "glow": Color(1.0, 0.15, 0.05),
			"shake": 0.14,
		},
	},
	&"brute": {
		"smash": {
			"anim": "e_smash", "weight": 0.6, "windup": 1.0, "active": 0.16, "recovery": 1.0, "cooldown": 1.6,
			"damage": 24, "knockback": 12.0, "hitstun": 0.6, "hitstop": 0.12, "lunge": 2.0,
			"size": Vector3(2.4, 2.6, 3.2), "offset": Vector3(0, 1.2, 1.9), "glow": Color(1.0, 0.1, 0.05),
			"shake": 0.25,
		},
		"stomp": {
			"anim": "e_smash", "weight": 0.4, "windup": 0.9, "active": 0.12, "recovery": 1.1, "cooldown": 2.2,
			"damage": 14, "knockback": 9.0, "hitstun": 0.5, "hitstop": 0.08, "lunge": 0.0,
			"size": Vector3(0.1, 0.1, 0.1), "offset": Vector3(0, 0.5, 0.5), "glow": Color(0.9, 0.4, 0.05),
			"explosion": 3.4, "shake": 0.3,
		},
	},
	&"archer": {
		"jab": {
			"anim": "e_swing", "weight": 1.0, "windup": 0.35, "active": 0.14, "recovery": 0.5, "cooldown": 1.0,
			"damage": 6, "knockback": 6.0, "hitstun": 0.3, "hitstop": 0.05, "lunge": 3.0,
			"size": Vector3(2.0, 1.5, 1.4), "offset": Vector3(0, 1.0, 0.9), "glow": Color(1.0, 0.8, 0.2),
		},
	},
}


## Sorteia um golpe do conjunto pelo peso.
static func pick(set_id: StringName) -> Dictionary:
	var moves: Dictionary = SETS.get(set_id, SETS[&"grunt"])
	var total := 0.0
	for k in moves:
		total += float(moves[k].get("weight", 1.0))
	var r := randf() * total
	for k in moves:
		r -= float(moves[k].get("weight", 1.0))
		if r <= 0.0:
			return moves[k]
	return moves.values()[0]
