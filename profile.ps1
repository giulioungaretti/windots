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

	# Feedback provider (PS 7.4+) colors. The default FeedbackAction is bright
	# white (\e[97m) -- the suggested-command list is then washed out / unreadable
	# on light terminal backgrounds. Use the theme's accent blue (#5FAAE8) which
	# has contrast on both light and dark backgrounds.
	if ($PSStyle -and $PSStyle.Formatting.PSObject.Properties['FeedbackAction']) {
		$PSStyle.Formatting.FeedbackAction = "$([char]0x1b)[38;2;95;170;232m"
	}

	# --- oh-my-posh DISABLED (favoring a fast shell; use the `git` CLI for status)
	# The lazy oh-my-posh loader still cost noticeable startup/idle time, so it is
	# turned off for now. We keep only the instant placeholder prompt below (green
	# arrow + cyan folder), which is pixel-identical to the robbyrussell base
	# prompt -- just without the git/status segments. To re-enable, restore the
	# prompt's .git/idle detection and uncomment the init + OnIdle block below.
	# Idea: https://matt.kotsenas.com/posts/pwsh-profiling-async-startup/

	# Fast, self-contained prompt: green arrow (#98C379) + cyan (#56B6C2)
	# folder-style path (~ at home, else the leaf folder) + a trailing space.
	function global:prompt {
		$e = [char]0x1b
		$p = $executionContext.SessionState.Path.CurrentLocation.ProviderPath
		if ($p -eq $HOME) { $leaf = '~' }
		else { $leaf = Split-Path $p -Leaf; if (-not $leaf) { $leaf = $p } }

		"$e[38;2;152;195;121m➜$e[0m  $e[38;2;86;182;194m$leaf$e[0m "
	}

	<#  DISABLED -- oh-my-posh lazy init + git-completion + OnIdle auto-load.
	# The actual (slow) oh-my-posh init, plus a wrapper that lazily imports
	# git-completion (~1.7s) the first time we're inside a Git repo. Loaded as
	# -Global modules so they survive the idle event's job scope.
	$global:__ompInit = {
		oh-my-posh init pwsh --config $global:__ompConfig | Invoke-Expression

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
	}

	# Each idle tick (~every 0.3s) is cheap: just check the two triggers. When
	# one fires, load oh-my-posh once, re-render, self-unregister, and clean up.
	Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
		if ($global:__ompLoad -or $global:__ompIdleSw.Elapsed.TotalSeconds -ge $global:__ompIdleSeconds) {
			& $global:__ompInit
			Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
			[Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
			Remove-Variable -Name '__ompInit','__ompLoad','__ompIdleSeconds','__ompIdleSw' -Scope Global -Force -ErrorAction SilentlyContinue
		}
	}
	#>
}

Set-Alias codi code-insiders