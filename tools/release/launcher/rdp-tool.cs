using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;

// RDP-Tool launcher: runs the RDP-Tool.ps1 script sitting next to this executable
// through PowerShell 7 and forwards the script's exit code unchanged.
//
// Compiled with the in-box C# 5 compiler (csc.exe, .NET Framework 4.x), so the
// source must stay C# 5 compatible: no string interpolation, no expression-bodied
// members, no null-conditional operators.
class RdpToolLauncher
{
    // The tool documents 4 for "prerequisite not met / unsupported platform" and
    // 99 for an unhandled script error. A launcher that cannot start the tool at
    // all is the same class of failure as the latter.
    private const int ExitLaunchFailed = 99;

    private static int Main(string[] args)
    {
        string scriptPath = Path.Combine(
            Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location),
            "RDP-Tool.ps1");

        if (!File.Exists(scriptPath))
        {
            Console.Error.WriteLine("Bundled script not found: " + scriptPath);
            return ExitLaunchFailed;
        }

        string pwsh = ResolvePwsh();

        StringBuilder arguments = new StringBuilder();
        arguments.Append("-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ");
        arguments.Append(Quote(scriptPath));
        for (int i = 0; i < args.Length; i++)
        {
            arguments.Append(' ');
            arguments.Append(Quote(args[i]));
        }

        ProcessStartInfo psi = new ProcessStartInfo(pwsh, arguments.ToString());
        psi.UseShellExecute = false;

        try
        {
            using (Process process = Process.Start(psi))
            {
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("PowerShell 7 (pwsh) could not be started: " + ex.Message);
            Console.Error.WriteLine(
                "RDP-Tool requires PowerShell 7.0 or later. Install it with:");
            Console.Error.WriteLine("  winget install --id Microsoft.PowerShell --source winget");
            return ExitLaunchFailed;
        }
    }

    // Install locations first (PowerShell 7 is required), then PATH.
    private static string ResolvePwsh()
    {
        string[] roots = new string[]
        {
            Environment.GetEnvironmentVariable("ProgramW6432"),
            Environment.GetEnvironmentVariable("ProgramFiles"),
            Environment.GetEnvironmentVariable("ProgramFiles(x86)")
        };

        for (int i = 0; i < roots.Length; i++)
        {
            if (string.IsNullOrEmpty(roots[i]))
            {
                continue;
            }

            string candidate = Path.Combine(roots[i], "PowerShell", "7", "pwsh.exe");
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        return "pwsh.exe";
    }

    // Windows command-line quoting rules: backslashes are doubled before a quote
    // and before the closing quote, embedded quotes are escaped.
    private static string Quote(string value)
    {
        if (value.Length > 0 && value.IndexOfAny(new char[] { ' ', '\t', '"' }) < 0)
        {
            return value;
        }

        StringBuilder sb = new StringBuilder();
        sb.Append('"');

        int backslashes = 0;
        for (int i = 0; i < value.Length; i++)
        {
            char c = value[i];
            if (c == '\\')
            {
                backslashes++;
                sb.Append(c);
            }
            else if (c == '"')
            {
                sb.Append('\\', backslashes + 1);
                sb.Append('"');
                backslashes = 0;
            }
            else
            {
                backslashes = 0;
                sb.Append(c);
            }
        }

        sb.Append('\\', backslashes);
        sb.Append('"');
        return sb.ToString();
    }
}
