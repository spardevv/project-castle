class_name HitData
extends Resource
## Dados de um golpe. Uma cópia é criada a cada acerto (source é definido em runtime).

@export var damage := 10
@export var knockback := 6.0
@export var hitstun := 0.3
## Duração do hit-stop local (atacante e vítima congelam; o resto do jogo segue).
@export var hitstop := 0.06
@export var launch := 0.0
## Falso para projéteis: o atacante não deve congelar quando a bola de fogo acerta.
## Também marca o golpe como "à distância": parry nega, mas não faz o atirador cambalear.
@export var freeze_attacker := true
## Ignora a super armor (poise) do alvo — ex.: investida de escudo.
@export var poise_break := false
## Multiplica o dano que o golpe causa no poise do alvo (martelo: 2,5×).
@export var poise_mult := 1.0

var source: Node3D
