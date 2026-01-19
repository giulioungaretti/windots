winget install JanDeDobbeleer.OhMyPosh --source winget
winget install junegunn.fzf 
Install-Module PSFzf -Scope CurrentUser
Install-Module git-completion -Scope CurrentUser

$repoProfilePath = Resolve-Path (Join-Path $PSScriptRoot 'profile.ps1')
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
	New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

@(
	". '$repoProfilePath'"
	'if ($env:TERM_PROGRAM -eq "vscode") { . "$(code --locate-shell-integration-path pwsh)" }'
) | Set-Content -Path $PROFILE -Force
