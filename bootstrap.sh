#!/bin/sh
#
# This script is meant for quick & easy install via:
#   wget -qO- https://raw.githubusercontent.com/SmartFinn/sdd/master/bootstrap.sh | sh

set -e

# these variables can be overwritten with env VAR=value
: "${SDD_BIN_DIR:=$HOME/.local/bin}"
: "${SDD_DATA_DIR:=${XDG_DATA_DIR:-$HOME/.local/share}/sdd}"
: "${SDD_BASH_COMPLETION_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions}"
: "${SDD_ZSH_COMPLETION_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions}"
: "${TAG:=master}"

gh_url="https://github.com/SmartFinn/sdd"

# make sure that required commands are available
for cmd in wget bash tar; do
	command -v bash >/dev/null && continue
	echo "!! Error: unable to find '$cmd' command. Please install it first." >&2
	exit 1
done

TEMP_DIR="$(mktemp -d)"

trap cleanup INT TERM EXIT

cleanup() {
	echo "=> Clearing cache ..."
	trap - INT TERM EXIT
	rm -rf "${TEMP_DIR:?}"
}

echo "=> Downloading '$gh_url/archive/$TAG.tar.gz'..."
wget -O "$TEMP_DIR/$TAG.tar.gz" "$gh_url/archive/$TAG.tar.gz"

echo "=> Extract '$TAG.tar.gz' into '$TEMP_DIR'..."
tar -C "$TEMP_DIR" -xzf "$TEMP_DIR/$TAG.tar.gz"

echo "=> Installing..."
cd "$TEMP_DIR/sdd-$TAG" || exit 1
env SDD_BIN_DIR="$SDD_BIN_DIR" \
	SDD_DATA_DIR="$SDD_DATA_DIR" \
	SDD_BASH_COMPLETION_DIR="$SDD_BASH_COMPLETION_DIR" \
	SDD_ZSH_COMPLETION_DIR="$SDD_ZSH_COMPLETION_DIR" \
	bash bin/sdd install sdd

exit 0
