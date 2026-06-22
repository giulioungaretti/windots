winget install JanDeDobbeleer.OhMyPosh --source winget
winget install junegunn.fzf

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
