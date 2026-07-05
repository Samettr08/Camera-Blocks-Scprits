@echo off
title Camera Blocker
color 0A
echo =========================================
echo   BY Samettr08 - Baslatiliyor...
echo =========================================
echo.

set "ps1file=%temp%\camerablocker_pro.ps1"

powershell -NoProfile -Command "$code = @' 
# GitHub: Samettr08 / guestiyy
# Kamera Blocker 
# Yönetici yetkisi zorunludur

#region Yönetici kontrolü
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"" + $MyInvocation.MyCommand.Path + "`""
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}
#endregion

#region Log fonksiyonu
$logDir = "C:\ProgramData\CameraBlocker"
$logFile = "$logDir\camera.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $entry -Force
    Write-Host $entry
}
#endregion

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  CAMERA BLOCKER " -ForegroundColor Yellow
Write-Host "  (c) Samettr08 / guestiyy" -ForegroundColor Gray
Write-Host "=========================================" -ForegroundColor Cyan
Write-Log "Başlatılıyor..."

#region C# kaynak kodu (geliştirilmiş)
$csharpCode = @"
using System;
using System.IO;
using System.Diagnostics;
using System.Security.AccessControl;
using System.Threading;
using Microsoft.Win32;

namespace CameraBlockerPro {
    class Program {
        private static string logPath = @"C:\ProgramData\CameraBlocker\camera.log";
        private static Mutex appMutex;

        static void Log(string msg) {
            try { File.AppendAllText(logPath, $""[{DateTime.Now}] {msg}\n""); } catch { }
        }

        static void Main() {
            bool createdNew;
            appMutex = new Mutex(true, ""Global\\CameraBlockerProMutex"", out createdNew);
            if (!createdNew) {
                Log(""Zaten çalışıyor, çıkılıyor."");
                return;
            }

            Log(""EXE başlatıldı."");

            try {
                string exePath = System.Reflection.Assembly.GetExecutingAssembly().Location;
                using (var key = Registry.CurrentUser.OpenSubKey(@""Software\Microsoft\Windows\CurrentVersion\Run"", true)) {
                    if (key != null) key.SetValue(""CameraBlockerPro"", exePath);
                }
                using (var key = Registry.CurrentUser.OpenSubKey(@""Software\Microsoft\Windows\CurrentVersion\RunOnce"", true)) {
                    if (key != null) key.SetValue(""CameraBlockerPro"", exePath);
                }
                string startup = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
                string shortcut = Path.Combine(startup, ""CameraBlockerPro.lnk"");
                if (!File.Exists(shortcut)) {
                    try {
                        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID(""WScript.Shell""));
                        dynamic sc = shell.CreateShortcut(shortcut);
                        sc.TargetPath = exePath;
                        sc.WorkingDirectory = Path.GetDirectoryName(exePath);
                        sc.Save();
                    } catch { }
                }
                Log(""Kalıcılık başarılı."");
            } catch (Exception ex) { Log(""Kalıcılık hatası: "" + ex.Message); }

            string[] cameraGuids = {
                ""{6bdd1fc6-810f-11d0-bec7-08002be2092f}"",
                ""{65E8773D-8F56-11D0-A3B9-00A0C9223196}"",
                ""{ca3e7ab9-b4c3-4ae6-8251-579ef933890f}"",
                ""{e5323777-f976-4f5b-9b55-b94699c46e44}"",
                ""{33c186a1-39d4-45a1-84f0-9ad4bb11bb58}""
            };

            foreach (string guid in cameraGuids) {
                string regPath = @""SYSTEM\CurrentControlSet\Control\Class\"" + guid;
                try {
                    using (var key = Registry.LocalMachine.OpenSubKey(regPath, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.TakeOwnership | RegistryRights.ChangePermissions)) {
                        if (key != null) {
                            var rs = key.GetAccessControl();
                            var rule = new RegistryAccessRule(""Everyone"", RegistryRights.ReadKey | RegistryRights.SetValue | RegistryRights.CreateSubKey | RegistryRights.Delete, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Deny);
                            rs.AddAccessRule(rule);
                            key.SetAccessControl(rs);
                            Log(""ACL eklendi: "" + guid);
                        }
                    }
                } catch (Exception ex) { Log(""ACL hatası "" + guid + "": "" + ex.Message); }
            }

            try {
                using (var classKey = Registry.LocalMachine.OpenSubKey(@""SYSTEM\CurrentControlSet\Control\DeviceClasses"", false)) {
                    if (classKey != null) {
                        foreach (string sub in classKey.GetSubKeyNames()) {
                            bool match = false;
                            foreach (string g in cameraGuids) if (sub.Contains(g.Replace(""{"" ,"""").Replace(""}"" ,""""))) match = true;
                            if (match) {
                                using (var target = Registry.LocalMachine.OpenSubKey(@""SYSTEM\CurrentControlSet\Control\DeviceClasses\"" + sub, true)) {
                                    if (target != null) {
                                        var rs = target.GetAccessControl();
                                        rs.AddAccessRule(new RegistryAccessRule(""Everyone"", RegistryRights.ReadKey | RegistryRights.SetValue, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Deny));
                                        target.SetAccessControl(rs);
                                        Log(""DeviceClass ACL: "" + sub);
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (Exception ex) { Log(""DeviceClasses hatası: "" + ex.Message); }

            try {
                var searcher = new System.Management.ManagementObjectSearcher(""SELECT * FROM Win32_PnPEntity WHERE (Name LIKE '%camera%' OR Name LIKE '%webcam%' OR Name LIKE '%kamera%' OR Description LIKE '%camera%' OR Description LIKE '%webcam%' OR PNPClass = 'Image' OR PNPClass = 'Camera')"");
                foreach (System.Management.ManagementObject device in searcher.Get()) {
                    try {
                        if (device[""DeviceID""] != null) {
                            string devId = device[""DeviceID""].ToString();
                            var method = device.GetMethodParameters(""Disable"");
                            var result = device.InvokeMethod(""Disable"", method, null);
                            Log(""WMI devre dışı: "" + devId + "" (sonuç: "" + result + "")"");
                        }
                    } catch { }
                }
            } catch (Exception ex) { Log(""WMI hatası: "" + ex.Message); }

            try {
                Process p = new Process();
                p.StartInfo.FileName = ""pnputil"";
                p.StartInfo.Arguments = ""/disable-device * /class Image"";
                p.StartInfo.CreateNoWindow = true;
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.RedirectStandardOutput = true;
                p.Start();
                string output = p.StandardOutput.ReadToEnd();
                p.WaitForExit(5000);
                Log(""pnputil çalıştı: "" + output.Substring(0, Math.Min(200, output.Length)));
            } catch (Exception ex) { Log(""pnputil hatası: "" + ex.Message); }

            Log(""Koruma döngüsü başladı."");
            while (true) {
                Thread.Sleep(30000);
                try {
                    string mainPath = @""SYSTEM\CurrentControlSet\Control\Class\{6bdd1fc6-810f-11d0-bec7-08002be2092f}"";
                    using (var key = Registry.LocalMachine.OpenSubKey(mainPath, false)) {
                        if (key != null) {
                            var rs = key.GetAccessControl();
                            bool hasDeny = false;
                            foreach (RegistryAccessRule rule in rs.GetAccessRules(true, true, typeof(System.Security.Principal.NTAccount))) {
                                if (rule.IdentityReference.Value == ""Everyone"" && rule.AccessControlType == AccessControlType.Deny) { hasDeny = true; break; }
                            }
                            if (!hasDeny) {
                                using (var rw = Registry.LocalMachine.OpenSubKey(mainPath, RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.ChangePermissions)) {
                                    if (rw != null) {
                                        var rs2 = rw.GetAccessControl();
                                        rs2.AddAccessRule(new RegistryAccessRule(""Everyone"", RegistryRights.ReadKey | RegistryRights.SetValue, InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Deny));
                                        rw.SetAccessControl(rs2);
                                        Log(""ACL yeniden uygulandı."");
                                    }
                                }
                            }
                        }
                    }
                    if (DateTime.Now.Minute % 5 == 0) { }
                } catch (Exception ex) { Log(""Döngü hatası: "" + ex.Message); }
            }
        }
    }
}
""@

$exePath = ""$env:SystemRoot\CameraBlockerPro.exe""
Add-Type -TypeDefinition @""
using System;
using System.CodeDom.Compiler;
using Microsoft.CSharp;
using System.Reflection;
public class Compiler {
    public static bool Compile(string code, string output) {
        var provider = new CSharpCodeProvider();
        var parameters = new CompilerParameters();
        parameters.ReferencedAssemblies.Add(""System.dll"");
        parameters.ReferencedAssemblies.Add(""System.Security.dll"");
        parameters.ReferencedAssemblies.Add(""System.Management.dll"");
        parameters.GenerateExecutable = true;
        parameters.OutputAssembly = output;
        parameters.CompilerOptions = ""/target:winexe /platform:anycpu"";
        var results = provider.CompileAssemblyFromSource(parameters, code);
        return results.Errors.Count == 0;
    }
}
""@ -ReferencedAssemblies ""System.dll"",""System.Security.dll"",""System.Management.dll""

$compilerType = [Compiler]
$compiled = $compilerType::Compile($csharpCode, $exePath)

if ($compiled) {
    Write-Host ""[OK] CameraBlockerPro.exe oluşturuldu: $exePath"" -ForegroundColor Green
    Write-Log ""EXE derlendi: $exePath""

    Set-ItemProperty -Path ""HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"" -Name ""CameraBlockerPro"" -Value $exePath -Force
    Set-ItemProperty -Path ""HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"" -Name ""CameraBlockerPro"" -Value $exePath -Force
    $startup = [Environment]::GetFolderPath(""Startup"")
    $shortcut = Join-Path $startup ""CameraBlockerPro.lnk""
    if (-not (Test-Path $shortcut)) {
        $shell = New-Object -ComObject WScript.Shell
        $sc = $shell.CreateShortcut($shortcut)
        $sc.TargetPath = $exePath
        $sc.WorkingDirectory = ""C:\ProgramData\CameraBlocker""
        $sc.Save()
    }
    $taskName = ""CameraBlockerPro""
    $action = New-ScheduledTaskAction -Execute $exePath -Argument ""-silent""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction SilentlyContinue | Out-Null

    Start-Process -FilePath $exePath -WindowStyle Hidden

    $guids = @(""{6bdd1fc6-810f-11d0-bec7-08002be2092f}"",""{65E8773D-8F56-11D0-A3B9-00A0C9223196}"",""{ca3e7ab9-b4c3-4ae6-8251-579ef933890f}"",""{e5323777-f976-4f5b-9b55-b94699c46e44}"",""{33c186a1-39d4-45a1-84f0-9ad4bb11bb58}"")
    foreach ($g in $guids) {
        $path = ""HKLM:\SYSTEM\CurrentControlSet\Control\Class\$g""
        if (Test-Path $path) {
            try {
                $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(""SYSTEM\CurrentControlSet\Control\Class\$g"", $true)
                if ($key) {
                    $acl = $key.GetAccessControl()
                    $rule = New-Object System.Security.AccessControl.RegistryAccessRule(""Everyone"", ""ReadKey, SetValue, CreateSubKey, Delete"", ""ContainerInherit, ObjectInherit"", ""None"", ""Deny"")
                    $acl.AddAccessRule($rule)
                    $key.SetAccessControl($acl)
                    $key.Close()
                    Write-Log ""ACL (PS1) uygulandı: $g""
                }
            } catch { Write-Log ""PS1 ACL hatası $g : $_"" }
        }
    }

    Write-Host """"
    Write-Host ""[OK] Tüm işlemler başarıyla tamamlandı."" -ForegroundColor Green
    Write-Host ""[INFO] Log dosyası: $logFile"" -ForegroundColor Gray
    Write-Host ""[INFO] EXE konumu: $exePath"" -ForegroundColor Gray
    Write-Host ""[INFO] Yeniden başlatmada otomatik çalışır."" -ForegroundColor Gray
    Write-Host ""[INFO] Kamera erişimi tamamen engellendi."" -ForegroundColor Yellow
    Write-Log ""PS1 betiği başarıyla tamamlandı.""
} else {
    Write-Host ""[ERR] Derleme başarısız! .NET Framework veya System.Management.dll eksik."" -ForegroundColor Red
    Write-Log ""DERLEME HATASI - lütfen .NET Framework 4.5+ yükleyin.""
    Read-Host ""Çıkmak için Enter""
    exit
}

Write-Host """"
Write-Host ""=== İŞLEM SONU ==="" -ForegroundColor Cyan
Read-Host -Prompt ""Çıkmak için Enter tuşuna basın""
'@; $code | Out-File -FilePath $env:temp\camerablocker_pro.ps1 -Encoding UTF8"

if exist "%ps1file%" (
    powershell -ExecutionPolicy Bypass -File "%ps1file%"
    del "%ps1file%"
) else (
    echo [ERR] Geçici dosya oluşturulamadı.
    pause
)
:: ===== İŞLEM SONU BİLGİSİ VE BEKLETME =====
echo.
echo ======================================================
echo  ISLEM TAMAMLANDI
echo ======================================================
echo  [DURUM] Kamera erisimi engellendi.
echo  [LOG]   C:\ProgramData\CameraBlocker\camera.log
echo  [EXE]   %SystemRoot%\CameraBlockerPro.exe
echo  [NOT]   Sistem yeniden baslatin.
echo ======================================================
echo.
echo Kapatmak icin herhangi bir tusa basin...
pause >nul