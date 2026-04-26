param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$serverDataPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootPath = Split-Path -Parent $serverDataPath
$serverBinaryPath = Join-Path $rootPath 'server\FXServer.exe'
$serverConfigPath = Join-Path $serverDataPath 'server.cfg'
$serverInternalConfigPath = Join-Path $serverDataPath 'server_internal.cfg'
$logDirectoryPath = Join-Path $serverDataPath 'logs\startup'

function Write-StartupLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $script:LogFilePath -Value $line
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label was not found at $Path"
    }
}

function Assert-ConfigDoesNotContain {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch -Quiet) {
        throw $Message
    }
}

New-Item -ItemType Directory -Path $logDirectoryPath -Force | Out-Null
$startupTimestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$script:LogFilePath = Join-Path $logDirectoryPath ("startup-$startupTimestamp.log")
New-Item -ItemType File -Path $script:LogFilePath -Force | Out-Null

try {
    Write-StartupLog -Message "Preparing FXServer startup from $serverDataPath"

    Assert-FileExists -Path $serverBinaryPath -Label 'FXServer binary'
    Assert-FileExists -Path $serverConfigPath -Label 'Server config'
    Assert-FileExists -Path $serverInternalConfigPath -Label 'Internal server config'

    Assert-ConfigDoesNotContain -Path $serverInternalConfigPath -Pattern 'REPLACE_WITH_YOUR_LICENSE_KEY' -Message 'server_internal.cfg still contains the placeholder license key.'
    Assert-ConfigDoesNotContain -Path $serverInternalConfigPath -Pattern 'mysql://username:password@localhost/lsrp' -Message 'server_internal.cfg still contains the placeholder mysql connection string.'

    Write-StartupLog -Message 'Preflight checks passed.'

    if ($DryRun) {
        Write-StartupLog -Message 'Dry run requested. Skipping FXServer launch.'
        exit 0
    }

    Push-Location -LiteralPath $serverDataPath
    try {
        Write-StartupLog -Message "Launching FXServer. Log file: $script:LogFilePath"
        & $serverBinaryPath '+exec' 'server.cfg' 2>&1 | Tee-Object -FilePath $script:LogFilePath -Append
        $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        Write-StartupLog -Message "FXServer exited with code $exitCode" -Level ($(if ($exitCode -eq 0) { 'INFO' } else { 'ERROR' }))
        exit $exitCode
    }
    finally {
        Pop-Location
    }
}
catch {
    if (-not $script:LogFilePath) {
        throw
    }

    Write-StartupLog -Message $_.Exception.Message -Level 'ERROR'
    exit 1
}