[CmdletBinding()]
param([ValidateSet('es', 'en')][string]$Language = 'es')

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Import-Module (Join-Path $Root 'src\HermesManager.psm1') -Force
. (Join-Path $Root 'src\HermesLocalization.ps1')
Set-HermesLanguage -Language $Language

function Write-Host {
    param(
        [Parameter(Position = 0)][object[]]$Object,
        [switch]$NoNewline,
        [Nullable[ConsoleColor]]$ForegroundColor,
        [Nullable[ConsoleColor]]$BackgroundColor,
        [string]$Separator = ' '
    )
    Write-HermesLocalizedHost -Object $Object -NoNewline:$NoNewline -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -Separator $Separator
}

$aliases = @(Get-HermesAgents -Root $Root | Where-Object { $_.TerminalAlias })
if (-not $aliases.Count) {
    throw 'No hay alias configurados. Abre Hermes Manager y utiliza la opción A.'
}

$added = Install-HermesAliasPath -Root $Root
$binPath = Get-HermesBinPath -Root $Root
$userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
if (@($userPath -split ';' | Where-Object { $_.TrimEnd('\').Equals($binPath, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) {
    throw "No se pudo registrar $binPath en el PATH del usuario."
}

Write-Host
Write-Host 'ALIAS GLOBALES ACTIVADOS' -ForegroundColor Green
Write-Host "Ruta: $binPath"
Write-Host 'Disponibles:'
foreach ($agent in $aliases | Sort-Object TerminalAlias) {
    Write-Host ("  {0}  ->  {1}" -f $agent.TerminalAlias, $agent.DisplayName)
}
Write-Host
if ($added) {
    Write-Host 'Abre una terminal nueva antes de utilizarlos.' -ForegroundColor Yellow
} else {
    Write-Host 'La ruta ya estaba registrada. Puedes abrir una terminal nueva y utilizarlos.'
}
