# Utility functions for sdd framework

FRAMEWORKDIR="$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")"

utils_usage() {
    cat <<END_OF_HELP_TEXT
Usage: sdd [OPTIONS] COMMAND [APP [APP...]]

A framework to manage installation of apps from web sources for non-root users
on Linux systems. For more info visit https://github.com/pylipp/sdd

APP is the name of the application to manage.

Commands:
    install
    upgrade
    uninstall
    list

General options:
    --help          Display help message
    --version       Display version information

Options for list command:
    --installed     List installed apps
    --available     List apps available for installation
    --upgradable    List apps that can be upgraded

END_OF_HELP_TEXT
}

utils_version() {
    if [ ! -e "$SDD_DATA_DIR"/apps/installed ]; then
        printf 'Cannot find %s.\n' "$SDD_DATA_DIR"/apps/installed >&2
        return 1
    fi

    tac "$SDD_DATA_DIR"/apps/installed | awk -F= '/^sddj/ {print $2; exit}'
}

_get_appfilepath() {
    local app_name="$1"

    for dir in "$HOME/.config/sdd/apps" "$FRAMEWORKDIR/../apps/user"; do
        if [ -f "$dir/$app_name" ]; then
            echo "$dir/$app_name"
            return 0
        fi
    done

    return 1
}

_validate_apps() {
    local arg app_name

    for arg in "$@"; do
        # Extract app name from the argument
        app_name="${arg%%=*}"

        # Check whether app available
        if ! _get_appfilepath "$app_name" >/dev/null; then
            printf 'App "%s" could not be found.\n' "$app_name" >&2
            return 1
        fi
    done

    return 0
}

utils_install() {
    local -i return_code=0
    local arg app_name app_version
    local stdoutlog stderrlog

    # Install one or more apps
    if [ -z "$1" ]; then
        printf 'Specify at least one app to install.\n' >&2
        return 1
    fi

    # Abort if one of the specified apps doesn't exist
    _validate_apps "$@" || return 1

    for arg in "$@"; do
        # Extract app name from the argument
        app_name="${arg%%=*}"

        # Extract app version from the argument
        app_version=""
        if [[ $arg == *"="* ]]; then
            app_version="${arg##*=}"
        fi

        stdoutlog="/tmp/sdd-install-$app_name.stdout"
        stderrlog="/tmp/sdd-install-$app_name.stderr"

        # Execute installation; tee stdout/stderr to files, see
        # https://stackoverflow.com/a/53051506
        { _utils_install_one "$app_name" "$app_version" > >(tee "$stdoutlog"); } 2> >(tee "$stderrlog" >&2)
        return_code="$?"

        if [[ $return_code -ne 0 ]]; then
            printf 'Error installing "%s". See above and %s.\n' "$app_name" "$stderrlog" > >(tee -a "$stderrlog" >&2)

            return "$return_code"
        fi
    done

    return 0
}

utils_uninstall() {
    local -i return_code=0
    local arg app_name
    local stdoutlog stderrlog

    # Uninstall one or more apps
    if [ -z "$1" ]; then
        printf 'Specify at least one app to uninstall.\n' >&2
        return 1
    fi

    # Abort if one of the specified apps doesn't exist
    _validate_apps "$@" || return 1

    for arg in "$@"; do
        # Extract app name from the argument
        app_name="${arg%%=*}"

        stdoutlog=/tmp/sdd-uninstall-$app_name.stdout
        stderrlog=/tmp/sdd-uninstall-$app_name.stderr

        # Execute uninstallation; tee stdout/stderr to files, see
        # https://stackoverflow.com/a/53051506
        { _utils_uninstall_one "$app_name" > >(tee "$stdoutlog"); } 2> >(tee "$stderrlog" >&2) || {
            return_code="$?"
            printf 'Error uninstalling "%s". See above and %s.\n' "$app_name" "$stderrlog" > >(tee -a "$stderrlog" >&2)

            return "$return_code"
        }
    done

    return 0
}

_utils_install_one() {
    # The remaining arguments apps to be installed, as passed into utils_install,
    # i.e. possibly with versions specified
    local app_name="$1"
    local app_version="$2"

    if [ -f "$HOME/.config/sdd/apps/$app_name" ]; then
        printf 'Custom installation for "%s" found.\n' "$app_name"
    fi

    if [[ -n $app_version ]]; then
        printf 'Specified version: %s\n' "$app_version"
    else
        # If version not specified, try to read it from the app management files.
        app_version=$(_utils_app_version_from_files "$app_name") || {
            printf 'Latest version available: %s\n' "$app_version"
        }
    fi

    # Cleanup current scope
    unset -f sdd_install 2>/dev/null || true

    # Source app management file
    source "$(_get_appfilepath "$app_name")" || return 1

    sdd_install "$app_version"

    # Remove previous records
    if [ -f "$SDD_DATA_DIR"/apps/installed ]; then
        sed -i "/^$app_name=/d" "$SDD_DATA_DIR"/apps/installed
    fi

    # Record installed app and version (can be empty)
    echo "$app_name=$app_version" >> "$SDD_DATA_DIR"/apps/installed

    printf 'Installed "%s".\n' "$app_name"
    return 0
}

_utils_uninstall_one() {
    local app_name="$1"

    if [ -f "$HOME/.config/sdd/apps/$app_name" ]; then
        printf 'Custom uninstallation for "%s" found.\n' "$app_name"
    fi

    # Cleanup current scope
    unset -f sdd_uninstall 2>/dev/null || true

    # Source app management file
    source "$(_get_appfilepath "$app_name")" || return 1

    sdd_uninstall

    if [ -f "$SDD_DATA_DIR"/apps/installed ]; then
        # Remove app install records
        sed -i "/^$app_name=/d" "$SDD_DATA_DIR"/apps/installed
    fi

    printf 'Uninstalled "%s".\n' "$app_name"
    return 0
}

_utils_upgrade_one() {
    local app_name="$1"
    local app_version="$2"

    _utils_uninstall_one "$app_name"
    _utils_install_one "$app_name" "$app_version"

    printf 'Upgraded "%s".\n' "$app_name"
    return 0
}

utils_upgrade() {
    local -i return_code=0
    local arg app_name app_version
    local stdoutlog stderrlog

    if [ -z "$1" ]; then
        printf 'Specify at least one app to upgrade.\n' >&2
        return 1
    fi

    # Abort if one of the specified apps doesn't exist
    _validate_apps "$@" || return 1

    for arg in "$@"; do
        # Extract app name from the argument
        app_name="${arg%%=*}"

        # Extract app version from the argument
        app_version=""
        if [[ $arg == *"="* ]]; then
            app_version="${arg##*=}"
        fi

        stdoutlog=/tmp/sdd-upgrade-$app_name.stdout
        stderrlog=/tmp/sdd-upgrade-$app_name.stderr

        { _utils_upgrade_one "$app_name" "$app_version" > >(tee "$stdoutlog"); } 2> >(tee "$stderrlog" >&2) || {
            return_code="$?"
            printf 'Error upgrading "%s". See above and %s.\n' "$app_name" "$stderrlog" > >(tee -a "$stderrlog" >&2)

            return "$return_code"
        }
    done

    return 0
}

_utils_app_version_from_files() {
    # Determine relevant version of app from app management files by executing
    # the sdd_fetch_latest_version() functions.
    # The custom definition takes precedence over the built-in one.
    local app_name="$1"

    unset -f sdd_fetch_latest_version 2>/dev/null || true
    source "$(_get_appfilepath "$app_name")"

    sdd_fetch_latest_version 2>/dev/null

    return 0
}

utils_list() {
    local option="$1"

    case "$option" in
        --installed|-i)
            if [ -f "$SDD_DATA_DIR"/apps/installed ]; then
                # List apps installed most recently by filtering unique app names first
                tac "$SDD_DATA_DIR"/apps/installed | sort -t= -k1,1 -u
            fi
            ;;
        --available|-a)
            ls -1 "$FRAMEWORKDIR/../apps/user"
            ;;
        --upgradable|-u)
            local name
            local installed_version
            local newest_version

            utils_list --installed | while IFS='=' read -r name installed_version; do
                newest_version=$(_utils_app_version_from_files "$name")

                if [[ "$installed_version" != "$newest_version" ]]; then
                    printf '%s (%s -> %s)\n' "$name" "$installed_version" "$newest_version"
                fi
            done
            ;;
        *)
            printf 'Unknown option "%s".\n' "$option" >&2
            return 1
            ;;
    esac
}

_tag_name_of_latest_github_release() {
    # Fetch tag name of latest release on GitHub
    local github_user=$1
    local repo_name=$2

    # Get tag name from URL redirection to bypass GitHub API limits
    awk -F'[ /]' -v err=1 '/Location:/ {err=0; print $(NF-1);} END {exit(err);}' < <(
        wget -o- --max-redirect 0 "https://github.com/$github_user/$repo_name/releases/latest"
    )
}

_sha_of_github_master() {
    # Fetch SHA of latest commit on GitHub master branch
    local github_user=$1
    local repo_name=$2
    local branch=${3:-master}

    # Get latest commit hash from atom feed to bypass GitHub API limits
    wget -qO- "https://github.com/$github_user/$repo_name/commits/$branch.atom" |
        awk -F'[/<>]' '/<id>tag:github.com,2008:Grit::Commit/ {i[n++] = $(NF-3);}
        END {print i[0];}'
}

_name_of_latest_github_tag() {
    local github_user=$1
    local repo_name=$2

    # Get latest tag from atom feed to bypass GitHub API limits
    wget -qO- "https://github.com/$github_user/$repo_name/tags.atom" |
        awk -F'[/<>]' '/<id>tag:github.com,2008:Repository/ {i[n++] = $(NF-3);}
            END {print i[0];}'
}
