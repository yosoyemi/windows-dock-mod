using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;

namespace EmiDockSetup;

[System.Runtime.Versioning.SupportedOSPlatform("windows")]
internal static class Program
{
    private const string Version = "1.0.1";

    private static int Main()
    {
        try
        {
            Console.Title = "Emi Liquid Glass Dock";
            Console.OutputEncoding = System.Text.Encoding.UTF8;
        }
        catch { }

        WriteBanner();
        using var installMutex = new Mutex(false, @"Local\EmiWindowsDockSetup");
        bool acquired;
        try { acquired = installMutex.WaitOne(0); }
        catch (AbandonedMutexException) { acquired = true; }
        if (!acquired)
        {
            Fail("Ya hay otro instalador abierto. Cierra esa ventana antes de continuar.");
            return 1;
        }

        if (GetWindowsBuild() < 19041)
        {
            Fail("Este dock es para Windows 10 (2004+, build 19041) o Windows 11.");
            return 1;
        }

        Console.WriteLine("Enter = instalar     Ctrl+C = cancelar");
        Console.WriteLine();
        try { Console.ReadLine(); } catch { }

        try
        {
            Console.WriteLine("Preparando archivos...");
            var packDir = ExtractPayload();
            var script = Path.Combine(packDir, "scripts", "Install-EmiDock.ps1");
            if (!File.Exists(script))
            {
                Fail("Falta scripts\\Install-EmiDock.ps1 en el paquete.");
                return 1;
            }

            Console.WriteLine("Instalando. No cierres esta ventana.");
            Console.WriteLine();

            var psi = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                    @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"",
                UseShellExecute = false,
                WorkingDirectory = packDir
            };

            using var process = Process.Start(psi);
            if (process is null)
            {
                Fail("No se pudo iniciar PowerShell.");
                return 1;
            }
            process.WaitForExit();
            if (process.ExitCode != 0)
            {
                Fail("La instalacion fallo. Log: " + Path.Combine(Path.GetTempPath(), "emi-dock-install.log"));
                return process.ExitCode;
            }

            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Instalacion completada.");
            Console.WriteLine("Para quitar el dock: " + Path.Combine(packDir, "DESINSTALAR.bat"));
            Console.ResetColor();
            Pause();
            return 0;
        }
        catch (Exception ex)
        {
            Fail(ex.Message);
            return 1;
        }
    }

    private static int GetWindowsBuild()
    {
        try
        {
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            var text = (key?.GetValue("CurrentBuildNumber") ?? key?.GetValue("CurrentBuild")) as string;
            if (int.TryParse(text, out var build) && build > 0)
                return build;
        }
        catch { }

        return Environment.OSVersion.Version.Build;
    }

    private static void WriteBanner()
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("  ============================================");
        Console.WriteLine("   Emi Liquid Glass Dock  v" + Version);
        Console.WriteLine("   Instalador para Windows 10 y 11");
        Console.WriteLine("  ============================================");
        Console.ResetColor();
        Console.WriteLine();
        Console.WriteLine("  No pide administrador.");
        Console.WriteLine("  Descarga Windhawk en Windows 11 o TaskbarX en Windows 10.");
        Console.WriteLine("  Las descargas verificadas se guardan para futuros intentos.");
        Console.WriteLine();
    }

    private static string ExtractPayload()
    {
        var dest = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "EmiWindowsDock",
            "pack");
        var staging = dest + "-" + Guid.NewGuid().ToString("N");
        var backup = staging + "-previous";
        var promoted = false;
        using var stream = OpenPayload();
        using var zip = new ZipArchive(stream, ZipArchiveMode.Read);
        try
        {
            zip.ExtractToDirectory(staging);
            foreach (var required in new[] { @"scripts\Install-EmiDock.ps1", @"scripts\Uninstall-EmiDock.ps1",
                @"dist\emi-windows-dock.whdata", "INSTALAR.bat", "DESINSTALAR.bat" })
            {
                if (!File.Exists(Path.Combine(staging, required)))
                    throw new InvalidDataException("El paquete esta incompleto: " + required);
            }
            if (Directory.Exists(dest)) Directory.Move(dest, backup);
            try { Directory.Move(staging, dest); promoted = true; }
            catch
            {
                if (Directory.Exists(backup)) Directory.Move(backup, dest);
                throw;
            }
            return dest;
        }
        finally
        {
            // A cleanup failure must not mask installation errors or a successful extraction.
            foreach (var temporary in promoted ? new[] { staging, backup } : new[] { staging })
            {
                try { if (Directory.Exists(temporary)) Directory.Delete(temporary, true); }
                catch { }
            }
        }
    }

    private static Stream OpenPayload()
    {
        var asm = Assembly.GetExecutingAssembly();
        var named = asm.GetManifestResourceStream("payload.zip");
        if (named != null) return named;

        foreach (var name in asm.GetManifestResourceNames())
        {
            if (name.EndsWith("payload.zip", StringComparison.OrdinalIgnoreCase))
            {
                var s = asm.GetManifestResourceStream(name);
                if (s != null) return s;
            }
        }

        throw new InvalidOperationException(
            "El instalador no incluye el paquete interno. Volve a bajar Emi-Windows-Dock-Setup-v" + Version + ".exe");
    }

    private static void Fail(string message)
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Red;
        Console.WriteLine(message);
        Console.ResetColor();
        Pause();
    }

    private static void Pause()
    {
        Console.WriteLine();
        Console.WriteLine("Enter para cerrar...");
        try { Console.ReadLine(); } catch { }
    }
}
