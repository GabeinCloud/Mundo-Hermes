[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Import-Module (Join-Path $Root 'src\HermesManager.psm1') -Force
$env:HERMES_MANAGER_LANGUAGE = 'en'

$aliases = @(Get-HermesAgents -Root $Root | Where-Object { $_.TerminalAlias })
if (-not $aliases.Count) {
    throw 'No aliases are configured. Open Hermes Manager and use option A.'
}

$added = Install-HermesAliasPath -Root $Root
$binPath = Get-HermesBinPath -Root $Root
$userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
if (@($userPath -split ';' | Where-Object { $_.TrimEnd('\').Equals($binPath, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) {
    throw "Could not add $binPath to the user PATH."
}

Write-Host
Write-Host 'GLOBAL ALIASES ENABLED' -ForegroundColor Green
Write-Host "Path: $binPath"
Write-Host 'Available:'
foreach ($agent in $aliases | Sort-Object TerminalAlias) {
    Write-Host ("  {0}  ->  {1}" -f $agent.TerminalAlias, $agent.DisplayName)
}
Write-Host
if ($added) {
    Write-Host 'Open a new terminal before using them.' -ForegroundColor Yellow
} else {
    Write-Host 'The path was already registered. Open a new terminal to use them.'
}
