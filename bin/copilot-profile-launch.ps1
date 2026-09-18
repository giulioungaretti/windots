$ErrorActionPreference = 'Stop'

if ($args.Count -lt 1) {
	throw 'A Copilot profile name is required.'
}

$profile = $args[0]
$copilotArguments = if ($args.Count -gt 1) {
	@($args[1..($args.Count - 1)])
}
else {
	@()
}

$profileScript = [System.IO.Path]::GetFullPath(
	(Join-Path $PSScriptRoot '..\copilot-profile.ps1')
)
& $profileScript -Profile $profile -CopilotArguments $copilotArguments
exit $LASTEXITCODE
