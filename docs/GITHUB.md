# Subir a GitHub (portafolio + descarga)

La carpeta del proyecto ya está lista para `git`. No incluye Windhawk ni tus apps ancladas.

## 1. Empaquetar zip + instalador

```powershell
cd "C:\Users\maste\OneDrive\Desktop\dev emi\windows-dock-mod"
.\scripts\Pack-Release.ps1
```

Quedan en `dist/`:

- `Emi-Windows-Dock-v1.0.1.zip` — para mandar por Drive / Discord / mail
- `Emi-Windows-Dock-Setup-v1.0.1.exe` — instalador de un clic para el portafolio
- `Emi-Windows-Dock-v1.0.1.sha256.txt` — checksums

## 2. Crear el repo

```powershell
git init
git add .
git commit -m "Initial Emi Liquid Glass Dock pack"
```

Si tenés [GitHub CLI](https://cli.github.com/):

```powershell
gh repo create windows-dock-mod --public --source . --remote origin --push
```

Si no:

1. Creá un repo vacío en github.com llamado `windows-dock-mod`.
2. Luego:

```powershell
git remote add origin https://github.com/TU_USUARIO/windows-dock-mod.git
git branch -M main
git push -u origin main
```

## 3. Publicar los archivos descargables

```powershell
gh release create v1.0.1 dist\Emi-Windows-Dock-v1.0.1.zip dist\Emi-Windows-Dock-Setup-v1.0.1.exe -t "Emi Windows Dock v1.0.1" -n "Descomprimí el zip y ejecutá INSTALAR.bat, o usá el Setup.exe."
```

Enlaces directos:

- Zip: `https://github.com/TU_USUARIO/windows-dock-mod/releases/latest/download/Emi-Windows-Dock-v1.0.1.zip`
- Setup: `https://github.com/TU_USUARIO/windows-dock-mod/releases/latest/download/Emi-Windows-Dock-Setup-v1.0.1.exe`

## 4. Portafolio

En tu sitio, enlazá:

- **Download (instalador):** el `.exe`
- **Download (zip):** el `.zip`
- Preview: `screenshots/dock.png`
- Stack: Windows 11 · Windhawk · Windows 10 (TaskbarX) · PowerShell

Mandá el zip a amigos. El exe es más cómodo en una landing, pero SmartScreen puede avisarlo por no estar firmado.

## Actualizar el preset

```powershell
.\scripts\Export-EmiDock.ps1
.\scripts\Pack-Release.ps1
git add dist\emi-windows-dock.whdata presets
git commit -m "Update dock preset"
git push
```
