if ($host.Name -eq 'ConsoleHost') {
	# Use the modules vendored in this repo (off OneDrive, version-controlled)
	# so startup doesn't pay the OneDrive placeholder-hydration cost.
	$env:PSModulePath = (Join-Path $PSScriptRoot 'Modules') + [System.IO.Path]::PathSeparator + $env:PSModulePath

	Import-Module PSReadLine
	Set-PSReadLineOption -EditMode vi



	# Tell PSReadLine we want to run a script when mode changes
	Set-PSReadLineOption -ViModeIndicator Script

	# Define the mode change handler
	Set-PSReadLineOption -ViModeChangeHandler {
		param($mode)

		switch ($mode) {
			'Command' {
				# Steady block cursor
				Write-Host -NoNewline "`e[2 q"
			}
			'Insert' {
				# Steady bar (line) cursor
				Write-Host -NoNewline "`e[6 q"
			}
			default {
				# Fallback to steady bar
				Write-Host -NoNewline "`e[6 q"
			}
		}
	}

	oh-my-posh init pwsh --config (Join-Path $PSScriptRoot 'robbyrussell.json') | Invoke-Expression

	Remove-PSReadlineKeyHandler 'Ctrl+r'
	Import-Module PSFzf
	#replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
	Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

	# Tab completion as menu
	Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete

	# colors that work in light and dark backgrounds
	Set-PSReadLineOption -Colors @{
		ContinuationPrompt = "$([char]0x1b)[39m"      # default foreground
		Default            = "$([char]0x1b)[39m"      # plain text
		Type               = "$([char]0x1b)[39m"      # type names
		Selection          = "$([char]0x1b)[39;49;7m" # inverse (swap fg/bg)
		Command            = "$([char]0x1b)[33m"      # yellow for commands
		Member             = "$([char]0x1b)[39m"      # .member names
		Number             = "$([char]0x1b)[38;5;242m"# ANSI 256-color gray
	}

	# Lazy-load git-completion the first time we step into a Git repo (it's the
	# single most expensive import, ~1.7s). Wrap oh-my-posh's prompt: run it
	# first so $? / $LASTEXITCODE stay intact for the status segment, then do a
	# cheap upward .git walk (no git.exe) and stop checking once loaded.
	$global:__ompPrompt = (Get-Item function:prompt).ScriptBlock
	$global:__gitCompletionLoaded = $false
	function global:prompt {
		$out = & $global:__ompPrompt
		if (-not $global:__gitCompletionLoaded) {
			$dir = $PWD.ProviderPath
			while ($dir) {
				if (Test-Path -LiteralPath (Join-Path $dir '.git')) {
					Import-Module git-completion -ErrorAction SilentlyContinue
					$global:__gitCompletionLoaded = $true
					break
				}
				$dir = Split-Path $dir -Parent
			}
		}
		$out
	}
}

New-Alias codi code-insiders