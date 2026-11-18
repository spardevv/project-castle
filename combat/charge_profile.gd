class_name ChargeProfile
extends Resource
## Estâncias do ataque carregado de uma arma (0 a 3). Índice = estância; `times` tem só 3 valores
## (segundos segurando para atingir as estâncias 1, 2 e 3). Cada MoveSet tem o seu (MoveSet.charge).

const MAX_STANCE := 3

@export var times: Array[float] = [0.45, 0.95, 1.55]
## Multiplicadores do golpe liberado.
@export var damage: Array[float] = [1.0, 1.4, 1.9, 2.6]
@export var poise: Array[float] = [1.0, 1.4, 2.0, 3.0] # multiplica o dano no poise do alvo
@export var knockback: Array[float] = [1.0, 1.2, 1.5, 1.9]
@export var hitbox: Array[float] = [1.0, 1.1, 1.25, 1.5]
## Mitigação enquanto carrega (e na startup/janela ativa do golpe liberado).
@export var armor_damage: Array[float] = [0.85, 0.7, 0.55, 0.4] # dano recebido ×
@export var armor_poise: Array[float] = [1.5, 2.5, 4.0, 8.0] # divide o dano no seu poise
## A partir desta estância o golpe quebra super armor e o jogador ignora poise_break recebido.
@export var poise_break_from := 2
## Na estância máxima: lança o alvo, hitstun mínimo e o jogador fica inabalável (só launch derruba).
@export var max_launch := 5.0
@export var max_hitstun := 1.0


## Aplica os multiplicadores da estância no HitData (modifica e devolve o mesmo objeto).
func apply(h: HitData, stance: int) -> HitData:
	if stance <= 0:
		return h
	h.damage = roundi(h.damage * damage[stance])
	h.knockback *= knockback[stance]
	h.poise_mult *= poise[stance]
	h.hitstop *= 1.0 + 0.25 * stance
	if stance >= poise_break_from:
		h.poise_break = true
	if stance >= MAX_STANCE:
		h.launch = maxf(h.launch, max_launch)
		h.hitstun = maxf(h.hitstun, max_hitstun)
	return h


## Estância atingida depois de segurar por `held` segundos.
func stance_at(held: float) -> int:
	var s := 0
	while s < MAX_STANCE and held >= times[s]:
		s += 1
	return s


## Jogador com essa estância de armadura resiste a poise_break recebido?
func resists_break(armor_level: int) -> bool:
	return armor_level >= poise_break_from


func is_unshakable(armor_level: int) -> bool:
	return armor_level >= MAX_STANCE
