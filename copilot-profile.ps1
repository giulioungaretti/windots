param(
	[Parameter(Mandatory, Position = 0)]
	[ValidateSet('personal', 'demo', 'work', 'agency')]
	[string] $Profile,

	[string[]] $CopilotArguments = @()
)

$ErrorActionPreference = 'Stop'

$profilesRoot = Join-Path $HOME '.copilot-profiles'
$profiles = @{
	personal = @{
		User       = 'giulioungaretti'
		Home       = Join-Path $profilesRoot 'giulioungaretti'
		Executable = 'copilot.exe'
		Prefix     = @()
		Vault27    = $true
	}
	demo = @{
		User       = 'gungaretti_MSDEMO'
		Home       = Join-Path $profilesRoot 'gungaretti_MSDEMO'
		Executable = 'copilot.exe'
		Prefix     = @()
		Vault27    = $false
	}
	work = @{
		User       = 'gungaretti_microsoft'
		Home       = Join-Path $profilesRoot 'gungaretti_microsoft'
		Executable = 'copilot.exe'
		Prefix     = @()
		Vault27    = $true
	}
	agency = @{
		User       = 'gungaretti_microsoft'
		Home       = Join-Path $HOME '.copilot'
		Executable = 'agency.exe'
		Prefix     = @('copilot')
		Vault27    = $false
	}
}

$selected = $profiles[$Profile]
New-Item -ItemType Directory -Path $selected.Home -Force | Out-Null

$vaultRoot = $null
$managedArguments = @()
if ($selected.Vault27) {
	$candidates = if ([string]::IsNullOrWhiteSpace($env:VAULT27_ROOT)) {
		@(
			(Join-Path $HOME 'vault27'),
			(Join-Path $HOME 'Vault27')
		)
	}
	else {
		@($env:VAULT27_ROOT)
	}

	$vaultRoot = $candidates |
		Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
		Select-Object -First 1
	if ([string]::IsNullOrWhiteSpace($vaultRoot)) {
		throw "Vault27 was not found. Set VAULT27_ROOT to the vault directory."
	}

	$vaultRoot = [System.IO.Path]::GetFullPath($vaultRoot)
	$vaultPlugin = Join-Path $vaultRoot '.github\plugins\vault27'
	if (-not (Test-Path -LiteralPath (Join-Path $vaultPlugin 'plugin.json') -PathType Leaf)) {
		throw "Vault27 plugin manifest was not found at '$vaultPlugin'."
	}

	$managedArguments = @(
		'--plugin-dir', $vaultPlugin,
		'--add-dir', $vaultRoot
	)
}

$token = (& gh.exe auth token --user $selected.User)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
	throw "Could not get a GitHub token for '$($selected.User)'. Run 'gh auth login' for that account."
}

$previousEnvironment = @{}
function Set-ScopedEnvironmentVariable {
	param(
		[Parameter(Mandatory)]
		[string] $Name,

		[AllowEmptyString()]
		[string] $Value
	)

	$current = Get-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue
	$previousEnvironment[$Name] = @{
		Exists = $null -ne $current
		Value  = if ($null -ne $current) { $current.Value } else { $null }
	}
	Set-Item -LiteralPath "Env:$Name" -Value $Value
}

Set-ScopedEnvironmentVariable -Name 'COPILOT_HOME' -Value $selected.Home
Set-ScopedEnvironmentVariable -Name 'COPILOT_GITHUB_TOKEN' -Value $token.Trim()
Set-ScopedEnvironmentVariable -Name 'GH_TOKEN' -Value $token.Trim()
if ($selected.Vault27) {
	Set-ScopedEnvironmentVariable -Name 'VAULT27_ROOT' -Value $vaultRoot
}
if ($Profile -eq 'agency') {
	Set-ScopedEnvironmentVariable -Name 'AGENCY_GITHUB_TOKEN' -Value $token.Trim()
	Set-ScopedEnvironmentVariable -Name 'GITHUB_TOKEN' -Value $token.Trim()
}

# Make child git processes use the same explicit GitHub identity as Copilot.
$gitConfigCount = 0
if ($env:GIT_CONFIG_COUNT) {
	$parsedCount = 0
	if ([int]::TryParse($env:GIT_CONFIG_COUNT, [ref] $parsedCount)) {
		$gitConfigCount = $parsedCount
	}
}

Set-ScopedEnvironmentVariable -Name "GIT_CONFIG_KEY_$gitConfigCount" -Value 'credential.https://github.com.helper'
Set-ScopedEnvironmentVariable -Name "GIT_CONFIG_VALUE_$gitConfigCount" -Value ''
Set-ScopedEnvironmentVariable -Name "GIT_CONFIG_KEY_$($gitConfigCount + 1)" -Value 'credential.https://github.com.helper'
Set-ScopedEnvironmentVariable -Name "GIT_CONFIG_VALUE_$($gitConfigCount + 1)" -Value '!gh auth git-credential'
Set-ScopedEnvironmentVariable -Name 'GIT_CONFIG_COUNT' -Value ($gitConfigCount + 2).ToString()

Write-Host "Launching $Profile Copilot as $($selected.User)"
Write-Host "COPILOT_HOME=$($selected.Home)"
if ($selected.Vault27) {
	Write-Host "VAULT27_ROOT=$vaultRoot"
}

$exitCode = 1
try {
	$commandArguments = @($selected.Prefix) + @($managedArguments) + @($CopilotArguments)
	& $selected.Executable @commandArguments
	$exitCode = $LASTEXITCODE
}
finally {
	foreach ($name in $previousEnvironment.Keys) {
		$previous = $previousEnvironment[$name]
		if ($previous.Exists) {
			Set-Item -LiteralPath "Env:$name" -Value $previous.Value
		}
		else {
			Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
		}
	}
}

exit $exitCode
