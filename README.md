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
| Bootloader              | GRUB                    | Highly customizable and mature.                                                                                |
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
