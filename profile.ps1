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

	Remove-PSReadlineKeyHandler 'Ctrl+r'

	# Lazy-load PSFzf on first use of its chords (saves ~0.5s at startup). The
	# first Ctrl+t / Ctrl+r imports it, wires the real bindings, then runs.
	$global:__psfzfLoaded = $false
	function global:Initialize-PSFzfLazy {
		if ($global:__psfzfLoaded) { return }
		Import-Module PSFzf
		Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
		$global:__psfzfLoaded = $true
	}
	Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock { Initialize-PSFzfLazy; Invoke-FzfPsReadlineHandlerProvider }
	Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock { Initialize-PSFzfLazy; Invoke-FzfPsReadlineHandlerHistory }

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

	# --- Deferred (async) load of oh-my-posh ----------------------------------
	# oh-my-posh's init costs ~900ms. Instead of paying that before the first
	# prompt, show an instant placeholder prompt and load oh-my-posh on the
	# first idle tick -- after the shell is already interactive -- then
	# re-render. Technique:
	# https://matt.kotsenas.com/posts/pwsh-profiling-async-startup/
	$global:__ompConfig = Join-Path $PSScriptRoot 'robbyrussell.json'

	# Instant placeholder prompt, shown only until oh-my-posh finishes loading.
	function global:prompt {
		"$([char]0x1b)[38;5;242m➜$([char]0x1b)[0m  $($executionContext.SessionState.Path.CurrentLocation) "
	}

	# On the first idle tick (shell already interactive) load oh-my-posh, then
	# re-render once. -MaxTriggerCount 1 auto-unregisters so this runs exactly
	# once -- a single placeholder -> real transition, no redundant re-render.
	# The work is loaded as a -Global module so it survives the event's job
	# scope and overrides the placeholder prompt.
	Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -MaxTriggerCount 1 -Action {
		oh-my-posh init pwsh --config $global:__ompConfig | Invoke-Expression

		# Wrap oh-my-posh's freshly-defined prompt so git-completion (the most
		# expensive import, ~1.7s) loads lazily the first time we're inside a
		# Git repo. Capture omp's prompt first, then export our wrapper.
		$global:__ompPrompt = (Get-Item function:prompt).ScriptBlock
		$global:__gitCompletionLoaded = $false
		New-Module -Name git-completion-lazy-prompt -ScriptBlock {
			function prompt {
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
		} | Import-Module -Global

		# Re-render now that the real prompt is loaded, so it shows immediately.
		[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
	}
}

Set-Alias codi code-insiders