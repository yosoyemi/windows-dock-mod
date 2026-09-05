# Instalación

## Amigos (recomendado)

1. Bajá **Emi-Windows-Dock-v1.0.0.zip**.
2. Extraé la carpeta.
3. Doble clic en `INSTALAR.bat`.
4. Si Windows bloquea el script, elegí **Más información → Ejecutar de todas formas**.
5. Esperá a que descargue Windhawk (solo la primera vez) e importe el preset.
6. El Explorador se reinicia solo. Pasá el mouse por el centro inferior de la pantalla.

No pide administrador: Windhawk se instala portable en `%LOCALAPPDATA%\Programs\Windhawk`.

## Si ya tenés Windhawk 2

El instalador detecta `windhawk-cli.exe` y solo importa `dist\emi-windows-dock.whdata`.

También podés importar a mano:

```powershell
windhawk-cli.exe data import .\dist\emi-windows-dock.whdata --offline --yes --confirm-app-restart
```

## Ajustes de Windows que aplica

- Barra centrada
- Widgets desactivados
- Vista de tareas oculta
- Tema oscuro
- Auto-ocultar barra (bit en `StuckRects3`)

No toca los iconos anclados.

## Quitar el dock

```powershell
.\scripts\Uninstall-EmiDock.ps1
.\scripts\Uninstall-EmiDock.ps1 -RemoveMods
```

## Problemas frecuentes

| Síntoma | Qué hacer |
| --- | --- |
| No aparece el dock | Reiniciá `explorer.exe` o cerrá sesión. |
| Barra clásica de Windows | Confirmá que Windhawk está corriendo en la bandeja. |
| Error de hash al bajar Windhawk | Bajá a mano [2.0.0-alpha.3](https://github.com/ramensoftware/windhawk/releases/tag/2.0.0-alpha.3) e instalalo; volvé a correr `INSTALAR.bat`. |
| Windows 10 | No soportado. Hace falta Windows 11. |
