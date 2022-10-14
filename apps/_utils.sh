#!/usr/bin/env bash
# Utility functions for sdd framework

# these variables can be overwritten with env VAR=value
: "${SDD_BIN_DIR:=$HOME/.local/bin}"
: "${SDD_BASH_COMPLETION_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions}"
: "${SDD_ZSH_COMPLETION_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions}"
: "${SDD_MAN_DIR:=${XDG_DATA_HOME:-$HOME/.local/share}/man}"

APP_FILE="$(basename "$0" .sh)"
APP_NAME="${APP_FILE%@*}"
APP_ARCH="${APP_FILE##*@}"

# workaround for busybox mktemp command
SDD_TEMP_DIR="$(mktemp -u | sed "s/tmp\./sdd_${APP_FILE}_/")"
mkdir -p "$SDD_TEMP_DIR"
trap utils:cleanup SIGINT SIGTERM ERR EXIT

utils:cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    rm -rf "$SDD_TEMP_DIR"
}

utils:github_latest_release() {
    # Fetch tag name of latest release on GitHub
    local repo="${1?}"

    # Get tag name from URL redirection to avoid GitHub API limits
    awk -F'[ /]' -v e=1 '/Location:/ {e=0; print $(NF-1);} END {exit(e);}' < <(
        wget -o- --max-redirect 0 "https://github.com/$repo/releases/latest"
    )
}

utils:github_latest_commit_hash() {
    local repo="${1?}"
    local branch="${2:-master}"

    # Get latest commit hash from atom feed to avoid GitHub API limits
    wget -qO- "https://github.com/$repo/commits/$branch.atom" |
        awk -F'[/<>]' '/<id>tag:github.com,2008:Grit::Commit/ {i[n++] = $(NF-3);}
        END {print i[0];}'
}

utils:github_latest_tag() {
    local repo="${1?}"

    # Get latest tag from atom feed to avoid GitHub API limits
    wget -qO- "https://github.com/$repo/tags.atom" |
        awk -F'[/<>]' '/<id>tag:github.com,2008:Repository/ {i[n++] = $(NF-3);}
            END {print i[0];}'
}

utils:github_tags() {
    local repo="${1?}"

    # Get tags from atom feed to avoid GitHub API limits
    wget -qO- "https://github.com/$repo/tags.atom" |
        sed -n 's/[ ]*<id>tag:github.com,2008:Repository\/[0-9]\+\/\(.*\)<\/id>/\1/p'
}

utils:github_releases() {
    local repo="${1?}"

    # Get all releases from atom feed to avoid GitHub API limits
    wget -qO- "https://github.com/$repo/releases.atom" |
        awk -F'[/<>]' '/<id>tag:github.com,2008:Repository/ {print $(NF-3);}'
}

utils:gitlab_latest_tag() {
    local repo="${1?}"
    local gitlab_host="${2:-gitlab.com}"

    # Get latest tag from atom feed to avoid GitLab API limits
    wget -qO- "https://$gitlab_host/$repo/-/tags?format=atom" |
        awk -F'[/<>]' '/\/-\/tags\/.*<\/id>/ {i[n++] = $(NF-3);}
            END {print i[0];}'
}

utils:gitlab_tags() {
    local repo="${1?}"
    local gitlab_host="${2:-gitlab.com}"

    # Get tags from atom feed to avoid GitLab API limits
    wget -qO- "https://$gitlab_host/$repo/-/tags?format=atom" |
        sed -n 's/.*\/-\/tags\/\(.*\)<\/id>/\1/p'
}

utils:cgit_lastest_tag() {
    local cgit_repo_url="${1?}"

    # Get tags from cgit web interface
    wget -qO- "$cgit_repo_url/refs/" |
        awk -F"['=]" '/\/tag\/\?h=/ {i[n++] = $4;} END {print i[0];}'
}

utils:cgit_tags() {
    local cgit_repo_url="${1?}"

    # Get tags from cgit web interface
    wget -qO- "$cgit_repo_url/refs/" |
        sed -n "s/.*\/tag\/?h=\([^']\+\)'>.*/\1/p"
}

utils:gitea_latest_release() {
    local repo="${1?}"
    local gitea_host="${2:-gitea.com}"

    # Get tag name from URL redirection to avoid TOKEN requires
    awk -F'[ /]' -v e=1 '/Location:/ {e=0; print $(NF-1);} END {exit(e);}' < <(
        wget -o- --max-redirect 0 "https://$gitea_host/$repo/releases/latest"
    )
}

utils:gitea_tags() {
    local repo="${1?}"
    local gitea_host="${2:-gitea.com}"

    # Get tags from Gitea web interface to avoid TOKEN requires
    wget -qO- "https://$gitea_host/$repo/tags" |
        sed -n 's%.*/src/tag/\([^"]\+\)"[ >].*%\1%p'
}

utils:gitea_releases() {
    local repo="${1?}"
    local gitea_host="${2:-gitea.com}"

    # Get releases from Gitea web interface to avoid TOKEN requires
    wget -qO- "https://$gitea_host/$repo/tags" |
        sed -n 's%.*/releases/tag/\([^"]\+\)">.*%\1%p'
}

utils:parser() {
    local cmd="${1:-}"

    shift || true

    case "$cmd" in
        install|remove|upgrade|version|info)
            if declare -f app_"$cmd" > /dev/null; then
                app_"$cmd" "$@"
            else
                printf 'error: "%s" is not supported\n' "$cmd" >&2
                exit 2
            fi
            ;;
        *)
            echo -n "usage: $APP_FILE install [version]" >&2
            echo " | remove | version | info" >&2
            exit 2
    esac
}

utils:info() {
    local app_desc="${1:-}"
    local cols="${COLUMNS:-$(tput cols)}"

    printf '%-16s %-10s %s\n' "$APP_NAME" "$APP_ARCH" "$app_desc" |
        cut -c 1-"${cols:-80}"
}

utils:extract() {
    # usage: utils:extract file [extra_opts]
    local archive="$1"
    local -a opts=("${@:2}")

    case "$archive" in
    *.zip)  unzip "${opts[@]}" -d "$SDD_TEMP_DIR" --  "$1" >&2 ;;
    *.tar)  tar "${opts[@]}" -C "$SDD_TEMP_DIR" -xvf  "$1" >&2 ;;
    *.tar.bz2|*.tbz2)
            tar "${opts[@]}" -C "$SDD_TEMP_DIR" -xvjf "$1" >&2 ;;
    *.tar.gz|*.tgz)
            tar "${opts[@]}" -C "$SDD_TEMP_DIR" -xvzf "$1" >&2 ;;
    *.tar.xz|*.txz)
            tar "${opts[@]}" -C "$SDD_TEMP_DIR" -xvJf "$1" >&2 ;;
    *.tar.*)
            tar "${opts[@]}" -C "$SDD_TEMP_DIR" -xvaf "$1" >&2 ;;
    *.xz)   cd "$SDD_TEMP_DIR" && unxz -k          -- "$1" >&2 ;;
    *.gz)   cd "$SDD_TEMP_DIR" && gunzip -k        -- "$1" >&2 ;;
    esac
}
