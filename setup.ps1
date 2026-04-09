$versionUrl = "https://raw.githubusercontent.com/lefiera/rbx-setup/refs/heads/main/version.txt"
$downloaderUrl = "https://raw.githubusercontent.com/lefiera/rbx-setup/refs/heads/main/rdd.bat"

$version = (Invoke-WebRequest -Uri $versionUrl -UseBasicParsing).Content.Trim()

$downloaderPath = Join-Path $env:TEMP "rdd.bat"
Invoke-WebRequest -Uri $downloaderUrl -OutFile $downloaderPath -UseBasicParsing

Get-Process -Name "RobloxPlayerBeta","RobloxCrashHandler" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "setting up.. DONT CLOSE!."

$desktopPath = [Environment]::GetFolderPath("Desktop")
$outputPath = Join-Path $desktopPath "roblox"

$process = Start-Process -FilePath $downloaderPath -ArgumentList "--version", $version, "--output", "`"$outputPath`"" -Wait -PassThru -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Host "Error: rdd.bat exited with code $($process.ExitCode)" -ForegroundColor Red
    exit 1
}

$exePath = "$outputPath\$version\RobloxPlayerBeta.exe"
$registryValue = "`"$exePath`" %1"

$regPath = "HKCU:\Software\Classes\roblox-player\shell\open\command"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value $registryValue

Write-Host "Finished setting up Volt, now restart the Volt application and press Install Now, it will be then ready to use"