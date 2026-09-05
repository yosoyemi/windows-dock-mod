# Subir a GitHub (portafolio + descarga)

La carpeta del proyecto ya está lista para `git`. No incluye Windhawk ni tus apps ancladas.

## 1. Crear el repo

En PowerShell, dentro de esta carpeta:

```powershell
cd "C:\Users\maste\OneDrive\Desktop\dev emi\windows-dock-mod"
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

## 2. Publicar el zip descargable

```powershell
.\scripts\Pack-Release.ps1
gh release create v1.0.0 dist\Emi-Windows-Dock-v1.0.0.zip -t "Emi Windows Dock v1.0.0" -n "Preset de dock para Windows 11. Descomprimí y ejecutá INSTALAR.bat."
```

Ese archivo de **Releases** es el que mandás a tus amigos. El botón Download del repo sirve, pero el zip de Releases es más simple para gente que no usa git.

## 3. Enlace directo para amigos

Cuando exista el release:

`https://github.com/TU_USUARIO/windows-dock-mod/releases/latest/download/Emi-Windows-Dock-v1.0.0.zip`

También podés subir el mismo zip a Google Drive / Discord.

## 4. Portafolio

En tu sitio, enlazá:

- Repo: `https://github.com/TU_USUARIO/windows-dock-mod`
- Preview: `screenshots/dock.png`
- Stack: Windows 11 · Windhawk · PowerShell

## Actualizar el preset

Si cambiás el dock en tu PC:

```powershell
.\scripts\Export-EmiDock.ps1
.\scripts\Pack-Release.ps1
git add dist\emi-windows-dock.whdata presets
git commit -m "Update dock preset"
git push
gh release create v1.0.1 dist\Emi-Windows-Dock-v1.0.1.zip
```

(Renombrá la versión en `Pack-Release.ps1` cuando subas un release nuevo.)
