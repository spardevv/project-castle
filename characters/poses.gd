class_name Poses
extends RefCounted
## Biblioteca de poses do HumanoidRig. Uma pose é um Dictionary junta -> Vector3 (graus; "root" em metros).
##
## Convenções (personagem olhando para +Z; direita do personagem = -X, esquerda = +X):
##  - Membros pendurados (braços/pernas): rotação X NEGATIVA = balançar para frente.
##  - Tronco/cabeça (apontam para cima):  rotação X POSITIVA = inclinar para frente.
##  - Tronco: Z positivo inclina para a direita do personagem (-X).
##  - Yaw (Y) positivo vira para a esquerda do personagem.
##  - Braço esquerdo: Z positivo abre para fora. Braço direito (espada): Z negativo abre para fora.
##  - Ordem de rotação do Godot é YXZ: Z (abrir) -> X (levantar) -> Y (varrer horizontalmente).
##  - Pulso "wr_r": 0 = lâmina na linha do antebraço; X negativo = lâmina "engatilhada" para cima.
##  - "yaw"/"pitch" giram o corpo todo (x = graus) — usados em giro e quedas.
##
## Golpes têm 3 chaves: "windup" (preparação), "strike" (impacto) e "follow" (continuação).
## Na fase ativa as juntas se movem em cascata (quadril -> tronco -> ombro -> cotovelo -> pulso),
## o que dá o efeito de chicote. Use tools/pose_sheet.tscn para ver as poses renderizadas.

const JOINTS: Array[String] = [
	"root", "yaw", "pitch", "hips", "spine", "head",
	"sh_l", "el_l", "sh_r", "el_r", "wr_r", "th_l", "kn_l", "th_r", "kn_r",
]

## Atraso de cada junta na fase ativa (fração do tempo ativo). Quadril lidera, pulso fecha.
const LAG := {
	"root": 0.0, "yaw": 0.0, "pitch": 0.0, "hips": 0.0, "th_l": 0.0, "kn_l": 0.0, "th_r": 0.0, "kn_r": 0.0,
	"spine": 0.1, "head": 0.12, "sh_l": 0.12, "el_l": 0.16, "sh_r": 0.18, "el_r": 0.26, "wr_r": 0.34,
}

## Peso de cada golpe (0 = leve e seco, 1 = muito pesado): controla antecipação, aceleração do
## golpe e o quanto o corpo afunda depois do impacto.
const WEIGHT := {
	"a1": 0.2, "a2": 0.2, "a3": 0.6, "spin": 0.4, "overhead": 1.0, "stinger": 0.5, "rising": 0.6,
	"air1": 0.1, "air2": 0.1, "plunge": 0.8, "grab": 0.5, "e_swing": 0.5, "e_smash": 1.0,
	"art_dash": 0.4, "art_finish": 0.9, "bash": 0.6, "cast": 0.2, "e_draw": 0.0,
	"punch_r": 0.5, "punch_l": 0.5, "rock_throw": 0.7, "taunt": 0.6, "priest_cast": 0.1,
}

## Guarda de espada: peso nas pernas, espada à frente na diagonal.
const READY := {
	"root": Vector3(0, -0.06, 0), "yaw": Vector3.ZERO, "pitch": Vector3.ZERO,
	"hips": Vector3(0, -18, 0), "spine": Vector3(6, 14, 0), "head": Vector3(0, 4, 0),
	"sh_l": Vector3(-20, 0, 14), "el_l": Vector3(-50, 0, 0),
	"sh_r": Vector3(-30, -10, -12), "el_r": Vector3(-55, 0, 0), "wr_r": Vector3(-45, 0, 0),
	"th_l": Vector3(-16, 0, 4), "kn_l": Vector3(16, 0, 0),
	"th_r": Vector3(14, 0, -4), "kn_r": Vector3(22, 0, 0),
}

const ATTACKS := {
	# Corte horizontal direita -> esquerda.
	"a1": {
		"windup": {
			"root": Vector3(0, -0.1, -0.06), "hips": Vector3(0, -40, 0), "spine": Vector3(8, -28, 0),
			"head": Vector3(0, 24, 0), "sh_r": Vector3(-80, -95, -5), "el_r": Vector3(-35, 0, 0), "wr_r": Vector3(-70, 0, 0),
			"sh_l": Vector3(-35, 0, 35), "el_l": Vector3(-45, 0, 0),
			"th_l": Vector3(-22, 0, 4), "kn_l": Vector3(16, 0, 0), "th_r": Vector3(16, 0, -4), "kn_r": Vector3(26, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.1, 0.14), "hips": Vector3(0, 30, 0), "spine": Vector3(12, 38, 0),
			"head": Vector3(0, -30, 0), "sh_r": Vector3(-95, -50, 0), "el_r": Vector3(-8, 0, 0), "wr_r": Vector3(-12, 0, 0),
			"sh_l": Vector3(10, 0, 55), "el_l": Vector3(-25, 0, 0),
			"th_l": Vector3(-32, 0, 4), "kn_l": Vector3(26, 0, 0), "th_r": Vector3(20, 0, -4), "kn_r": Vector3(16, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.12, 0.16), "hips": Vector3(0, 38, 0), "spine": Vector3(14, 52, 0),
			"head": Vector3(0, -38, 0), "sh_r": Vector3(-82, 5, 0), "el_r": Vector3(-20, 0, 0), "wr_r": Vector3(-5, 0, 0),
			"sh_l": Vector3(20, 0, 60), "el_l": Vector3(-25, 0, 0),
			"th_l": Vector3(-34, 0, 4), "kn_l": Vector3(30, 0, 0), "th_r": Vector3(22, 0, -4), "kn_r": Vector3(16, 0, 0),
		},
	},
	# Golpe de volta esquerda -> direita.
	"a2": {
		"windup": {
			"root": Vector3(0, -0.1, 0.04), "hips": Vector3(0, 36, 0), "spine": Vector3(8, 45, 0),
			"head": Vector3(0, -30, 0), "sh_r": Vector3(-85, 50, 0), "el_r": Vector3(-30, 0, 0), "wr_r": Vector3(-65, 0, 0),
			"sh_l": Vector3(-5, 0, 50), "el_l": Vector3(-35, 0, 0),
			"th_r": Vector3(-18, 0, -4), "kn_r": Vector3(18, 0, 0), "th_l": Vector3(16, 0, 4), "kn_l": Vector3(22, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.1, 0.16), "hips": Vector3(0, -32, 0), "spine": Vector3(12, -40, 0),
			"head": Vector3(0, 28, 0), "sh_r": Vector3(-94, 55, 0), "el_r": Vector3(-6, 0, 0), "wr_r": Vector3(-12, 0, 0),
			"sh_l": Vector3(-35, 0, 40), "el_l": Vector3(-40, 0, 0),
			"th_r": Vector3(-30, 0, -4), "kn_r": Vector3(24, 0, 0), "th_l": Vector3(18, 0, 4), "kn_l": Vector3(18, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.12, 0.18), "hips": Vector3(0, -40, 0), "spine": Vector3(14, -52, 0),
			"head": Vector3(0, 34, 0), "sh_r": Vector3(-82, -5, 0), "el_r": Vector3(-15, 0, 0), "wr_r": Vector3(-5, 0, 0),
			"sh_l": Vector3(-40, 0, 35), "el_l": Vector3(-45, 0, 0),
			"th_r": Vector3(-32, 0, -4), "kn_r": Vector3(28, 0, 0), "th_l": Vector3(20, 0, 4), "kn_l": Vector3(18, 0, 0),
		},
	},
	# Corte diagonal descendente (de cima-direita para baixo-esquerda), avanço com a perna da frente.
	"a3": {
		"windup": {
			"root": Vector3(0, -0.04, -0.1), "hips": Vector3(0, -25, 0), "spine": Vector3(-12, -22, 0),
			"head": Vector3(-6, 15, 0), "sh_r": Vector3(-165, -40, -15), "el_r": Vector3(-40, 0, 0), "wr_r": Vector3(-55, 0, 0),
			"sh_l": Vector3(-70, 0, 30), "el_l": Vector3(-40, 0, 0),
			"th_l": Vector3(-10, 0, 4), "kn_l": Vector3(12, 0, 0), "th_r": Vector3(16, 0, -4), "kn_r": Vector3(28, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.2, 0.24), "hips": Vector3(0, 28, 0), "spine": Vector3(28, 32, 0),
			"head": Vector3(16, -22, 0), "sh_r": Vector3(-80, -30, 0), "el_r": Vector3(-6, 0, 0), "wr_r": Vector3(-10, 0, 0),
			"sh_l": Vector3(-5, 0, 55), "el_l": Vector3(-25, 0, 0),
			"th_l": Vector3(-45, 0, 4), "kn_l": Vector3(40, 0, 0), "th_r": Vector3(28, 0, -4), "kn_r": Vector3(12, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.24, 0.28), "hips": Vector3(0, 34, 0), "spine": Vector3(34, 40, 0),
			"head": Vector3(18, -26, 0), "sh_r": Vector3(-78, 0, 0), "el_r": Vector3(-10, 0, 0), "wr_r": Vector3(-25, 0, 0),
			"sh_l": Vector3(5, 0, 60), "el_l": Vector3(-25, 0, 0),
			"th_l": Vector3(-48, 0, 4), "kn_l": Vector3(46, 0, 0), "th_r": Vector3(30, 0, -4), "kn_r": Vector3(10, 0, 0),
		},
	},
	# Giro de 360 graus com a espada estendida na horizontal.
	"spin": {
		"windup": {
			"root": Vector3(0, -0.14, 0), "hips": Vector3(0, -45, 0), "spine": Vector3(10, -35, 0),
			"sh_r": Vector3(-75, -70, -5), "el_r": Vector3(-15, 0, 0), "wr_r": Vector3(-30, 0, 0), "sh_l": Vector3(-20, 0, 60),
			"th_l": Vector3(-16, 0, 8), "kn_l": Vector3(34, 0, 0), "th_r": Vector3(16, 0, -8), "kn_r": Vector3(38, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.1, 0), "yaw": Vector3(360, 0, 0), "hips": Vector3.ZERO, "spine": Vector3(8, 0, 0),
			"head": Vector3.ZERO, "sh_r": Vector3(-95, -55, 0), "el_r": Vector3.ZERO, "wr_r": Vector3(-5, 0, 0),
			"sh_l": Vector3(-20, 0, 75), "el_l": Vector3(-10, 0, 0),
			"th_l": Vector3(-12, 0, 10), "kn_l": Vector3(22, 0, 0), "th_r": Vector3(12, 0, -10), "kn_r": Vector3(22, 0, 0),
		},
	},
	# Golpe vertical pesado com as duas mãos: espada cai das costas até o chão à frente.
	"overhead": {
		"windup": {
			"root": Vector3(0, -0.02, -0.08), "spine": Vector3(-18, 0, 0), "hips": Vector3(0, -5, 0),
			"head": Vector3(-10, 0, 0), "sh_r": Vector3(-175, 10, -12), "el_r": Vector3(-55, 0, 0), "wr_r": Vector3(-40, 0, 0),
			"sh_l": Vector3(-172, -10, 12), "el_l": Vector3(-55, 0, 0),
			"th_l": Vector3(-14, 0, 4), "kn_l": Vector3(14, 0, 0), "th_r": Vector3(12, 0, -4), "kn_r": Vector3(22, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.26, 0.2), "spine": Vector3(34, 0, 0), "hips": Vector3.ZERO,
			"head": Vector3(20, 0, 0), "sh_r": Vector3(-95, 12, 0), "el_r": Vector3(-8, 0, 0), "wr_r": Vector3(-12, 0, 0),
			"sh_l": Vector3(-92, -14, 0), "el_l": Vector3(-12, 0, 0),
			"th_l": Vector3(-46, 0, 4), "kn_l": Vector3(55, 0, 0), "th_r": Vector3(30, 0, -4), "kn_r": Vector3(38, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.3, 0.22), "spine": Vector3(40, 0, 0), "hips": Vector3.ZERO,
			"head": Vector3(24, 0, 0), "sh_r": Vector3(-85, 12, 0), "el_r": Vector3(-8, 0, 0), "wr_r": Vector3(-5, 0, 0),
			"sh_l": Vector3(-82, -14, 0), "el_l": Vector3(-12, 0, 0),
			"th_l": Vector3(-50, 0, 4), "kn_l": Vector3(62, 0, 0), "th_r": Vector3(32, 0, -4), "kn_r": Vector3(42, 0, 0),
		},
	},
	# Estocada em avanço: espada recolhida na cintura, depois braço e lâmina em linha reta.
	"stinger": {
		"windup": {
			"root": Vector3(0, -0.12, -0.12), "hips": Vector3(0, -35, 0), "spine": Vector3(6, -25, 0),
			"head": Vector3(0, 20, 0), "sh_r": Vector3(25, -10, -15), "el_r": Vector3(-105, 0, 0), "wr_r": Vector3(-8, 0, 0),
			"sh_l": Vector3(-50, 0, 30), "el_l": Vector3(-30, 0, 0),
			"th_l": Vector3(-14, 0, 4), "kn_l": Vector3(20, 0, 0), "th_r": Vector3(30, 0, -4), "kn_r": Vector3(30, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.16, 0.32), "hips": Vector3(0, 20, 0), "spine": Vector3(26, 12, 0),
			"head": Vector3(6, -12, 0), "sh_r": Vector3(-112, -32, 0), "el_r": Vector3.ZERO, "wr_r": Vector3.ZERO,
			"sh_l": Vector3(25, 0, 55), "el_l": Vector3(-15, 0, 0),
			"th_l": Vector3(-52, 0, 4), "kn_l": Vector3(32, 0, 0), "th_r": Vector3(40, 0, -4), "kn_r": Vector3(2, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.17, 0.34), "hips": Vector3(0, 22, 0), "spine": Vector3(28, 14, 0),
			"head": Vector3(6, -14, 0), "sh_r": Vector3(-110, -34, 0), "el_r": Vector3(-4, 0, 0), "wr_r": Vector3(-4, 0, 0),
			"sh_l": Vector3(28, 0, 58), "el_l": Vector3(-15, 0, 0),
			"th_l": Vector3(-54, 0, 4), "kn_l": Vector3(36, 0, 0), "th_r": Vector3(42, 0, -4), "kn_r": Vector3(2, 0, 0),
		},
	},
	# Corte ascendente: agacha com a espada baixa e sobe esticando o corpo.
	"rising": {
		"windup": {
			"root": Vector3(0, -0.34, -0.06), "spine": Vector3(28, -15, 0), "head": Vector3(8, 10, 0), "hips": Vector3(0, -20, 0),
			"sh_r": Vector3(0, -35, -20), "el_r": Vector3(-30, 0, 0), "wr_r": Vector3(-45, 0, 0), "sh_l": Vector3(-25, 0, 40),
			"th_l": Vector3(-40, 0, 6), "kn_l": Vector3(70, 0, 0), "th_r": Vector3(28, 0, -6), "kn_r": Vector3(70, 0, 0),
		},
		"strike": {
			"root": Vector3(0, 0.08, 0.1), "hips": Vector3(0, 25, 0), "spine": Vector3(-10, 25, 0),
			"head": Vector3(-16, -15, 0), "sh_r": Vector3(-155, -20, 0), "el_r": Vector3(-5, 0, 0), "wr_r": Vector3(-10, 0, 0),
			"sh_l": Vector3(30, 0, 60), "th_l": Vector3(-14, 0, 4), "kn_l": Vector3(10, 0, 0),
			"th_r": Vector3(-4, 0, -4), "kn_r": Vector3(20, 0, 0),
		},
		"follow": {
			"root": Vector3(0, 0.1, 0.1), "hips": Vector3(0, 28, 0), "spine": Vector3(-14, 28, 0),
			"head": Vector3(-20, -15, 0), "sh_r": Vector3(-170, -15, 0), "el_r": Vector3(-10, 0, 0), "wr_r": Vector3(-20, 0, 0),
			"sh_l": Vector3(30, 0, 65), "th_l": Vector3(-20, 0, 4), "kn_l": Vector3(30, 0, 0),
			"th_r": Vector3(-8, 0, -4), "kn_r": Vector3(40, 0, 0),
		},
	},
	# Cortes no ar, com pernas recolhidas.
	"air1": {
		"windup": {
			"hips": Vector3(0, -35, 0), "spine": Vector3(6, -25, 0), "sh_r": Vector3(-75, -95, 0), "el_r": Vector3(-30, 0, 0),
			"wr_r": Vector3(-65, 0, 0), "sh_l": Vector3(-20, 0, 45), "th_l": Vector3(-50, 0, 6), "kn_l": Vector3(80, 0, 0),
			"th_r": Vector3(-30, 0, -6), "kn_r": Vector3(70, 0, 0),
		},
		"strike": {
			"hips": Vector3(0, 32, 0), "spine": Vector3(10, 35, 0), "sh_r": Vector3(-92, -50, 0), "el_r": Vector3(-6, 0, 0),
			"wr_r": Vector3(-10, 0, 0), "sh_l": Vector3(10, 0, 60), "th_l": Vector3(-50, 0, 6), "kn_l": Vector3(80, 0, 0),
			"th_r": Vector3(-30, 0, -6), "kn_r": Vector3(70, 0, 0),
		},
	},
	"air2": {
		"windup": {
			"hips": Vector3(0, 32, 0), "spine": Vector3(6, 32, 0), "sh_r": Vector3(-85, 60, 0), "el_r": Vector3(-30, 0, 0),
			"wr_r": Vector3(-65, 0, 0), "sh_l": Vector3(-10, 0, 55), "th_l": Vector3(-40, 0, 6), "kn_l": Vector3(70, 0, 0),
			"th_r": Vector3(-45, 0, -6), "kn_r": Vector3(80, 0, 0),
		},
		"strike": {
			"hips": Vector3(0, -35, 0), "spine": Vector3(10, -38, 0), "sh_r": Vector3(-92, 55, 0), "el_r": Vector3(-6, 0, 0),
			"wr_r": Vector3(-10, 0, 0), "sh_l": Vector3(-35, 0, 40), "th_l": Vector3(-40, 0, 6), "kn_l": Vector3(70, 0, 0),
			"th_r": Vector3(-45, 0, -6), "kn_r": Vector3(80, 0, 0),
		},
	},
	# Mergulho: ergue a espada e desce com a lâmina apontada para o chão.
	"plunge": {
		"windup": {
			"spine": Vector3(-10, 0, 0), "head": Vector3(-8, 0, 0), "sh_r": Vector3(-170, 0, -10), "el_r": Vector3(-25, 0, 0),
			"wr_r": Vector3.ZERO, "sh_l": Vector3(-165, 0, 10), "el_l": Vector3(-30, 0, 0),
			"th_l": Vector3(-20, 0, 4), "kn_l": Vector3(50, 0, 0), "th_r": Vector3(-10, 0, -4), "kn_r": Vector3(45, 0, 0),
		},
		"strike": {
			"root": Vector3.ZERO, "spine": Vector3(16, 0, 0), "head": Vector3(22, 0, 0), "hips": Vector3.ZERO,
			"sh_r": Vector3(25, 0, -8), "el_r": Vector3.ZERO, "wr_r": Vector3.ZERO, "sh_l": Vector3(-70, 0, 25), "el_l": Vector3(-35, 0, 0),
			"th_l": Vector3(-10, 0, 4), "kn_l": Vector3(12, 0, 0), "th_r": Vector3(8, 0, -4), "kn_r": Vector3(14, 0, 0),
		},
	},
	# Arte da arma 1/3: investida longa cortando na horizontal.
	"art_dash": {
		"windup": {
			"root": Vector3(0, -0.22, -0.1), "hips": Vector3(0, -40, 0), "spine": Vector3(22, -30, 0), "head": Vector3(-6, 28, 0),
			"sh_r": Vector3(-60, -60, -10), "el_r": Vector3(-20, 0, 0), "wr_r": Vector3(-30, 0, 0),
			"sh_l": Vector3(-40, 0, 40), "el_l": Vector3(-40, 0, 0),
			"th_l": Vector3(-40, 0, 6), "kn_l": Vector3(55, 0, 0), "th_r": Vector3(30, 0, -6), "kn_r": Vector3(40, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.24, 0.3), "hips": Vector3(0, 30, 0), "spine": Vector3(24, 35, 0), "head": Vector3(-8, -30, 0),
			"sh_r": Vector3(-115, -55, 0), "el_r": Vector3(-5, 0, 0), "wr_r": Vector3(-10, 0, 0),
			"sh_l": Vector3(20, 0, 60), "el_l": Vector3(-20, 0, 0),
			"th_l": Vector3(-55, 0, 6), "kn_l": Vector3(40, 0, 0), "th_r": Vector3(45, 0, -6), "kn_r": Vector3(5, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.24, 0.3), "hips": Vector3(0, 38, 0), "spine": Vector3(24, 48, 0), "head": Vector3(-8, -36, 0),
			"sh_r": Vector3(-110, -5, 0), "el_r": Vector3(-10, 0, 0), "wr_r": Vector3(-5, 0, 0),
			"sh_l": Vector3(25, 0, 62), "el_l": Vector3(-20, 0, 0),
			"th_l": Vector3(-55, 0, 6), "kn_l": Vector3(42, 0, 0), "th_r": Vector3(45, 0, -6), "kn_r": Vector3(5, 0, 0),
		},
	},
	# Arte da arma 3/3: agacha fundo e sobe num corte ascendente com as duas mãos.
	"art_finish": {
		"windup": {
			"root": Vector3(0, -0.4, -0.06), "hips": Vector3(0, -30, 0), "spine": Vector3(32, -20, 0), "head": Vector3(10, 18, 0),
			"sh_r": Vector3(-8, -40, -20), "el_r": Vector3(-30, 0, 0), "wr_r": Vector3(-50, 0, 0),
			"sh_l": Vector3(5, -50, 15), "el_l": Vector3(-40, 0, 0),
			"th_l": Vector3(-45, 0, 6), "kn_l": Vector3(80, 0, 0), "th_r": Vector3(30, 0, -6), "kn_r": Vector3(80, 0, 0),
		},
		"strike": {
			"root": Vector3(0, 0.1, 0.15), "hips": Vector3(0, 20, 0), "spine": Vector3(-15, 20, 0), "head": Vector3(-20, -12, 0),
			"sh_r": Vector3(-165, -15, 0), "el_r": Vector3(-5, 0, 0), "wr_r": Vector3(-15, 0, 0),
			"sh_l": Vector3(-160, -30, 10), "el_l": Vector3(-10, 0, 0),
			"th_l": Vector3(-20, 0, 4), "kn_l": Vector3(15, 0, 0), "th_r": Vector3(-6, 0, -4), "kn_r": Vector3(25, 0, 0),
		},
		"follow": {
			"root": Vector3(0, 0.12, 0.15), "hips": Vector3(0, 22, 0), "spine": Vector3(-18, 22, 0), "head": Vector3(-24, -12, 0),
			"sh_r": Vector3(-175, -10, 0), "el_r": Vector3(-10, 0, 0), "wr_r": Vector3(-20, 0, 0),
			"sh_l": Vector3(-170, -25, 10), "el_l": Vector3(-15, 0, 0),
			"th_l": Vector3(-22, 0, 4), "kn_l": Vector3(20, 0, 0), "th_r": Vector3(-8, 0, -4), "kn_r": Vector3(30, 0, 0),
		},
	},
	# Investida de escudo: recolhe o escudo junto ao corpo e avança com ele à frente.
	# Também usada pela Investida do summon (ombro à frente).
	"bash": {
		"windup": {
			"root": Vector3(0, -0.16, -0.08), "hips": Vector3(0, -30, 0), "spine": Vector3(12, -25, 0), "head": Vector3(0, 20, 0),
			"sh_l": Vector3(-70, -20, 10), "el_l": Vector3(-90, 0, 0),
			"sh_r": Vector3(5, -20, -20), "el_r": Vector3(-40, 0, 0), "wr_r": Vector3(-30, 0, 0),
			"th_l": Vector3(-24, 0, 6), "kn_l": Vector3(34, 0, 0), "th_r": Vector3(22, 0, -6), "kn_r": Vector3(40, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.18, 0.3), "hips": Vector3(0, 25, 0), "spine": Vector3(26, 18, 0), "head": Vector3(6, -15, 0),
			"sh_l": Vector3(-85, -25, 10), "el_l": Vector3(-65, 0, 0),
			"sh_r": Vector3(15, -15, -25), "el_r": Vector3(-45, 0, 0), "wr_r": Vector3(-30, 0, 0),
			"th_l": Vector3(-50, 0, 6), "kn_l": Vector3(35, 0, 0), "th_r": Vector3(40, 0, -6), "kn_r": Vector3(5, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.18, 0.32), "hips": Vector3(0, 28, 0), "spine": Vector3(28, 20, 0), "head": Vector3(6, -16, 0),
			"sh_l": Vector3(-82, -22, 10), "el_l": Vector3(-70, 0, 0),
			"sh_r": Vector3(15, -15, -25), "el_r": Vector3(-45, 0, 0), "wr_r": Vector3(-30, 0, 0),
			"th_l": Vector3(-52, 0, 6), "kn_l": Vector3(38, 0, 0), "th_r": Vector3(42, 0, -6), "kn_r": Vector3(5, 0, 0),
		},
	},
	# Arqueiro: vira o ombro esquerdo para o alvo, braço do arco estendido, puxa a corda até o queixo e solta.
	"e_draw": {
		"windup": {
			"root": Vector3(0, -0.06, 0), "hips": Vector3(0, -40, 0), "spine": Vector3(2, -35, 0), "head": Vector3(0, 70, 0),
			"sh_l": Vector3(-90, 75, 0), "el_l": Vector3(-3, 0, 0),
			"sh_r": Vector3(-90, 60, 0), "el_r": Vector3(-145, 0, 0), "wr_r": Vector3.ZERO,
			"th_l": Vector3(-14, 0, 10), "kn_l": Vector3(10, 0, 0), "th_r": Vector3(10, 0, -10), "kn_r": Vector3(14, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.06, 0), "hips": Vector3(0, -40, 0), "spine": Vector3(-2, -38, 0), "head": Vector3(0, 70, 0),
			"sh_l": Vector3(-90, 75, 0), "el_l": Vector3(-3, 0, 0),
			"sh_r": Vector3(-75, 105, -25), "el_r": Vector3(-60, 0, 0), "wr_r": Vector3.ZERO,
			"th_l": Vector3(-14, 0, 10), "kn_l": Vector3(10, 0, 0), "th_r": Vector3(10, 0, -10), "kn_r": Vector3(14, 0, 0),
		},
	},
	# Golem: soco direto com o braço direito (punho recolhido junto ao peito, depois estendido).
	"punch_r": {
		"windup": {
			"root": Vector3(0, -0.1, -0.06), "hips": Vector3(0, -35, 0), "spine": Vector3(6, -22, 0), "head": Vector3(0, 20, 0),
			"sh_r": Vector3(25, -20, -20), "el_r": Vector3(-115, 0, 0), "wr_r": Vector3.ZERO,
			"sh_l": Vector3(-70, 0, 20), "el_l": Vector3(-100, 0, 0),
			"th_l": Vector3(-20, 0, 6), "kn_l": Vector3(20, 0, 0), "th_r": Vector3(22, 0, -6), "kn_r": Vector3(28, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.14, 0.3), "hips": Vector3(0, 28, 0), "spine": Vector3(18, 25, 0), "head": Vector3(0, -20, 0),
			"sh_r": Vector3(-92, -5, 0), "el_r": Vector3.ZERO, "wr_r": Vector3.ZERO,
			"sh_l": Vector3(-60, 0, 25), "el_l": Vector3(-110, 0, 0),
			"th_l": Vector3(-45, 0, 6), "kn_l": Vector3(30, 0, 0), "th_r": Vector3(35, 0, -6), "kn_r": Vector3(5, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.15, 0.32), "hips": Vector3(0, 32, 0), "spine": Vector3(20, 28, 0), "head": Vector3(0, -22, 0),
			"sh_r": Vector3(-88, -8, 0), "el_r": Vector3(-6, 0, 0), "wr_r": Vector3.ZERO,
			"sh_l": Vector3(-60, 0, 25), "el_l": Vector3(-110, 0, 0),
			"th_l": Vector3(-46, 0, 6), "kn_l": Vector3(32, 0, 0), "th_r": Vector3(36, 0, -6), "kn_r": Vector3(5, 0, 0),
		},
	},
	# Golem: soco com o braço esquerdo (espelho do anterior).
	"punch_l": {
		"windup": {
			"root": Vector3(0, -0.1, -0.06), "hips": Vector3(0, 35, 0), "spine": Vector3(6, 22, 0), "head": Vector3(0, -20, 0),
			"sh_l": Vector3(25, 20, 20), "el_l": Vector3(-115, 0, 0),
			"sh_r": Vector3(-70, 0, -20), "el_r": Vector3(-100, 0, 0), "wr_r": Vector3.ZERO,
			"th_r": Vector3(-20, 0, -6), "kn_r": Vector3(20, 0, 0), "th_l": Vector3(22, 0, 6), "kn_l": Vector3(28, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.14, 0.3), "hips": Vector3(0, -28, 0), "spine": Vector3(18, -25, 0), "head": Vector3(0, 20, 0),
			"sh_l": Vector3(-92, 5, 0), "el_l": Vector3.ZERO,
			"sh_r": Vector3(-60, 0, -25), "el_r": Vector3(-110, 0, 0), "wr_r": Vector3.ZERO,
			"th_r": Vector3(-45, 0, -6), "kn_r": Vector3(30, 0, 0), "th_l": Vector3(35, 0, 6), "kn_l": Vector3(5, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.15, 0.32), "hips": Vector3(0, -32, 0), "spine": Vector3(20, -28, 0), "head": Vector3(0, 22, 0),
			"sh_l": Vector3(-88, 8, 0), "el_l": Vector3(-6, 0, 0),
			"sh_r": Vector3(-60, 0, -25), "el_r": Vector3(-110, 0, 0), "wr_r": Vector3.ZERO,
			"th_r": Vector3(-46, 0, -6), "kn_r": Vector3(32, 0, 0), "th_l": Vector3(36, 0, 6), "kn_l": Vector3(5, 0, 0),
		},
	},
	# Golem: ergue a pedra com as duas mãos e a arremessa para frente.
	"rock_throw": {
		"windup": {
			"root": Vector3(0, -0.04, -0.08), "spine": Vector3(-20, 0, 0), "head": Vector3(-12, 0, 0), "hips": Vector3.ZERO,
			"sh_r": Vector3(-172, 10, -15), "el_r": Vector3(-50, 0, 0), "wr_r": Vector3.ZERO,
			"sh_l": Vector3(-170, -10, 15), "el_l": Vector3(-50, 0, 0),
			"th_l": Vector3(-14, 0, 6), "kn_l": Vector3(14, 0, 0), "th_r": Vector3(12, 0, -6), "kn_r": Vector3(22, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.2, 0.2), "spine": Vector3(30, 0, 0), "head": Vector3(15, 0, 0), "hips": Vector3.ZERO,
			"sh_r": Vector3(-70, 10, -5), "el_r": Vector3(-5, 0, 0), "wr_r": Vector3.ZERO,
			"sh_l": Vector3(-68, -10, 5), "el_l": Vector3(-5, 0, 0),
			"th_l": Vector3(-40, 0, 6), "kn_l": Vector3(45, 0, 0), "th_r": Vector3(28, 0, -6), "kn_r": Vector3(30, 0, 0),
		},
	},
	# Golem: bate no peito e abre os braços rugindo (provocar).
	"taunt": {
		"windup": {
			"root": Vector3(0, -0.12, 0), "spine": Vector3(12, 0, 0), "head": Vector3(8, 0, 0), "hips": Vector3.ZERO,
			"sh_r": Vector3(-60, 35, -10), "el_r": Vector3(-110, 0, 0), "wr_r": Vector3.ZERO,
			"sh_l": Vector3(-60, -35, 10), "el_l": Vector3(-110, 0, 0),
			"th_l": Vector3(-14, 0, 12), "kn_l": Vector3(22, 0, 0), "th_r": Vector3(14, 0, -12), "kn_r": Vector3(22, 0, 0),
		},
		"strike": {
			"root": Vector3(0, 0.0, 0), "spine": Vector3(-22, 0, 0), "head": Vector3(-28, 0, 0), "hips": Vector3.ZERO,
			"sh_r": Vector3(-40, 0, -110), "el_r": Vector3(-10, 0, 0), "wr_r": Vector3.ZERO,
			"sh_l": Vector3(-40, 0, 110), "el_l": Vector3(-10, 0, 0),
			"th_l": Vector3(-10, 0, 18), "kn_l": Vector3(15, 0, 0), "th_r": Vector3(10, 0, -18), "kn_r": Vector3(15, 0, 0),
		},
	},
	# Sacerdote: mãos juntas junto ao peito (prece) e braços abertos para cima soltando a magia.
	"priest_cast": {
		"windup": {
			"root": Vector3(0, -0.08, 0), "spine": Vector3(8, 0, 0), "head": Vector3(10, 0, 0), "hips": Vector3.ZERO,
			"sh_r": Vector3(-55, 30, -10), "el_r": Vector3(-105, 0, 0), "wr_r": Vector3(-20, 0, 0),
			"sh_l": Vector3(-55, -30, 10), "el_l": Vector3(-105, 0, 0),
			"th_l": Vector3(-14, 0, 6), "kn_l": Vector3(18, 0, 0), "th_r": Vector3(14, 0, -6), "kn_r": Vector3(18, 0, 0),
		},
		"strike": {
			"root": Vector3(0, 0.02, 0.04), "spine": Vector3(-10, 0, 0), "head": Vector3(-20, 0, 0), "hips": Vector3.ZERO,
			"sh_r": Vector3(-125, 15, -28), "el_r": Vector3(-15, 0, 0), "wr_r": Vector3(-10, 0, 0),
			"sh_l": Vector3(-125, -15, 28), "el_l": Vector3(-15, 0, 0),
			"th_l": Vector3(-10, 0, 8), "kn_l": Vector3(12, 0, 0), "th_r": Vector3(8, 0, -8), "kn_r": Vector3(12, 0, 0),
		},
	},
	# Conjurar com o orbe (mão esquerda): recolhe o orbe junto ao peito e projeta o braço à frente.
	# A espada fica baixa, recuada ao lado do corpo.
	"cast": {
		"windup": {
			"root": Vector3(0, -0.1, -0.06), "hips": Vector3(0, -25, 0), "spine": Vector3(4, -30, 0), "head": Vector3(0, 28, 0),
			"sh_l": Vector3(-45, -55, 20), "el_l": Vector3(-105, 0, 0),
			"sh_r": Vector3(5, -15, -25), "el_r": Vector3(-45, 0, 0), "wr_r": Vector3(-30, 0, 0),
			"th_l": Vector3(-18, 0, 6), "kn_l": Vector3(22, 0, 0), "th_r": Vector3(16, 0, -6), "kn_r": Vector3(28, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.1, 0.1), "hips": Vector3(0, 15, 0), "spine": Vector3(10, 25, 0), "head": Vector3(0, -22, 0),
			"sh_l": Vector3(-98, -32, 0), "el_l": Vector3(-4, 0, 0),
			"sh_r": Vector3(15, -10, -30), "el_r": Vector3(-50, 0, 0), "wr_r": Vector3(-30, 0, 0),
			"th_l": Vector3(-28, 0, 6), "kn_l": Vector3(26, 0, 0), "th_r": Vector3(20, 0, -6), "kn_r": Vector3(20, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.1, 0.1), "hips": Vector3(0, 18, 0), "spine": Vector3(12, 28, 0), "head": Vector3(0, -24, 0),
			"sh_l": Vector3(-94, -30, 0), "el_l": Vector3(-14, 0, 0),
			"sh_r": Vector3(15, -10, -30), "el_r": Vector3(-50, 0, 0), "wr_r": Vector3(-30, 0, 0),
			"th_l": Vector3(-28, 0, 6), "kn_l": Vector3(28, 0, 0), "th_r": Vector3(20, 0, -6), "kn_r": Vector3(20, 0, 0),
		},
	},
	# Skill do summon: abre os braços e varre tudo para perto.
	"grab": {
		"windup": {
			"spine": Vector3(-12, 0, 0), "hips": Vector3.ZERO, "head": Vector3(-8, 0, 0), "root": Vector3(0, -0.1, -0.06),
			"sh_r": Vector3(-20, -30, -80), "el_r": Vector3(-15, 0, 0), "wr_r": Vector3(-20, 0, 0),
			"sh_l": Vector3(-20, 0, 80), "el_l": Vector3(-15, 0, 0),
			"th_l": Vector3(-16, 0, 10), "kn_l": Vector3(26, 0, 0), "th_r": Vector3(16, 0, -10), "kn_r": Vector3(30, 0, 0),
		},
		"strike": {
			"spine": Vector3(22, 0, 0), "hips": Vector3.ZERO, "head": Vector3(14, 0, 0), "root": Vector3(0, -0.16, 0.14),
			"sh_r": Vector3(-100, 40, -10), "el_r": Vector3(-25, 0, 0), "wr_r": Vector3(-20, 0, 0),
			"sh_l": Vector3(-100, -40, 10), "el_l": Vector3(-25, 0, 0),
			"th_l": Vector3(-34, 0, 6), "kn_l": Vector3(32, 0, 0), "th_r": Vector3(22, 0, -6), "kn_r": Vector3(22, 0, 0),
		},
	},
	# Inimigo: varrida larga e curvada com a clava.
	"e_swing": {
		"windup": {
			"root": Vector3(0, -0.16, -0.06), "hips": Vector3(0, -45, 0), "spine": Vector3(24, -38, 0),
			"head": Vector3(-12, 28, 0), "sh_r": Vector3(-55, -80, -15), "el_r": Vector3(-45, 0, 0), "wr_r": Vector3(-60, 0, 0),
			"sh_l": Vector3(-40, 0, 45), "el_l": Vector3(-50, 0, 0),
			"th_l": Vector3(-24, 0, 10), "kn_l": Vector3(34, 0, 0), "th_r": Vector3(18, 0, -10), "kn_r": Vector3(40, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.16, 0.18), "hips": Vector3(0, 38, 0), "spine": Vector3(26, 42, 0),
			"head": Vector3(-14, -30, 0), "sh_r": Vector3(-105, -60, 0), "el_r": Vector3(-10, 0, 0), "wr_r": Vector3(-10, 0, 0),
			"sh_l": Vector3(15, 0, 65), "el_l": Vector3(-30, 0, 0),
			"th_l": Vector3(-34, 0, 10), "kn_l": Vector3(40, 0, 0), "th_r": Vector3(24, 0, -10), "kn_r": Vector3(30, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.18, 0.2), "hips": Vector3(0, 50, 0), "spine": Vector3(28, 58, 0),
			"head": Vector3(-14, -40, 0), "sh_r": Vector3(-90, -5, 0), "el_r": Vector3(-25, 0, 0), "wr_r": Vector3(0, 0, 0),
			"sh_l": Vector3(25, 0, 70), "el_l": Vector3(-30, 0, 0),
			"th_l": Vector3(-36, 0, 10), "kn_l": Vector3(42, 0, 0), "th_r": Vector3(26, 0, -10), "kn_r": Vector3(30, 0, 0),
		},
	},
	# Inimigo: clava erguida com as duas mãos atrás da cabeça e esmagada no chão.
	"e_smash": {
		"windup": {
			"root": Vector3(0, 0.0, -0.12), "hips": Vector3.ZERO, "spine": Vector3(-24, 0, 0), "head": Vector3(-14, 0, 0),
			"sh_r": Vector3(-170, 15, -15), "el_r": Vector3(-75, 0, 0), "wr_r": Vector3(-45, 0, 0),
			"sh_l": Vector3(-168, -15, 15), "el_l": Vector3(-75, 0, 0),
			"th_l": Vector3(-14, 0, 8), "kn_l": Vector3(10, 0, 0), "th_r": Vector3(14, 0, -8), "kn_r": Vector3(20, 0, 0),
		},
		"strike": {
			"root": Vector3(0, -0.34, 0.24), "hips": Vector3.ZERO, "spine": Vector3(46, 0, 0), "head": Vector3(22, 0, 0),
			"sh_r": Vector3(-105, 15, 0), "el_r": Vector3(-5, 0, 0), "wr_r": Vector3(-5, 0, 0),
			"sh_l": Vector3(-102, -15, 0), "el_l": Vector3(-5, 0, 0),
			"th_l": Vector3(-55, 0, 8), "kn_l": Vector3(70, 0, 0), "th_r": Vector3(34, 0, -8), "kn_r": Vector3(50, 0, 0),
		},
		"follow": {
			"root": Vector3(0, -0.38, 0.26), "hips": Vector3.ZERO, "spine": Vector3(52, 0, 0), "head": Vector3(26, 0, 0),
			"sh_r": Vector3(-95, 15, 0), "el_r": Vector3(-5, 0, 0), "wr_r": Vector3(0, 0, 0),
			"sh_l": Vector3(-92, -15, 0), "el_l": Vector3(-5, 0, 0),
			"th_l": Vector3(-58, 0, 8), "kn_l": Vector3(76, 0, 0), "th_r": Vector3(36, 0, -8), "kn_r": Vector3(54, 0, 0),
		},
	},
}

const AIR_UP := {
	"root": Vector3.ZERO, "hips": Vector3.ZERO, "spine": Vector3(8, 0, 0), "head": Vector3(-6, 0, 0),
	"th_l": Vector3(-40, 0, 4), "kn_l": Vector3(65, 0, 0), "th_r": Vector3(-10, 0, -4), "kn_r": Vector3(40, 0, 0),
	"sh_l": Vector3(-35, 0, 30), "el_l": Vector3(-40, 0, 0), "sh_r": Vector3(-45, -10, -30), "el_r": Vector3(-55, 0, 0),
	"wr_r": Vector3(-30, 0, 0),
}
const AIR_DOWN := {
	"root": Vector3.ZERO, "hips": Vector3.ZERO, "spine": Vector3(-4, 0, 0), "head": Vector3(4, 0, 0),
	"th_l": Vector3(-20, 0, 14), "kn_l": Vector3(24, 0, 0), "th_r": Vector3(10, 0, -14), "kn_r": Vector3(30, 0, 0),
	"sh_l": Vector3(-10, 0, 60), "el_l": Vector3(-20, 0, 0), "sh_r": Vector3(-20, 0, -60), "el_r": Vector3(-25, 0, 0),
	"wr_r": Vector3(-20, 0, 0),
}
const DODGE := {
	"root": Vector3(0, -0.34, 0.1), "spine": Vector3(40, 0, 0), "head": Vector3(14, 0, 0), "hips": Vector3.ZERO,
	"sh_r": Vector3(25, 0, -15), "el_r": Vector3(-40, 0, 0), "wr_r": Vector3(30, 0, 0),
	"sh_l": Vector3(25, 0, 15), "el_l": Vector3(-40, 0, 0),
	"th_l": Vector3(-50, 0, 6), "kn_l": Vector3(80, 0, 0), "th_r": Vector3(32, 0, -6), "kn_r": Vector3(60, 0, 0),
}
## Guarda: espada atravessada à frente do corpo, mão esquerda apoiando a lâmina.
const GUARD := {
	"root": Vector3(0, -0.16, 0), "hips": Vector3(0, -10, 0), "spine": Vector3(8, 10, 0), "head": Vector3(6, 0, 0),
	"sh_r": Vector3(-55, 35, -10), "el_r": Vector3(-75, 0, 0), "wr_r": Vector3(-20, 0, 0),
	"sh_l": Vector3(-70, -30, 10), "el_l": Vector3(-80, 0, 0),
	"th_l": Vector3(-22, 0, 6), "kn_l": Vector3(32, 0, 0), "th_r": Vector3(18, 0, -6), "kn_r": Vector3(38, 0, 0),
}
## Guarda com escudo: antebraço esquerdo erguido com o escudo à frente; espada recuada, pronta.
const GUARD_SHIELD := {
	"root": Vector3(0, -0.18, 0), "hips": Vector3(0, 15, 0), "spine": Vector3(10, 10, 0), "head": Vector3(8, -10, 0),
	"sh_l": Vector3(-75, -15, 10), "el_l": Vector3(-75, 0, 0),
	"sh_r": Vector3(-25, -25, -20), "el_r": Vector3(-60, 0, 0), "wr_r": Vector3(-40, 0, 0),
	"th_l": Vector3(-26, 0, 6), "kn_l": Vector3(34, 0, 0), "th_r": Vector3(20, 0, -6), "kn_r": Vector3(40, 0, 0),
}
## Recuos por direção do empurrão (frente = empurrado para trás, etc.).
const HURT_BACK := {
	"root": Vector3(0, -0.1, -0.14), "hips": Vector3.ZERO, "spine": Vector3(-24, 0, 0), "head": Vector3(-22, 0, 0),
	"sh_r": Vector3(-5, -20, -35), "el_r": Vector3(-30, 0, 0), "wr_r": Vector3(20, 0, 0),
	"sh_l": Vector3(-5, 0, 40), "el_l": Vector3(-35, 0, 0),
	"th_l": Vector3(-20, 0, 4), "kn_l": Vector3(28, 0, 0), "th_r": Vector3(16, 0, -4), "kn_r": Vector3(34, 0, 0),
}
const HURT_FWD := {
	"root": Vector3(0, -0.12, 0.12), "hips": Vector3.ZERO, "spine": Vector3(30, 0, 0), "head": Vector3(20, 0, 0),
	"sh_r": Vector3(30, 0, -25), "el_r": Vector3(-25, 0, 0), "wr_r": Vector3(20, 0, 0),
	"sh_l": Vector3(30, 0, 25), "el_l": Vector3(-25, 0, 0),
	"th_l": Vector3(-10, 0, 4), "kn_l": Vector3(30, 0, 0), "th_r": Vector3(24, 0, -4), "kn_r": Vector3(36, 0, 0),
}
const HURT_TO_RIGHT := { # empurrado para a direita do personagem (-X)
	"root": Vector3(-0.08, -0.1, 0), "hips": Vector3(0, -15, 0), "spine": Vector3(4, -20, 20), "head": Vector3(0, -15, 14),
	"sh_r": Vector3(-10, 0, -50), "el_r": Vector3(-30, 0, 0), "wr_r": Vector3(20, 0, 0),
	"sh_l": Vector3(-30, 0, 20), "el_l": Vector3(-45, 0, 0),
	"th_l": Vector3(-10, 0, 14), "kn_l": Vector3(26, 0, 0), "th_r": Vector3(8, 0, -2), "kn_r": Vector3(30, 0, 0),
}
const HURT_TO_LEFT := { # empurrado para a esquerda do personagem (+X)
	"root": Vector3(0.08, -0.1, 0), "hips": Vector3(0, 15, 0), "spine": Vector3(4, 20, -20), "head": Vector3(0, 15, -14),
	"sh_r": Vector3(-35, 0, -20), "el_r": Vector3(-45, 0, 0), "wr_r": Vector3(20, 0, 0),
	"sh_l": Vector3(-10, 0, 50), "el_l": Vector3(-30, 0, 0),
	"th_l": Vector3(-8, 0, 2), "kn_l": Vector3(30, 0, 0), "th_r": Vector3(10, 0, -14), "kn_r": Vector3(26, 0, 0),
}
## No ar (juggle): corpo largado, inclinado para trás, membros soltos.
const AIR_HURT := {
	"root": Vector3(0, 0.1, 0), "pitch": Vector3(-30, 0, 0), "hips": Vector3.ZERO, "spine": Vector3(-18, 0, 0),
	"head": Vector3(-22, 0, 0), "sh_r": Vector3(-110, 0, -40), "el_r": Vector3(-30, 0, 0), "wr_r": Vector3(10, 0, 0),
	"sh_l": Vector3(-100, 0, 45), "el_l": Vector3(-35, 0, 0),
	"th_l": Vector3(-35, 0, 8), "kn_l": Vector3(55, 0, 0), "th_r": Vector3(-10, 0, -8), "kn_r": Vector3(35, 0, 0),
}
## Deitado de costas (usado com "pitch" -88 no knockdown e na morte).
const DOWN := {
	"root": Vector3.ZERO, "hips": Vector3.ZERO, "spine": Vector3.ZERO, "head": Vector3(-8, 0, 0),
	"sh_r": Vector3(0, 0, -70), "el_r": Vector3(-10, 0, 0), "wr_r": Vector3(20, 0, 0),
	"sh_l": Vector3(0, 0, 70), "el_l": Vector3(-10, 0, 0),
	"th_l": Vector3(0, 0, 12), "kn_l": Vector3(8, 0, 0), "th_r": Vector3(0, 0, -12), "kn_r": Vector3(8, 0, 0),
}
## Ajoelhado, apoiado para se levantar.
const KNEEL := {
	"root": Vector3(0, -0.42, 0), "hips": Vector3.ZERO, "spine": Vector3(28, 0, 0), "head": Vector3(10, 0, 0),
	"sh_r": Vector3(-25, 0, -20), "el_r": Vector3(-30, 0, 0), "wr_r": Vector3(-40, 0, 0),
	"sh_l": Vector3(-35, 0, 20), "el_l": Vector3(-40, 0, 0),
	"th_l": Vector3(-75, 0, 4), "kn_l": Vector3(80, 0, 0), "th_r": Vector3(15, 0, -4), "kn_r": Vector3(105, 0, 0),
}

static var _cache: Dictionary = {}


## READY completado com as juntas da pose parcial.
static func full(partial: Dictionary) -> Dictionary:
	var d: Dictionary = READY.duplicate()
	d.merge(partial, true)
	return d


static func mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out := {}
	for j in JOINTS:
		var va: Vector3 = a.get(j, Vector3.ZERO)
		var vb: Vector3 = b.get(j, Vector3.ZERO)
		out[j] = va.lerp(vb, w)
	return out


## Mistura com atraso por junta (cascata quadril -> pulso) e easing de saída.
## power > 1: começa mais devagar e acelera (sensação de peso sendo vencido).
static func mix_lagged(a: Dictionary, b: Dictionary, u: float, power := 1.0) -> Dictionary:
	var out := {}
	for j in JOINTS:
		var lag: float = LAG.get(j, 0.1)
		var uj := pow(clampf((u - lag) / (1.0 - lag), 0.0, 1.0), power)
		var va: Vector3 = a.get(j, Vector3.ZERO)
		var vb: Vector3 = b.get(j, Vector3.ZERO)
		out[j] = va.lerp(vb, _ease_out(uj))
	return out


static func _cached(key: String, partial: Dictionary) -> Dictionary:
	if not _cache.has(key):
		_cache[key] = full(partial)
	return _cache[key]


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


static func _ease_in_out(u: float) -> float:
	return smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0))


## Amplitude do balanço das pernas (graus) para andar (0) a correr (1).
static func _stride_amp(run: float) -> float:
	return lerpf(34.0, 55.0, run)


## Comprimento de um passo (m, sem escala do rig) que corresponde à amplitude acima: o rig avança a
## fase do ciclo por distância percorrida, então o pé de apoio não desliza.
static func step_length(run: float) -> float:
	return 2.0 * 0.9 * sin(deg_to_rad(_stride_amp(run)))


## Idle, andar, correr, pulo e queda.
static func locomotion(phase: float, speed: float, on_floor: bool, vy: float, time: float) -> Dictionary:
	if not on_floor:
		return _cached("air_up", AIR_UP) if vy > 0.5 else _cached("air_down", AIR_DOWN)
	if speed < 0.4:
		var b := sin(time * 2.2)
		var p: Dictionary = READY.duplicate()
		p["spine"] = Vector3(6.0 + b * 1.5, 14.0, 0.0)
		p["sh_l"] = Vector3(-20.0 + b * 2.0, 0.0, 14.0)
		p["root"] = Vector3(0.0, -0.06 + b * 0.008, 0.0)
		return p
	var run := clampf(inverse_lerp(2.5, 7.0, speed), 0.0, 1.0)
	var s := sin(phase)
	var c := cos(phase)
	var amp := _stride_amp(run)
	var flex := lerpf(30.0, 70.0, run)
	var arm := lerpf(18.0, 45.0, run)
	return {
		"root": Vector3(0, -absf(s) * lerpf(0.03, 0.07, run) - run * 0.04, 0),
		"yaw": Vector3.ZERO, "pitch": Vector3.ZERO,
		"hips": Vector3(0, s * lerpf(5.0, 9.0, run), 0),
		"spine": Vector3(lerpf(4.0, 20.0, run), -s * lerpf(6.0, 12.0, run), 0),
		"head": Vector3(-lerpf(0.0, 10.0, run), 0, 0),
		"th_l": Vector3(-s * amp, 0, 0), "kn_l": Vector3(maxf(c, 0.0) * flex + 6.0, 0, 0),
		"th_r": Vector3(s * amp, 0, 0), "kn_r": Vector3(maxf(-c, 0.0) * flex + 6.0, 0, 0),
		"sh_l": Vector3(s * arm, 0, 10), "el_l": Vector3(-30.0 - run * 40.0, 0, 0),
		# Espada carregada baixa, apontando para trás-baixo ao correr.
		"sh_r": Vector3(-10.0 - s * arm * 0.4, 0, -14), "el_r": Vector3(-35.0 - run * 15.0, 0, 0),
		"wr_r": Vector3(lerpf(10.0, 45.0, run), 0, 0),
	}


## t = tempo desde o início do golpe. Usa os mesmos tempos do AttackData.
static func attack(anim: String, startup: float, active: float, recovery: float, t: float) -> Dictionary:
	var key := "atk_" + anim
	if not _cache.has(key):
		var def: Dictionary = ATTACKS.get(anim, ATTACKS["a1"])
		var strike := full(def["strike"])
		var follow := full(def["follow"]) if def.has("follow") else strike
		_cache[key] = [full(def["windup"]), strike, follow]
	var keys: Array = _cache[key]
	var windup: Dictionary = keys[0]
	var strike: Dictionary = keys[1]
	var follow: Dictionary = keys[2]

	var w: float = WEIGHT.get(anim, 0.3)
	if t < startup: # antecipação: golpes pesados chegam antes à preparação e "seguram" lá
		var u_wind := clampf(t / maxf(startup, 0.001), 0.0, 1.0)
		var f := _ease_in_out(clampf(u_wind * (1.0 + w * 0.8), 0.0, 1.0))
		var pose := mix(READY, windup, f)
		# Pesados: o corpo afunda e se enrola um pouco mais no fim da preparação (carregando força).
		if w > 0.0 and u_wind > 0.5:
			var coil := (u_wind - 0.5) / 0.5 * w
			pose["root"] = (pose["root"] as Vector3) + Vector3(0, -0.03 * coil, -0.02 * coil)
		return pose
	if t < startup + active: # impacto: cascata do quadril ao pulso, acelerando mais nos pesados
		var u_hit := (t - startup) / maxf(active, 0.001)
		return mix_lagged(windup, strike, u_hit, 1.0 + w)
	# recuperação: continua o movimento (follow-through), assenta o peso e volta à guarda
	var u_rec := clampf((t - startup - active) / maxf(recovery, 0.001), 0.0, 1.0)
	var out: Dictionary
	if u_rec < 0.35:
		var k := u_rec / 0.35
		out = mix(strike, follow, _ease_out(k))
		# Afundamento do quadril após o impacto, proporcional ao peso do golpe.
		out["root"] = (out["root"] as Vector3) + Vector3(0, -0.07 * w * sin(k * PI), 0)
	else:
		out = mix(follow, READY, _ease_in_out((u_rec - 0.35) / 0.65))
	out["yaw"] = strike["yaw"] # o giro é normalizado pelo rig ao sair do ataque
	return out


static func dodge(p: float) -> Dictionary:
	var w := smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.72, 1.0, p))
	return mix(READY, _cached("dodge", DODGE), w)


static func guard(time: float, with_shield := false) -> Dictionary:
	var out: Dictionary = (_cached("guard_shield", GUARD_SHIELD) if with_shield else _cached("guard", GUARD)).duplicate()
	out["root"] = Vector3(0, -0.16 + sin(time * 2.5) * 0.006, 0)
	return out


## p: 0..1 do hitstun. push_local: direção do empurrão no espaço do personagem (ZERO = pela frente).
static func hurt(p: float, push_local := Vector3.ZERO) -> Dictionary:
	var d := push_local
	if d.length() < 0.01:
		d = Vector3(0, 0, -1)
	var weights := {
		"back": maxf(-d.z, 0.0), "fwd": maxf(d.z, 0.0),
		"right": maxf(-d.x, 0.0), "left": maxf(d.x, 0.0),
	}
	var total := 0.0
	for k in weights:
		total += weights[k]
	var pose := {}
	for j in JOINTS:
		pose[j] = Vector3.ZERO
	var sources := {
		"back": _cached("hurt_back", HURT_BACK), "fwd": _cached("hurt_fwd", HURT_FWD),
		"right": _cached("hurt_right", HURT_TO_RIGHT), "left": _cached("hurt_left", HURT_TO_LEFT),
	}
	for k in weights:
		var w: float = weights[k] / maxf(total, 0.001)
		if w <= 0.0:
			continue
		var src: Dictionary = sources[k]
		for j in JOINTS:
			pose[j] += (src[j] as Vector3) * w
	# Impacto imediato, segura um pouco e volta à guarda.
	var amount := 1.0 - smoothstep(0.4, 1.0, p)
	return mix(READY, pose, amount)


## Juggle: tomba para trás devagar enquanto está no ar.
static func air_hurt(time: float) -> Dictionary:
	var out: Dictionary = _cached("air_hurt", AIR_HURT).duplicate()
	var sway := sin(time * 6.0)
	out["pitch"] = Vector3(-30.0 - minf(time, 0.8) * 30.0, 0, 0)
	out["sh_l"] = (out["sh_l"] as Vector3) + Vector3(sway * 12.0, 0, 0)
	out["sh_r"] = (out["sh_r"] as Vector3) - Vector3(sway * 12.0, 0, 0)
	out["th_l"] = (out["th_l"] as Vector3) + Vector3(sway * 10.0, 0, 0)
	return out


## Derrubada: cai de costas (0,3 s), fica no chão e levanta nos últimos 0,6 s de `duration`.
static func knockdown(t: float, duration: float) -> Dictionary:
	var down := _cached("down", DOWN)
	var kneel := _cached("kneel", KNEEL)
	var rise_start := maxf(duration - 0.6, 0.35)
	var out: Dictionary
	if t < 0.3:
		var u := t / 0.3
		out = mix(_cached("hurt_back", HURT_BACK), down, _ease_out(u))
		out["pitch"] = Vector3(-88.0 * u * u, 0, 0)
		out["root"] = Vector3(0, 0.14 * u, 0)
	elif t < rise_start:
		out = down.duplicate()
		out["pitch"] = Vector3(-88, 0, 0)
		out["root"] = Vector3(0, 0.14, 0)
	else:
		var u2 := clampf((t - rise_start) / maxf(duration - rise_start, 0.01), 0.0, 1.0)
		if u2 < 0.5:
			var a := _ease_in_out(u2 / 0.5)
			out = mix(down, kneel, a)
			out["pitch"] = Vector3(lerpf(-88.0, 0.0, a), 0, 0)
			out["root"] = Vector3(0, lerpf(0.14, -0.42, a), 0)
		else:
			out = mix(kneel, READY, _ease_in_out((u2 - 0.5) / 0.5))
			out["pitch"] = Vector3.ZERO
	return out


static func dead(t: float) -> Dictionary:
	var u := clampf(t / 0.55, 0.0, 1.0)
	var out := mix(READY, _cached("down", DOWN), _ease_out(u))
	out["pitch"] = Vector3(-90.0 * u * u, 0, 0)
	out["root"] = Vector3(0, 0.14 * u, 0)
	return out
