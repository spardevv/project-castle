class_name SummonSkills
extends RefCounted
## Skills dos summons. Os ids são únicos entre summons; cada summon só oferece as suas no menu.
##  - LIBRARY: comandadas pelo jogador nos slots (LB + X/Y/B/A).
##  - PASSIVES: usadas sozinhas em combate. Golem: por distância/inimigos por perto (min/max/crowd).
##    Sacerdote (prefixo p_): por condição (vida do jogador, buffs ativos, grupo de inimigos...).
##
## No início cada summon tem UMA skill ativa (GOLEM/PRIEST/MAGE_CHOICES), ataques básicos, a skill de
## chegada (arrive.gd) e UMA passiva. As demais entradas das tabelas ficam guardadas para serem
## liberadas depois: basta incluí-las nas listas *_CHOICES.

## Intervalo da benção passiva do sacerdote (s).
const BLESSING_COOLDOWN := 35.0

const LIBRARY := {
	# --- Golem de Pedra ---
	&"quake": {"name": "Terremoto", "cooldown": 10.0, "desc": "Bate no chão: onda de choque que lança os inimigos em volta."},
	&"taunt": {"name": "Provocar", "cooldown": 8.0, "desc": "Ruge e bate no peito: puxa os inimigos em volta e os obriga a atacá-lo."},
	&"punches": {"name": "Rajada de socos", "cooldown": 7.0, "desc": "Cinco socos seguidos; o último derruba."},
	&"rock": {"name": "Lançar pedra", "cooldown": 6.0, "desc": "Arremessa uma pedra que explode em área ao cair."},
	&"grab": {"name": "Agarrar", "cooldown": 14.0, "desc": "Agarra pelo pescoço o inimigo travado (ou o mais próximo) por 4 s, causando dano baixo por segundo; seus golpes não o soltam. Perto de uma porta pesada e sem inimigos por perto, o golem a abre."},
	# --- Sacerdote ---
	&"heal": {"name": "Cura", "cooldown": 1.2, "desc": "Restaura 10% da vida máxima do jogador. Recarga de 1,2 s."},
	&"ward": {"name": "Proteção", "cooldown": 15.0, "desc": "Buff: o jogador recebe 30% menos dano por 10 s."},
	&"bless": {"name": "Bênção", "cooldown": 18.0, "desc": "Buff: o jogador causa 30% mais dano por 12 s."},
	&"haste": {"name": "Pressa", "cooldown": 16.0, "desc": "Buff: o jogador se move 25% mais rápido por 10 s."},
	&"renew": {"name": "Renovar", "cooldown": 16.0, "desc": "Cura gradual: o jogador regenera 4 de vida por segundo durante 8 s."},
	&"hex": {"name": "Maldição", "cooldown": 14.0, "desc": "Debuff: inimigos em volta recebem 30% mais dano e causam 20% menos por 8 s."},
	&"slow": {"name": "Lentidão", "cooldown": 12.0, "desc": "Debuff: inimigos em volta ficam 50% mais lentos por 6 s."},
	&"smite": {"name": "Julgamento", "cooldown": 9.0, "desc": "Dano: coluna de luz sobre o inimigo travado (ou o mais próximo)."},
	&"nova": {"name": "Nova sagrada", "cooldown": 13.0, "desc": "Dano: explosão de luz em volta do sacerdote que empurra os inimigos."},
	# --- Mago ---
	&"banish": {"name": "Banimento", "cooldown": 30.0, "desc": "Bane o alvo (travado ou mais próximo) para um plano alternativo por 20 s: ele não interage com nada, atravessa paredes e vira névoa verde. Cancela a ação do inimigo; criaturas grandes ficam atordoadas por metade do tempo. Recarga de 30 s só depois que o banimento acaba. Sem inimigos por perto, bane o jogador (sem recarga; aperte de novo para sair), para acessar locais secretos."},
	&"blast": {"name": "Explosão arcana", "cooldown": 5.0, "desc": "Lança uma bola de fogo no inimigo travado (ou no mais próximo) que explode em área."},
	&"frostnova": {"name": "Nova gélida", "cooldown": 11.0, "desc": "Onda de gelo em volta do mago: dano em área e lentidão nos inimigos próximos."},
	&"storm": {"name": "Tempestade", "cooldown": 13.0, "desc": "Chama vários raios sobre os inimigos num raio de 11 m; cada um explode em área."},
	&"meteor": {"name": "Chuva de meteoros", "cooldown": 20.0, "desc": "Marca o chão e faz três meteoros caírem sobre os inimigos: dano pesado em área, com atraso."},
}

## Skills ativas oferecidas no menu (por enquanto só uma por summon; o resto da LIBRARY será liberado depois).
const GOLEM_CHOICES: Array[StringName] = [&"grab"]
const MAGE_CHOICES: Array[StringName] = [&"banish"]
const PRIEST_CHOICES: Array[StringName] = [&"heal"]

## Golem: min/max = distância ao alvo; crowd = inimigos mínimos num raio de crowd_radius.
## Sacerdote (p_*): sem distância; a condição fica no estado de suporte.
const PASSIVES := {
	&"slam": {"name": "Pisada sísmica", "cooldown": 7.0, "min": 0.0, "max": 2.6, "crowd": 1, "crowd_radius": 3.4,
		"desc": "Pisa forte e abala o chão quando há inimigos colados nele."},
	&"combo": {"name": "Socos", "cooldown": 5.0, "min": 0.0, "max": 2.4, "crowd": 0, "crowd_radius": 0.0,
		"desc": "Três socos seguidos contra um alvo próximo."},
	&"rock": {"name": "Lançar pedra", "cooldown": 10.0, "min": 4.5, "max": 16.0, "crowd": 0, "crowd_radius": 0.0,
		"desc": "Arremessa uma pedra (dano moderado + stun de 2 s). Prioriza inimigos aéreos e a longa distância."},
	&"spin": {"name": "Braços giratórios", "cooldown": 9.0, "min": 0.0, "max": 2.8, "crowd": 2, "crowd_radius": 3.6,
		"desc": "Gira os braços atingindo todos em volta (precisa de 2+ inimigos perto)."},
	&"p_aura": {"name": "Aura de cura", "cooldown": 0.0, "desc": "Passiva constante: enquanto estiver perto, o jogador regenera 2,5 de vida por segundo, sem precisar de comando."},
	&"p_heal": {"name": "Cura divina", "cooldown": 10.0, "desc": "Cura o jogador sozinho (+35) quando a vida cai abaixo de 60%."},
	&"p_renew": {"name": "Renovação", "cooldown": 14.0, "desc": "Aplica cura gradual no jogador quando a vida está abaixo de 85% em combate."},
	&"p_bless": {"name": "Bênção do campo", "cooldown": 25.0, "desc": "Abençoa o jogador no início de cada combate."},
	&"p_ward": {"name": "Escudo de luz", "cooldown": 18.0, "desc": "Protege o jogador em combate quando a vida cai abaixo de 80%."},
	&"p_slow": {"name": "Teia lenta", "cooldown": 14.0, "desc": "Retarda os inimigos quando há 2 ou mais perto do jogador."},
	&"m_bolt": {"name": "Orbe arcano", "cooldown": 3.2, "desc": "Lança bolas de fogo explosivas nos inimigos a média distância, sozinho."},
	&"m_frost": {"name": "Geada", "cooldown": 9.0, "desc": "Congela o entorno (dano + lentidão) quando 2 ou mais inimigos chegam perto do mago."},
	&"m_meteor": {"name": "Chuva ardente", "cooldown": 22.0, "desc": "Chama meteoros quando 3 ou mais inimigos se juntam perto do jogador."},
	&"m_storm": {"name": "Tempestade elétrica", "cooldown": 16.0, "desc": "Chama raios quando há 2 ou mais inimigos num raio de 11 m."},
	&"p_blessing": {"name": "Benção", "cooldown": BLESSING_COOLDOWN, "desc": "Abençoa o jogador em combate: +25% de dano e +25% de armadura por 5 s. Também permite que o sacerdote abra baús encantados (botão de interação)."},
	&"m_orbs": {"name": "Orbes arcanas", "cooldown": 40.0, "desc": "Conjura 4 orbes arcanas que rodeiam o mago e voam contra o inimigo mais próximo que entrar num raio de 10 m."},
	&"p_smite": {"name": "Centelha", "cooldown": 5.0, "desc": "Solta um raio de luz fraco em inimigos a média distância."},
}

const GOLEM_PASSIVE_CHOICES: Array[StringName] = [&"rock"]
const MAGE_PASSIVE_CHOICES: Array[StringName] = [&"m_orbs"]
const PRIEST_PASSIVE_CHOICES: Array[StringName] = [&"p_blessing"]


static func choices_for(kind: StringName) -> Array[StringName]:
	if kind == &"mage":
		return MAGE_CHOICES
	return PRIEST_CHOICES if kind == &"priest" else GOLEM_CHOICES


static func passive_choices_for(kind: StringName) -> Array[StringName]:
	if kind == &"mage":
		return MAGE_PASSIVE_CHOICES
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
