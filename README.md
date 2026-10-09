# DSam

> DevSSH + Samane(سامانه, The Persian word for `System`). Pronounced: "D'Sum".

A declarative, reproducible definition and implementation of my personal system standard.

## DSam Principles

1. **Minimalism**
   No unnecessary packages, services, or components shall be installed. Each component must have a clear purpose, and unnecessary functional overlap should be avoided.

2. **Freedom & Purpose**
   Free software should be preferred wherever practical. Proprietary software is permitted when justified, but is generally disfavored. Every installed component and tracked file should have a known purpose.

3. **Isolation**
   Bloat-heavy or potentially intrusive applications, particularly browsers, should be sandboxed and their persistent state explicitly controlled.

4. **Reproducibility**
   The complete system should be reproducible from a fresh installation using DSam, without undocumented manual configuration or accumulated system state.

5. **Deliberate Technology Choices**
   Components should be selected deliberately according to DSam's requirements rather than convention or popularity. Native/compiled software is preferred for applications; interpreted languages are primarily reserved for scripting.

## Design Choices

| Component               | Choice                  | Rationale                                                                                                      |
| ----------------------- | ----------------------- | -------------------------------------------------------------------------------------------------------------- |
| Base System             | Arch Linux              | Minimal base; supports both binary packages and compiling from source.                                         |
| Bootloader              | systemd-boot            | Ships with systemd, UEFI-native and configured by two small files; no config generation step.                  |
| Login Manager           | SDDM                    | Fairly lightweight and customizable. Balances looks and functionality; minimalism doesn't mean bad taste.      |
| Shell                   | Zsh + Starship          | Lightweight and feature-rich. Starship follows the Minimalism Principle better than omz (Oh My Zsh).           |
| AUR Helper              | Paru                    | Mature and complete. Also written in Rust.                                                                     |
| WM                      | Sway                    | Fast, i3-compatible and Wayland-centric.                                                                       |
| Bar                     | Base Swaybar            | Lightweight and simple to configure.                                                                           |
| Terminal Emulator       | Kitty                   | Fast and feature-rich. Also `Cat = Good`.                                                                      |
| Sound System            | PipeWire                | Newer and works better with newer hardware.                                                                    |
| Networking              | NetworkManager          | Well documented and more compatible; the TUI interface is excellent.                                           |
| Text Editor             | Helix                   | It just works and is written in Rust (+10 points).                                                             |
| Media Player            | mpv                     | Fast, lightweight, complete and easy to use; great man page.                                                   |
| File Manager            | nnn (n3)                | Fast and extensible. Written in C, and its complete, detailed man page makes it easy to understand and extend. |
| Web Browser (primary)   | Sandboxed LibreWolf     | Privacy-aware daily browser, with history turned on.                                                           |
| Web Browser (secondary) | Sandboxed Helium        | Fallback for websites (particularly government-related) that perform worse on Firefox-based browsers.          |
| Browser Isolation       | bubblewrap / Bubblejail | Isolates browser profiles to prevent uncontrolled application state from accumulating in `$HOME`.              |
| PDF Viewer              | pdf.js (from LibreWolf) | Built-in and meets my PDF viewing needs.                                                                       |
| Downloader              | aria2                   | Compatible with every download situation possible; its experience beats GUI downloaders.                       |

## Usage

DSam is one bash script, `dsam`, plus data: TOML files for what a machine should have, and a `packages/` tree for custom packages and dotfiles.

```sh
# From the Arch ISO, as root, inside a clone of this repo (UEFI only; it erases the disk)
./dsam base laptop /dev/nvme0n1

# After rebooting into the new system, with network up (nmtui)
dsam setup

# Day to day
dsam install [pkg...]   # no args: everything declared but missing
dsam update             # paru -Syu, then reconcile custom packages
dsam config             # link dotfiles, enable services
dsam diff [--deps]      # declared vs installed (exit 1 if they differ)
dsam info <pkg|path>    # class and source of a package, or who owns a file
```

`dsam man` shows the full manual (`dsam man --install` installs it system-wide) and `dsam help <topic>` shows one section of it. The clone should live at `~/dsam`: the paru dotfile points its PKGBUILD repository there.

## Repository layout

```
dsam                        the whole implementation (bash)
base.toml                   packages every machine gets
profiles/<name>/profile.toml  machine settings and per-profile packages and services
packages/<name>/            optional PKGBUILD, post-install.sh and .dotfiles/
LICENSE
```

`profile.toml`:

```toml
[machine]                 # read by `dsam base` only
host_name = "dsaml"
timezone = "Asia/Tehran"
locale = "en_US.UTF-8"
swap = "hibernate"        # none, zram or hibernate
esp_size = "1G"
root_size = "80G"         # /home takes the rest

[packages]
list = ["brightnessctl"]  # added on top of base.toml
exclude = []              # base.toml packages this profile does not want
ignore = []               # passed to paru -Syu --ignore

[services]
enable = []               # "user:<unit>" for user units
```

A machine's declared packages are `(base.toml - exclude) + list`. `dsam install <pkg>` records the package in `list` for you.

## Custom packages and dotfiles

A directory under `packages/` is named after a package and may contain any of:

- `PKGBUILD`: built and installed with paru. Its version is compared with the installed one, so raising it upgrades and lowering it downgrades. `.SRCINFO` is generated and git-ignored.
- `.dotfiles/`: mirrors `$HOME`. Every file is symlinked individually and nothing is ever overwritten.
- `post-install.sh`: executable, run as your user after the package is installed, upgraded or downgraded.

`dsam` itself needs `tomli`, which Arch does not package. It ships here as `packages/tomli-bin`, and `dsam` fetches the pinned, checksum-verified release for itself until that package is installed.

## Status

`dsam base` and `dsam setup` are a recent port of the former shell scripts and have not been exercised on real hardware; try them in a virtual machine first. Only `base.toml` and the laptop profile are declared so far, so most of the table above is intent rather than configuration.

## License

GPL-3.0-or-later, copyright (C) 2026 devssh. Files that state a different license in their header keep it. A PKGBUILD for software I do not own packages that software under its own license, given in the PKGBUILD's `license` array.
