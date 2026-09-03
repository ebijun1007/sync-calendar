#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

fail=0
ok() { printf 'ok   %s\n' "$1"; }
ng() { printf 'FAIL %s\n' "$1"; fail=1; }

check_file() {
  if [ -f "$1" ]; then ok "file: $1"; else ng "file: $1 が存在しない"; fi
}

check_contains() {
  if grep -qF "$2" "$1"; then ok "$1 に「$2」がある"; else ng "$1 に「$2」がない"; fi
}

check_file index.html
check_file privacy/index.html
check_file assets/style.css
check_file CNAME

if [ "$(cat CNAME)" = "calendar-sync.kwie.jp" ]; then
  ok "CNAME=calendar-sync.kwie.jp"
else
  ng "CNAME が calendar-sync.kwie.jp ではない"
fi

check_contains index.html 'Calendar Sync Ebijun'
check_contains index.html 'ダブルブッキング'
check_contains index.html '件名、説明、参加者、会議URL'
check_contains index.html 'href="/privacy/"'

check_contains privacy/index.html 'ダブルブッキング'
check_contains privacy/index.html '件名、説明、参加者、会議URL'
check_contains privacy/index.html 'AWS Secrets Manager'
check_contains privacy/index.html 'Amazon DynamoDB'
check_contains privacy/index.html '第三者への提供'
check_contains privacy/index.html '認可をいつでも取り消せます'
check_contains privacy/index.html 'ebijun1007@gmail.com'
check_contains privacy/index.html '制定日'
check_contains privacy/index.html 'href="/"'

for f in index.html privacy/index.html; do
  for tag in html head body; do
    if grep -qF "<$tag" "$f" && grep -qF "</$tag>" "$f"; then
      ok "$f: <$tag> が開閉している"
    else
      ng "$f: <$tag> の開閉が揃っていない"
    fi
  done
done

for f in index.html privacy/index.html; do
  grep -o 'href="/[^"#]*"' "$f" | sed 's/href="//; s/"$//' | while read -r href; do
    case "$href" in
      */) target=".${href}index.html" ;;
      *) target=".${href}" ;;
    esac
    if [ -f "$target" ]; then
      printf 'ok   %s: link %s -> %s\n' "$f" "$href" "$target"
    else
      printf 'FAIL %s: link %s の参照先 %s が無い\n' "$f" "$href" "$target"
      exit 1
    fi
  done || fail=1
done

secret_hits=$(
  git ls-files -z \
    | tr '\0' '\n' \
    | grep -v '^scripts/verify-static.sh$' \
    | while read -r f; do
        [ -f "$f" ] || continue
        if grep -lEi 'client_secret|private_key|BEGIN [A-Z ]*PRIVATE KEY|refresh_token|access_token|AKIA[0-9A-Z]{16}' "$f" >/dev/null 2>&1; then
          printf '%s\n' "$f"
        fi
      done
)
if [ -n "$secret_hits" ]; then
  ng "secret らしき値を含む追跡ファイル: $secret_hits"
else
  ok "secret らしき値を含む追跡ファイルは無い"
fi

json_hits=$(git ls-files | grep -Ei 'client_secret.*\.json$|credentials\.json$|token\.json$' || true)
if [ -n "$json_hits" ]; then
  ng "OAuth クライアント JSON らしき追跡ファイル: $json_hits"
else
  ok "OAuth クライアント JSON らしき追跡ファイルは無い"
fi

if [ "$fail" -eq 0 ]; then
  printf '\n静的検証: 全項目通過\n'
else
  printf '\n静的検証: 失敗あり\n'
fi
exit "$fail"
