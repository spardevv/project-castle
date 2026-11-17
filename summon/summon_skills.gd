class_name SummonSkills
extends RefCounted
## Skills dos summons. Os ids são únicos entre summons; cada summon só oferece as suas no menu.
##  - LIBRARY: comandadas pelo jogador nos 4 slots (LB + X/Y/B/A).
##  - PASSIVES: usadas sozinhas em combate. Golem: por distância/inimigos por perto (min/max/crowd).
##    Sacerdote (prefixo p_): por condição (vida do jogador, buffs ativos, grupo de inimigos...).

const LIBRARY := {
	# --- Golem de Pedra ---
	&"quake": {"name": "Terremoto", "cooldown": 10.0, "desc": "Bate no chão: onda de choque que lança os inimigos em volta."},
	&"taunt": {"name": "Provocar", "cooldown": 8.0, "desc": "Ruge e bate no peito: puxa os inimigos em volta e os obriga a atacá-lo."},
	&"punches": {"name": "Rajada de socos", "cooldown": 7.0, "desc": "Cinco socos seguidos; o último derruba."},
	&"rock": {"name": "Lançar pedra", "cooldown": 6.0, "desc": "Arremessa uma pedra que explode em área ao cair."},
	&"grab": {"name": "Agarrar", "cooldown": 9.0, "desc": "Corre até o inimigo travado no lock-on (ou o mais próximo), o agarra, ergue e esmaga no chão. Brutamontes resistem."},
	# --- Sacerdote ---
	&"heal": {"name": "Cura", "cooldown": 12.0, "desc": "Restaura 35 de vida do jogador."},
	&"ward": {"name": "Proteção", "cooldown": 15.0, "desc": "Buff: o jogador recebe 30% menos dano por 10 s."},
	&"bless": {"name": "Bênção", "cooldown": 18.0, "desc": "Buff: o jogador causa 30% mais dano por 12 s."},
	&"haste": {"name": "Pressa", "cooldown": 16.0, "desc": "Buff: o jogador se move 25% mais rápido por 10 s."},
	&"renew": {"name": "Renovar", "cooldown": 16.0, "desc": "Cura gradual: o jogador regenera 4 de vida por segundo durante 8 s."},
	&"hex": {"name": "Maldição", "cooldown": 14.0, "desc": "Debuff: inimigos em volta recebem 30% mais dano e causam 20% menos por 8 s."},
	&"slow": {"name": "Lentidão", "cooldown": 12.0, "desc": "Debuff: inimigos em volta ficam 50% mais lentos por 6 s."},
	&"smite": {"name": "Julgamento", "cooldown": 9.0, "desc": "Dano: coluna de luz sobre o inimigo travado (ou o mais próximo)."},
	&"nova": {"name": "Nova sagrada", "cooldown": 13.0, "desc": "Dano: explosão de luz em volta do sacerdote que empurra os inimigos."},
}

const GOLEM_CHOICES: Array[StringName] = [&"", &"quake", &"taunt", &"punches", &"grab", &"rock"]
const PRIEST_CHOICES: Array[StringName] = [&"", &"heal", &"renew", &"ward", &"bless", &"haste", &"hex", &"slow", &"smite", &"nova"]

## Golem: min/max = distância ao alvo; crowd = inimigos mínimos num raio de crowd_radius.
## Sacerdote (p_*): sem distância; a condição fica no estado de suporte.
const PASSIVES := {
	&"slam": {"name": "Pisada sísmica", "cooldown": 7.0, "min": 0.0, "max": 2.6, "crowd": 1, "crowd_radius": 3.4,
		"desc": "Pisa forte e abala o chão quando há inimigos colados nele."},
	&"combo": {"name": "Socos", "cooldown": 5.0, "min": 0.0, "max": 2.4, "crowd": 0, "crowd_radius": 0.0,
		"desc": "Três socos seguidos contra um alvo próximo."},
	&"rock": {"name": "Lançar pedra", "cooldown": 7.0, "min": 4.5, "max": 14.0, "crowd": 0, "crowd_radius": 0.0,
		"desc": "Arremessa uma pedra em alvos distantes."},
	&"spin": {"name": "Braços giratórios", "cooldown": 9.0, "min": 0.0, "max": 2.8, "crowd": 2, "crowd_radius": 3.6,
		"desc": "Gira os braços atingindo todos em volta (precisa de 2+ inimigos perto)."},
	&"p_aura": {"name": "Aura de cura", "cooldown": 0.0, "desc": "Passiva constante: enquanto estiver perto, o jogador regenera 2,5 de vida por segundo, sem precisar de comando."},
	&"p_heal": {"name": "Cura divina", "cooldown": 10.0, "desc": "Cura o jogador sozinho (+35) quando a vida cai abaixo de 60%."},
	&"p_renew": {"name": "Renovação", "cooldown": 14.0, "desc": "Aplica cura gradual no jogador quando a vida está abaixo de 85% em combate."},
	&"p_bless": {"name": "Bênção do campo", "cooldown": 25.0, "desc": "Abençoa o jogador no início de cada combate."},
	&"p_ward": {"name": "Escudo de luz", "cooldown": 18.0, "desc": "Protege o jogador em combate quando a vida cai abaixo de 80%."},
	&"p_slow": {"name": "Teia lenta", "cooldown": 14.0, "desc": "Retarda os inimigos quando há 2 ou mais perto do jogador."},
	&"p_smite": {"name": "Centelha", "cooldown": 5.0, "desc": "Solta um raio de luz fraco em inimigos a média distância."},
}

const GOLEM_PASSIVE_CHOICES: Array[StringName] = [&"", &"slam", &"combo", &"rock", &"spin"]
const PRIEST_PASSIVE_CHOICES: Array[StringName] = [&"", &"p_aura", &"p_heal", &"p_renew", &"p_bless", &"p_ward", &"p_slow", &"p_smite"]


static func choices_for(kind: StringName) -> Array[StringName]:
	return PRIEST_CHOICES if kind == &"priest" else GOLEM_CHOICES


static func passive_choices_for(kind: StringName) -> Array[StringName]:
	return PRIEST_PASSIVE_CHOICES if kind == &"priest" else GOLEM_PASSIVE_CHOICES


static func name_of(id: StringName) -> String:
	return LIBRARY[id]["name"] if LIBRARY.has(id) else "—"


static func desc_of(id: StringName) -> String:
	return LIBRARY[id]["desc"] if LIBRARY.has(id) else "Slot vazio."


static func cooldown_of(id: StringName) -> float:
	return float(LIBRARY[id]["cooldown"]) if LIBRARY.has(id) else 0.0


static func passive_name(id: StringName) -> String:
	return PASSIVES[id]["name"] if PASSIVES.has(id) else "—"


static func passive_desc(id: StringName) -> String:
	return PASSIVES[id]["desc"] if PASSIVES.has(id) else "Slot vazio."
