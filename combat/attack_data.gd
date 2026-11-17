class_name AttackData
extends Resource
## Descreve um golpe (tempos em segundos). Editável como .tres em data/attacks/<arma>/.

@export var id := ""
@export var display_name := ""
## Chave da animação em characters/poses.gd. Vazio = usa o id.
@export var anim := ""

@export_group("Dano")
@export var damage := 10
@export var knockback := 6.0
@export var hitstun := 0.3
@export var hitstop := 0.06
## Velocidade vertical dada ao alvo (juggle / lançamento).
@export var launch := 0.0
## Ignora a super armor do alvo / multiplica o dano no poise dele (armas pesadas "param" o inimigo).
@export var poise_break := false
@export var poise_mult := 1.0

@export_group("Timing")
@export var startup := 0.1
@export var active := 0.12
@export var recovery := 0.25
## A partir deste tempo o golpe pode ser encadeado (tap/hold) ou cancelado.
@export var cancel_start := 0.22
@export var lunge_speed := 3.0

@export_group("Movimento")
## Velocidade vertical dada ao próprio jogador no início da fase ativa (ex.: corte ascendente).
@export var self_launch := 0.0
## Se > 0, o jogador mergulha nessa velocidade até tocar o chão (golpe de mergulho).
@export var dive_speed := 0.0
## Multiplicador de gravidade enquanto o golpe é feito no ar (<1 = flutuar).
@export var air_gravity := 1.0
## Vira o jogador para o analógico ao iniciar. Falso mantém a direção atual.
@export var turn_to_input := true

@export_group("Hitbox")
## Verdadeiro: acerta onde a lâmina passa (varredura da arma). Falso: usa a caixa abaixo.
@export var use_sweep := true
@export var hitbox_size := Vector3(2.0, 1.5, 1.8)
@export var hitbox_offset := Vector3(0, 1.0, 1.1)


func anim_id() -> String:
	return anim if anim != "" else id


func total_time() -> float:
	return startup + active + recovery


func make_hit_data() -> HitData:
	var hit := HitData.new()
	hit.damage = damage
	hit.knockback = knockback
	hit.hitstun = hitstun
	hit.hitstop = hitstop
	hit.launch = launch
	hit.poise_break = poise_break
	hit.poise_mult = poise_mult
	return hit
