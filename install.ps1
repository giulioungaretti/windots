winget install JanDeDobbeleer.OhMyPosh --source winget
winget install junegunn.fzf

$githubAliases = [ordered]@{
	personal = 'auth switch --user giulioungaretti'
	demo     = 'auth switch --user gungaretti_MSDEMO'
	work     = 'auth switch --user gungaretti_microsoft'
}
foreach ($alias in $githubAliases.GetEnumerator()) {
	gh alias set $alias.Key $alias.Value --clobber
	if ($LASTEXITCODE -ne 0) {
		throw "Failed to configure the GitHub CLI alias '$($alias.Key)'."
	}
}

$binDir = Join-Path $PSScriptRoot 'bin'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$userPathEntries = @($userPath -split [System.IO.Path]::PathSeparator | Where-Object { $_ })
if ($userPathEntries -notcontains $binDir) {
	[Environment]::SetEnvironmentVariable(
		'Path',
		(@($binDir) + $userPathEntries) -join [System.IO.Path]::PathSeparator,
		'User'
	)
}

# Keep PSFzf and git-completion in a repo-local Modules folder (gitignored)
# instead of OneDrive. profile.ps1 prepends this folder to PSModulePath, so
# startup no longer pays the OneDrive placeholder-hydration cost.
$modulesDir = Join-Path $PSScriptRoot 'Modules'
New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null
Save-Module -Name PSFzf          -Path $modulesDir -Force
Save-Module -Name git-completion -Path $modulesDir -Force

$repoProfilePath = Resolve-Path (Join-Path $PSScriptRoot 'profile.ps1')
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
	New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

@(
	". '$repoProfilePath'"
	'if ($env:TERM_PROGRAM -eq "vscode") { . "$(code --locate-shell-integration-path pwsh)" }'
) | Set-Content -Path $PROFILE -Force
