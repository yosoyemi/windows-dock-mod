# Instalación

Hay dos formas de instalar el dock. En Windows 11 aplican el preset Windhawk (Liquid Glass). En Windows 10 instalan un dock compatible con TaskbarX.

## Opción A — ZIP (para mandar a alguien)

1. Bajá **Emi-Windows-Dock-v1.0.1.zip**.
2. Clic derecho → **Extraer todo**. No abras `INSTALAR.bat` desde dentro del zip.
3. Entrá a la carpeta extraída y doble clic en **INSTALAR.bat**.
4. Si Windows bloquea: **Más información → Ejecutar de todas formas**.
5. Esperá. La primera vez necesita internet: Windows 11 baja Windhawk; Windows 10 baja TaskbarX.
6. El Explorador se reinicia. En Windows 11, pasá el mouse por el **centro** inferior. En Windows 10 los iconos quedan centrados en la barra.

No pide administrador. Windhawk (Win11) queda en `%LOCALAPPDATA%\Programs\Windhawk`. En Windows 10 quedan TaskbarX y `EmiDockGlass.exe` en `%LOCALAPPDATA%\Programs\EmiDock`.

## Opción B — Instalador EXE (portafolio / un clic)

1. Bajá **Emi-Windows-Dock-Setup-v1.0.1.exe**.
2. Doble clic. Si SmartScreen aparece: **Más información → Ejecutar de todas formas**.
3. Presiona **Enter** para instalar y espera.

El EXE extrae el mismo paquete y corre el mismo instalador.

## Si ya tenés Windhawk 2

El instalador detecta `windhawk-cli.exe` (también en `WindhawkDock`) y solo importa `dist\emi-windows-dock.whdata`.

```powershell
windhawk-cli.exe --yes data import .\dist\emi-windows-dock.whdata --yes --confirm-app-restart --on-conflict overwrite --no-app-settings
```

## Ajustes de Windows que aplica

- Barra centrada
- Widgets desactivados
- Vista de tareas oculta
- Tema oscuro
- Auto-ocultar barra

No toca los iconos anclados.

## Quitar el dock

Doble clic en `DESINSTALAR.bat`, o:

```powershell
.\scripts\Uninstall-EmiDock.ps1
.\scripts\Uninstall-EmiDock.ps1 -RemoveMods
```

## Problemas frecuentes

| Síntoma | Qué hacer |
| --- | --- |
| “Ejecutá desde la carpeta extraída” | Extraé el zip completo. No corras el `.bat` adentro del zip. |
| Windows protegió tu PC | Más información → Ejecutar de todas formas. |
| No aparece el dock | Reiniciá `explorer.exe` o cerrá sesión. En Windows 11, Windhawk tiene que estar en la bandeja. En Windows 10, TaskbarX.exe tiene que estar en ejecución. |
| Error de hash al bajar Windhawk | Bajá a mano [2.0.0-alpha.3](https://github.com/ramensoftware/windhawk/releases/tag/2.0.0-alpha.3), instalalo, y volvé a correr `INSTALAR.bat`. |
| Falló la instalación | Abrí `%TEMP%\emi-dock-install.log`. |
| Windows 10 (build 19045, etc.) | Dock de vidrio esmerilado (acrylic) + iconos centrados. La barra queda flotante y visible. El Liquid Glass XAML completo sigue siendo solo Windows 11. |
| Dock negro / no se ven iconos (Win10) | Actualizá el pack. La versión vieja pintaba un overlay oscuro. DESINSTALAR.bat y volvé a instalar. |
| “Este dock es para Windows 11” | Actualizá el pack. Las versiones viejas cortaban en Windows 10. |

## Descargas y reintentos

Las dependencias se descargan desde sus releases oficiales y se verifican con SHA256 antes de usarlas. El instalador hace hasta tres intentos; si una descarga se interrumpe o llega corrupta, elimina el archivo parcial y vuelve a intentarlo. Las descargas verificadas se guardan en `%LOCALAPPDATA%\EmiWindowsDock\downloads` y se reutilizan en instalaciones posteriores, incluso sin conexión. Windhawk puede necesitar internet adicional para sus componentes o mods.

Si los tres intentos fallan, revisa la conexión y el acceso a GitHub desde tu proxy o firewall. El detalle queda en `%TEMP%\emi-dock-install.log`. Un error de SHA256 no debe ignorarse: vuelve a descargar desde la fuente oficial.

El EXE conserva el paquete anterior hasta que termina de extraer y validar el nuevo. Al terminar muestra la ubicación de `DESINSTALAR.bat`. TaskbarX también valida el contenido del ZIP antes de reemplazar la instalación anterior.

Para verificar el flujo de descargas sin instalar ni modificar la barra:

```powershell
.\scripts\Test-Downloads.ps1
```