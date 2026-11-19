class_name BodyProportions
extends Resource
## Esboço de proporções do corpo (docs/vault/Animação/img/esboco_proporcoes.svg): alturas e comprimentos
## em "cabeças" (altura total ÷ heads). O HumanoidRig monta juntas, comprimentos de braço/perna, IK e
## hitboxes a partir daqui; modelos 3D são medidos e encaixados neste esqueleto.

## Quantas cabeças cabem na altura (8 = heroico).
@export var heads := 8.0
## Altura total no espaço do rig (antes da escala `height` do rig).
@export var total_height := 1.94

@export_group("Alturas (cabeças a partir do chão)")
@export var pelvis := 4.35 # pivô do quadril
@export var spine := 4.85 # lombar
@export var chest := 5.75
@export var shoulder := 6.6
@export var neck := 6.75
@export var head := 7.15 # pivô da cabeça (atlas)
@export var hip_joint := 4.15 # cabeça do fêmur
@export var ankle := 0.3 # tornozelo (altura do chão)

@export_group("Comprimentos (cabeças)")
@export var upper_arm := 1.5
@export var forearm := 1.25
@export var hand := 0.75
@export var thigh := 2.0
@export var shin := 1.85
## Quanto a perna do rig é mais curta que quadril→tornozelo: em pé o joelho fica levemente dobrado
## e o IK tem margem para o passo sem travar a perna reta.
@export var knee_slack := 0.05

@export_group("Larguras (cabeças do centro)")
@export var shoulder_half := 0.95
@export var clavicle_half := 0.25
@export var hip_joint_half := 0.45


## 1 cabeça no espaço do rig.
func unit() -> float:
	return total_height / heads


## Converte cabeças para o espaço do rig.
func u(v: float) -> float:
	return v * unit()


static func male() -> BodyProportions:
	return BodyProportions.new()


static func female() -> BodyProportions:
	var p := BodyProportions.new()
	p.shoulder_half = 0.78
	p.hip_joint_half = 0.42
	return p
