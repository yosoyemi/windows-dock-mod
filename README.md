# Emi Liquid Glass Dock

Windows 11 taskbar styled as a floating liquid-glass dock: blur, rounded capsule, hover magnification, auto-hide, and a tray that only appears when you need it.

![Dock preview](screenshots/dock.png)

This repo is a **shareable preset**, not a closed app. Friends download a zip, double-click `INSTALAR.bat`, and get the same look. The project is also ready to push to GitHub as a portfolio piece.

## What it does

- Floating centered dock with **Liquid Glass** blur and a 5px radius
- macOS-style **icon magnification** on hover (no bounce)
- Auto-hide when a window covers the bar; only the center of the bottom edge wakes it
- System tray hidden until hover
- Dark Windows 11 chrome, widgets off, taskbar centered

## Requirements

- Windows 11 (build 22000+)
- Internet the first time (to download [Windhawk](https://windhawk.net/) if it is not installed)
- Windhawk **2.0** (the installer fetches `2.0.0-alpha.3`)

## Install (friends)

1. Download **`Emi-Windows-Dock-v1.0.0.zip`** from [Releases](../../releases) or grab the copy in `dist/` after packing.
2. Unzip anywhere.
3. Double-click **`INSTALAR.bat`**.
4. Hover the bottom of the screen. The dock slides up.

Manual:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-EmiDock.ps1
```

Undo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Uninstall-EmiDock.ps1
```

The uninstaller disables the mods. Windhawk itself stays installed.

## Install from Git

```powershell
git clone https://github.com/TU_USUARIO/windows-dock-mod.git
cd windows-dock-mod
.\INSTALAR.bat
```

Replace `TU_USUARIO` after you publish the repo.

## Project layout

```
windows-dock-mod/
  INSTALAR.bat                 # one-click for friends
  dist/emi-windows-dock.whdata # Windhawk archive (mods + your settings)
  presets/                     # readable JSON / INI settings
  registry/                    # Windows 11 tweaks (no pinned apps)
  screenshots/
  scripts/
    Install-EmiDock.ps1
    Uninstall-EmiDock.ps1
    Pack-Release.ps1           # builds the zip
    Export-EmiDock.ps1         # refresh preset from this PC
  docs/
```

Pinned apps are **not** included. Everyone keeps their own icons.

## Publish to GitHub

See [docs/GITHUB.md](docs/GITHUB.md). Short version:

```powershell
cd "C:\Users\maste\OneDrive\Desktop\dev emi\windows-dock-mod"
git init
git add .
git commit -m "Initial Emi Liquid Glass Dock pack"
gh repo create windows-dock-mod --public --source . --remote origin --push
.\scripts\Pack-Release.ps1
gh release create v1.0.0 dist\Emi-Windows-Dock-v1.0.0.zip -t "Emi Windows Dock v1.0.0" -n "One-click Windows 11 dock preset."
```

Friends then download the release zip. You can also send `dist\Emi-Windows-Dock-v1.0.0.zip` on Discord / Drive.

## Stack

| Layer | Tool |
| --- | --- |
| Mod engine | [Windhawk](https://windhawk.net/) 2.0 |
| Look | Windows 11 Taskbar Styler · LiquidGlass2 |
| Motion | Taskbar Dock Animation Plus |
| Hide / reveal | auto-hide mods + tray-on-hover |
| Pack | PowerShell installer + `.whdata` archive |

Credits for each mod: [CREDITS.md](CREDITS.md).

## License

MIT for this pack (scripts, presets, docs). Windhawk and the original mods keep their own licenses (typically GPL-3.0).
