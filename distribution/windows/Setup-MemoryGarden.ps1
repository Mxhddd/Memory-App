# Memory Garden setup helper for Windows.
# It gets the laptop ready to put SideStore on an iPhone, then opens the step-by-step guide.
# It only downloads from Apple and from iloader's official GitHub releases, and changes nothing else.
# Nothing can install an iPhone app from Windows without iloader + SideStore; this just removes the hunting.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Guide = 'https://mxhddd.github.io/Memory-App/'
$Work = Join-Path $env:TEMP 'MemoryGardenSetup'
New-Item -ItemType Directory -Force -Path $Work | Out-Null

function Say($text, $color = 'White') { Write-Host $text -ForegroundColor $color }
function Ask($question) {
    $answer = Read-Host "$question [Y/n]"
    return ($answer -eq '' -or $answer -match '^[Yy]')
}

Clear-Host
Say ''
Say '  Memory Garden - laptop setup' 'Magenta'
Say '  ----------------------------' 'Magenta'
Say '  This gets the laptop ready to put SideStore on an iPhone.'
Say '  Keep the iPhone nearby with its cable. It takes about 10 minutes.'
Say ''

# 1. Apple's iPhone driver (comes with iTunes from apple.com, not the Microsoft Store version)
Say 'Step 1 of 3 - Apple iPhone driver' 'Cyan'
$service = Get-Service -Name 'Apple Mobile Device Service' -ErrorAction SilentlyContinue
if ($service) {
    Say '  Found it. Good.' 'Green'
    if ($service.Status -ne 'Running') {
        try { Start-Service -Name 'Apple Mobile Device Service'; Say '  Started the driver service.' 'Green' }
        catch { Say '  The driver service is installed but stopped. Restart the laptop if the iPhone is not found.' 'Yellow' }
    }
} else {
    Say '  Not installed yet. iloader needs iTunes from Apple''s website (it includes the iPhone driver).' 'Yellow'
    if (Ask '  Download and open the iTunes installer now?') {
        $itunes = Join-Path $Work 'iTunes64Setup.exe'
        try {
            Say '  Downloading iTunes from apple.com (about 200 MB)...'
            Invoke-WebRequest -UseBasicParsing -Uri 'https://www.apple.com/itunes/download/win64' -OutFile $itunes
            Say '  Opening the installer. Click through it, then come back here.'
            Start-Process -FilePath $itunes -Wait
        } catch {
            Say '  The download did not work. Opening Apple''s page instead: choose "Download iTunes for Windows".' 'Yellow'
            Start-Process 'https://www.apple.com/itunes/'
            Read-Host '  Press Enter once iTunes is installed'
        }
    } else {
        Start-Process 'https://www.apple.com/itunes/'
        Read-Host '  Press Enter once iTunes is installed'
    }
}
Say ''

# 2. iloader (installs SideStore onto the iPhone)
Say 'Step 2 of 3 - iloader' 'Cyan'
$opened = $false
$base = 'https://github.com/nab138/iloader/releases/latest/download/'
foreach ($name in @('iloader-windows-x64.msi', 'iloader-windows-x64.exe')) {
    try {
        $file = Join-Path $Work $name
        Say "  Downloading $name from iloader's official GitHub releases..."
        Invoke-WebRequest -UseBasicParsing -Uri ($base + $name) -OutFile $file
        Say '  Opening the iloader installer. Click through it.'
        Start-Process -FilePath $file -Wait
        $opened = $true
        break
    } catch {
        Say "  Could not get $name ($($_.Exception.Message))." 'Yellow'
    }
}
if (-not $opened) {
    Say '  Opening iloader''s official download page. Download the Windows installer and run it.' 'Yellow'
    Start-Process 'https://github.com/nab138/iloader/releases/latest'
    Read-Host '  Press Enter once iloader is installed'
}
Say ''

# 3. The guide
Say 'Step 3 of 3 - the iPhone' 'Cyan'
Say '  Opening the step-by-step guide at the iPhone part.'
Say '  1. Unlock the iPhone and plug it in. Tap Trust on the phone and enter its passcode.'
Say '  2. Open iloader (Start menu), sign in with the Apple ID for this phone, choose Install SideStore.'
Say '  3. Then follow the guide on the iPhone itself.'
Start-Process "$Guide#phone"
Say ''
Say '  All set on the laptop. You can close this window.' 'Green'
Read-Host '  Press Enter to close'
