#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
temp=$(mktemp -d "${TMPDIR:-/tmp}/azithro-envrc-test.XXXXXX")
trap 'rm -rf -- "$temp"' EXIT
checkout="$temp/checkout"
mkdir -p "$checkout"
expected_checkout=$(cd -- "$checkout" && pwd -P)

fail() {
  printf 'tests/envrc.sh: %s\n' "$*" >&2
  exit 1
}

assert_link() {
  local path=$1 expected=$2
  [[ -L "$path" ]] || fail "expected symlink at $path"
  [[ $(readlink "$path") == "$expected" ]] || fail "unexpected symlink target at $path"
}

assert_warning() {
  local file=$1 path=$2
  grep -F "leaving existing config path untouched: $path" "$file" >/dev/null \
    || fail "expected untouched-path warning for $path"
}

# direnv provides PATH_add; use a disposable executable instead of inspecting
# the host's Nix profile in these portable, offline tests.
PATH_add() { export PATH="$1:$PATH"; }
mkdir -p "$temp/bin"
printf '#!/usr/bin/env bash\nprintf "unwrapped-fixture\\n"\n' > "$temp/bin/nvim"
chmod +x "$temp/bin/nvim"
export AZITHRO_DEV_NVIM="$temp/bin/nvim"

# XDG_CONFIG_HOME is honored and its missing parent hierarchy is created.
(
  export HOME="$temp/home"
  export XDG_CONFIG_HOME="$temp/custom/deep/config"
  cd "$checkout"
  export AZITHRO_TOOL_PROVIDER=nix
  export AZITHRO_PACK_LOCK=/tmp/hm-lock
  export AZITHRO_JS_DEBUG_COMMAND=/tmp/hm-js-debug
  export AZITHRO_JS_DEBUG_SERVER=/tmp/hm-js-server
  export AZITHRO_CODELLDB_COMMAND=/tmp/hm-codelldb
  export AZITHRO_LIBLLDB_PATH=/tmp/hm-liblldb
  source "$repo/.envrc" 2>"$temp/create.stderr"
  [[ $NVIM_APPNAME == azithro ]] || fail "NVIM_APPNAME was not set"
  [[ $AZITHRO_TOOL_PROVIDER == mason ]] || fail "development must use Mason"
  [[ $(nvim) == unwrapped-fixture ]] || fail "development executable not on PATH"
  for name in AZITHRO_PACK_LOCK AZITHRO_JS_DEBUG_COMMAND AZITHRO_JS_DEBUG_SERVER AZITHRO_CODELLDB_COMMAND AZITHRO_LIBLLDB_PATH; do
    if printenv "$name" >/dev/null; then
      fail "$name leaked into development environment"
    fi
  done
  [[ -d "$XDG_CONFIG_HOME" ]] || fail "XDG config parent hierarchy was not created"
  assert_link "$XDG_CONFIG_HOME/azithro" "$expected_checkout"
  [[ ! -s "$temp/create.stderr" ]] || fail "new config link unexpectedly emitted a warning"
)

# Sourcing repeatedly leaves a development link to this checkout alone.
(
  export HOME="$temp/home"
  export XDG_CONFIG_HOME="$temp/custom/deep/config"
  cd "$checkout"
  source "$repo/.envrc" 2>"$temp/correct-link.stderr"
  assert_link "$XDG_CONFIG_HOME/azithro" "$expected_checkout"
  [[ ! -s "$temp/correct-link.stderr" ]] || fail "correct existing link emitted a warning"
)

# Without XDG_CONFIG_HOME the disposable HOME/.config location is used.
(
  export HOME="$temp/home-default"
  unset XDG_CONFIG_HOME
  cd "$checkout"
  source "$repo/.envrc" 2>"$temp/home-default.stderr"
  assert_link "$HOME/.config/azithro" "$expected_checkout"
  [[ ! -s "$temp/home-default.stderr" ]] || fail "default config link emitted a warning"
)

# Existing directories and files must not be replaced.
(
  export HOME="$temp/home"
  export XDG_CONFIG_HOME="$temp/existing-directory-config"
  mkdir -p "$XDG_CONFIG_HOME/azithro"
  printf 'keep directory contents\n' > "$XDG_CONFIG_HOME/azithro/sentinel"
  cd "$checkout"
  source "$repo/.envrc" 2>"$temp/directory.stderr"
  [[ -d "$XDG_CONFIG_HOME/azithro" && ! -L "$XDG_CONFIG_HOME/azithro" ]] \
    || fail "existing directory was replaced"
  [[ $(<"$XDG_CONFIG_HOME/azithro/sentinel") == 'keep directory contents' ]] \
    || fail "existing directory contents changed"
  assert_warning "$temp/directory.stderr" "$XDG_CONFIG_HOME/azithro"
)

(
  export HOME="$temp/home"
  export XDG_CONFIG_HOME="$temp/existing-file-config"
  mkdir -p "$XDG_CONFIG_HOME"
  printf 'keep file contents\n' > "$XDG_CONFIG_HOME/azithro"
  cd "$checkout"
  source "$repo/.envrc" 2>"$temp/file.stderr"
  [[ -f "$XDG_CONFIG_HOME/azithro" && ! -L "$XDG_CONFIG_HOME/azithro" ]] \
    || fail "existing file was replaced"
  [[ $(<"$XDG_CONFIG_HOME/azithro") == 'keep file contents' ]] || fail "existing file contents changed"
  assert_warning "$temp/file.stderr" "$XDG_CONFIG_HOME/azithro"
)

# A dangling symlink also counts as an existing path and must remain untouched.
(
  export HOME="$temp/home"
  export XDG_CONFIG_HOME="$temp/dangling-config"
  mkdir -p "$XDG_CONFIG_HOME"
  ln -s "$temp/missing-target" "$XDG_CONFIG_HOME/azithro"
  cd "$checkout"
  source "$repo/.envrc" 2>"$temp/dangling.stderr"
  [[ -L "$XDG_CONFIG_HOME/azithro" ]] || fail "dangling symlink was replaced"
  [[ $(readlink "$XDG_CONFIG_HOME/azithro") == "$temp/missing-target" ]] \
    || fail "dangling symlink target changed"
  assert_warning "$temp/dangling.stderr" "$XDG_CONFIG_HOME/azithro"
)

# Missing overrides must fail rather than silently falling back to HM's wrapper.
(
  export AZITHRO_DEV_NVIM="$temp/missing-nvim"
  if source "$repo/.envrc" 2>"$temp/missing.stderr"; then
    fail "missing executable was accepted"
  fi
  grep -F 'set AZITHRO_DEV_NVIM' "$temp/missing.stderr" >/dev/null \
    || fail "missing executable did not explain the override"
)

printf 'tests/envrc.sh: all tests passed\n'
