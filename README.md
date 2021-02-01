# `setup-da-distro`

> A framework to manage installation of binary programs from web sources for non-root users on Linux systems

The repo is a fork of https://github.com/pylipp/sdd with a few major changes:

- Simpler project structure. Scripts in the repo are standalone with common helpers
- Support multiple architectures (x86-64, i686, arm, aarch64, or any)
- Extra helpers for fetching versions from GitHub, GitLab, and cgit, and for extracting archives
- Extra apps available

## Motivation

During occasional strolls on reddit or github, my attention is often drawn towards programs that increase productivity or provide an enhancement over others. (As a somewhat irrelevant side note - these programs mostly work in the command line.) Usually these programs are available for download as binary or script, meaning that naturally, the management (installation, upgrade, removal) of those programs has to be performed manually. At this point `sdd` comes into play: It provides a framework to automatize the tasks of managing the programs (or, in `sdd` terminology, 'apps'). The procedures to manage specific apps are defined within scripts in this repository (at `apps/`).

`sdd` enables me to keep track of my favorite programs, on different machines. I'm working towards having systems set up in a reproducible way on my machines. `sdd` helps me, since I might have different Linux distributions installed on these machine, with different package manager providing different versions of required programs (or none at all). I can freeze the versions of all apps managed by sdd with `sdd list --installed > sdd_freeze.txt`, and re-create them with `xargs -a sdd_freeze.txt sdd install`.

## WARNINGS

`sdd` is a simple collection of bash scripts, not a mature package manager (neither do I aim to turn it into one...). Using it might break things on your system (e.g. overwrite existing program files).

When using `sdd`, you execute functionality to manipulate your system. Especially, you download programs from third parties, and install them on your system. Most sources are provided by GitHub releases pages. Keep in mind that repositories can be compromised, and malicious code placed inside; and `sdd` will still happily download it. (If you have an idea how to mitigate this security flaw, please open an issue.)

Installing older versions of available apps is supported but not guaranteed.

## Installation

`sdd` requires a few dependencies:

- `bash`
- `wget`
- `awk` or `mawk` or `busybox`
- `coreutils` or `busybox`

Clone the git repository and let `sdd` install itself:

```sh
git clone https://github.com/SmartFinn/sdd
cd sdd
bash bin/sdd install sdd
```

or install `sdd` without git using the following command:

```sh
wget -qO- https://raw.githubusercontent.com/SmartFinn/sdd/master/bootstrap.sh | sh
```

Please verify that the `$SDD_BIN_DIR` (`$HOME/.local/bin` by default) is present in your `PATH`. You might want to append this to your shell configuration file:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Same applies for the `MANPATH`:

```sh
export MANPATH="$HOME/.local/share/man:$MANPATH"
```

For enabling `zsh` completion functions (`oh-my-zsh` users: put this before the line that sources `oh-my-zsh.sh` since it calls `compinit` for setting up completions):

```sh
fpath=(~/.local/share/zsh/site-functions $fpath)
```

For enabling `bash` completion functions, you should be fine if you already use the [`bash-completion`](https://github.com/scop/bash-completion) package. Otherwise add this snippet to your `~/.bashrc`:

```sh
# source user completion directory definitions
for i in "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"/*; do
    [[ -f $i && -r $i ]] && . "$i"
done
unset i
```

## Usage

### Installing an app

Install an app to `SDD_BIN_DIR` (defaults to `~/.local/bin`) with

    sdd install <app>

You can specify a custom installation prefix like this:

    SDD_BIN_DIR=~/bin sdd install <app>

or by exporting the `SDD_BIN_DIR` environment variable.

By default, `sdd` installs the latest version of the app available. You can specify a version for installation:

    sdd install <app>=<version>

> This command overwrites an existing installation of the app without additional conformation.

> The format of the `<version>` specifier depends on the app that is managed (usually it's the tag of the release on GitHub).

### Upgrading the installed apps

To upgrade the installed apps to the latest version available, run

    sdd upgrade

If you want to upgrade an individual app, run

    sdd install <app>

Internally, `sdd` executes un- and re-installation of the app for upgrading.
The usage of `SDD_BIN_DIR` is the same as for the `install` command.

### Uninstalling an app

To uninstall an app, run

    sdd uninstall <app>

The usage of `SDD_BIN_DIR` is the same as for the `install` command.

### Batch commands

The commands `install` and `uninstall` can take multiple arguments to manage apps, e.g.

    sdd install <app1> <app2>=<version> <app3>

### Listing app management information

List installed apps by running

    sdd list [--installed]

List all apps available for management in `sdd` with

    sdd list --available

List all installed apps that can be upgraded to a more recent version with

    sdd list --upgradable

The `list` command options come in short forms, too: `-i`, `-a`, `-u`

### General help

High-level program output during management is forwarded to the terminal. Output of the `sdd_*` functions of the app management file is in `/tmp/sdd-<command>-<app>.stderr`. For increased verbosity when running `sdd`, set the respective environment variable before invoking the program

    SDD_VERBOSE=1 sdd install <app>

You can always consult

    sdd --help

## Customization

You can both

- define app management files for apps that are not shipped with `sdd`, and
- extend app management files for apps that are shipped with `sdd`.

The procedure in either case is:

1. Create an empty bash file named after the app in `~/.config/sdd/apps` (without `.bash` extension).
1. Add the functions `sdd_install`, `sdd_remove`, and `sdd_version` with respective functionality.
1. You're able to manage the app as described in the 'Usage' section. `sdd` tells you when it found a customization for the app specified on the command line.

## Contributing

You're looking for managing an app but it's not included in `sdd` yet? Here's how contribute an app management script:

1. Fork this repository.
1. In your fork, create a feature branch.
1. Clone existing app management file to `new_name@arch` in `apps`.
1. Update `sdd_version`, `sdd_install`, and `sdd_remove` functions.
1. Add the new files, commit, and push.
1. Open a PR!

## Related projects

Use case | Tool
--- | ---
Managing Python packages (system-wide or user-specific) | pip
Managing Python apps (system-wide or user-specific) | [pipx](https://pipxproject.github.io/pipx/)
Generate packages from Makefile and track installation by package manager | [CheckInstall](https://asic-linux.com.mx/~izto/checkinstall/)
Declarative whole-system configuration; unprivileged package management | [GNU Guix](https://guix.gnu.org/)
Creating packages of various formats | [fpm](https://github.com/jordansissel/fpm)

Note that maintaining packages (deb, rpm, etc.) might still require root privileges, depending on your system.
