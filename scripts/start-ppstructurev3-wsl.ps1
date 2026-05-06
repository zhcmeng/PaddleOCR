$ErrorActionPreference = 'Stop'

$Distro = 'Ubuntu'
$ProjectDir = '/mnt/c/mine/PaddleOCR'
$ConfigPath = '/mnt/c/mine/PaddleOCR/deploy/PP-StructureV3-serving.yaml'
$PythonExe = '/home/administrator/.venv-ppocr310/bin/paddlex'
$Port = 8080
$MaxAttempts = 24
$SleepSeconds = 5
$LogPath = 'C:\mine\PaddleOCR\logs\ppstructurev3-autostart.log'

function Write-Log {
    param([string]$Message)
    "[$(Get-Date -Format s)] $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

function Invoke-Wsl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $output = & wsl.exe -d $Distro -- bash -lc $Command 2>&1
    $exitCode = $LASTEXITCODE

    return [pscustomobject]@{
        Output = $output
        ExitCode = $exitCode
    }
}

function Test-PortReady {
    return [bool](Test-NetConnection 127.0.0.1 -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)
}

try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null
    Write-Log 'autostart begin'

    if (Test-PortReady) {
        Write-Log "port_already_ready=$Port"
        Write-Output "Port $Port is already ready."
        exit 0
    }

    $kill = Invoke-Wsl "pkill -f '$PythonExe --serve --pipeline $ConfigPath --device gpu --host 0.0.0.0 --port $Port' || true"
    Write-Log "kill_exit=$($kill.ExitCode)"
    Start-Sleep -Seconds 2

    $bashCommand = "cd $ProjectDir && exec $PythonExe --serve --pipeline $ConfigPath --device gpu --host 0.0.0.0 --port $Port"
    $proc = Start-Process -FilePath 'wsl.exe' `
        -ArgumentList @('-d', $Distro, '--', 'bash', '-lc', $bashCommand) `
        -WindowStyle Hidden `
        -PassThru
    Write-Log "start_pid=$($proc.Id)"

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        if (Test-PortReady) {
            Write-Log "port_ready_attempt=$i"
            Write-Output "Service is ready on port $Port."
            exit 0
        }

        if ($proc.HasExited) {
            Write-Log "process_exited early exit=$($proc.ExitCode)"
            throw "WSL launch process exited before port $Port became ready."
        }

        Write-Log "wait_attempt=$i"
        Start-Sleep -Seconds $SleepSeconds
    }

    throw "Port $Port did not become ready in time."
}
catch {
    Write-Log "error=$_"
    Write-Error $_
    exit 1
}
