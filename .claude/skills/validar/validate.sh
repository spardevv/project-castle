#!/usr/bin/env bash
# Validação do Project Castle: lint, node_paths em .tscn, carga no editor (headless) e testes GUT.
# Uso (Git Bash, na raiz do projeto):
#   bash .claude/skills/validar/validate.sh [--all] [--probe <nome> [--fixed-fps N] [--quit-after N]]
#   --all            lint/checagem em todos os arquivos (padrão: só os alterados desde o HEAD + não versionados)
#   --probe nome     roda também res://tools/<nome>.tscn headless e mostra o fim do log; falha se a probe
#                    sair com código != 0, tiver linha "FAIL " ou erro de script
#   --fixed-fps N    passa --fixed-fps N para a probe (summon_kit_probe e summon_trial_probe precisam de 60)
#   --quit-after N   limite de quadros da probe (padrão 4500)
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

GODOT="${GODOT_PATH:-/c/Users/gabriel.ramos/Documents/Godot_v4.7.2-stable_win64.exe}"
GDLINT="${APPDATA:-}/Python/Python313/Scripts/gdlint.exe"
OUT="${TMPDIR:-${TEMP:-/tmp}}/castle-validate"
mkdir -p "$OUT"

ALL=0; PROBE=""; FIXED_FPS=""; QUIT_AFTER=4500
while [ $# -gt 0 ]; do
	case "$1" in
		--all) ALL=1 ;;
		--probe) PROBE="$2"; shift ;;
		--fixed-fps) FIXED_FPS="$2"; shift ;;
		--quit-after) QUIT_AFTER="$2"; shift ;;
	esac
	shift
done

if [ "$ALL" = 1 ]; then
	FILES=$(git ls-files '*.gd' '*.tscn' | grep -v '^addons/')
else
	FILES=$( { git diff --name-only HEAD; git ls-files --others --exclude-standard; } | grep -E '\.(gd|tscn)$' | grep -v '^addons/' | sort -u)
fi
GD=$(echo "$FILES" | grep '\.gd$' || true)
TSCN=$(echo "$FILES" | grep '\.tscn$' || true)
FAIL=0

echo "== 1. gdlint ($(echo "$GD" | grep -c . ) arquivos)"
if [ -z "$GD" ]; then echo "   nada a checar"
elif [ ! -x "$GDLINT" ] && ! command -v gdlint >/dev/null; then echo "   gdlint ausente: pip install --user gdtoolkit"
else
	[ -x "$GDLINT" ] || GDLINT=gdlint
	# shellcheck disable=SC2086
	"$GDLINT" $GD 2>&1 | grep -v '^Success' | sed 's/^/   /' || true
fi

echo "== 2. node_paths em .tscn ($(echo "$TSCN" | grep -c .) arquivos)"
if [ -n "$TSCN" ]; then
	# Toda propriedade "x = NodePath(...)" precisa estar em node_paths=PackedStringArray(...) do cabeçalho do nó.
	# shellcheck disable=SC2086
	PYTHONIOENCODING=utf-8 python -I - $TSCN <<'PY' || FAIL=1
import re, sys
bad = 0
for path in sys.argv[1:]:
    header, declared, line_no = None, set(), 0
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.startswith("["):
            header, line_no = line.strip(), n
            m = re.search(r'node_paths=PackedStringArray\(([^)]*)\)', line)
            declared = set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()
            continue
        m = re.match(r'([A-Za-z_][\w/]*)\s*=\s*NodePath\(', line)
        if m and header and header.startswith("[node") and m.group(1) not in declared:
            bad += 1
            print(f"   {path}:{n}: '{m.group(1)}' = NodePath sem node_paths no nó da linha {line_no} (carrega null sem erro)")
if not bad:
    print("   ok")
sys.exit(1 if bad else 0)
PY
else echo "   nada a checar"; fi

echo "== 3. carga no editor (erros de script/cena)"
"$GODOT" --headless --editor --path . --quit-after 300 --log-file "$OUT/editor.log" >/dev/null 2>&1
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/editor.log"; then
	FAIL=1
	grep -nE -A2 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/editor.log" | head -40 | sed 's/^/   /'
else echo "   ok"; fi

echo "== 4. testes GUT"
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit --log-file "$OUT/gut.log" >/dev/null 2>&1
GUT_EXIT=$?
grep -E '^(Tests|Passing Tests|Failing Tests|Pending)' "$OUT/gut.log" | sed 's/^/   /'
if [ "$GUT_EXIT" != 0 ] || grep -q 'Failing Tests' "$OUT/gut.log"; then
	FAIL=1
	grep -nE -B1 -A3 '\[Failed\]' "$OUT/gut.log" | head -40 | sed 's/^/   /'
fi

if [ -n "$PROBE" ]; then
	echo "== 5. probe $PROBE"
	PROBE_ARGS=(--headless)
	[ -n "$FIXED_FPS" ] && PROBE_ARGS+=(--fixed-fps "$FIXED_FPS")
	"$GODOT" "${PROBE_ARGS[@]}" --path . "res://tools/$PROBE.tscn" --quit-after "$QUIT_AFTER" --log-file "$OUT/probe.log" >/dev/null 2>&1
	PROBE_EXIT=$?
	[ "$PROBE_EXIT" != 0 ] && { FAIL=1; echo "   probe saiu com código $PROBE_EXIT"; }
	grep -qE 'SCRIPT ERROR|ERROR:|^ *FAIL ' "$OUT/probe.log" && FAIL=1
	grep -nE 'SCRIPT ERROR|ERROR:|^ *FAIL ' "$OUT/probe.log" | head -20 | sed 's/^/   /'
	tail -40 "$OUT/probe.log" | sed 's/^/   /'
fi

echo "Logs em: $OUT"
[ "$FAIL" = 0 ] && echo "RESULTADO: OK" || echo "RESULTADO: FALHOU"
exit "$FAIL"
