if ($host.Name -eq 'ConsoleHost') {
	# Use the modules vendored in this repo (off OneDrive, version-controlled)
	# so startup doesn't pay the OneDrive placeholder-hydration cost.
	$env:PSModulePath = (Join-Path $PSScriptRoot 'Modules') + [System.IO.Path]::PathSeparator + $env:PSModulePath

	Import-Module PSReadLine
	Set-PSReadLineOption -EditMode vi

	# Function to detect if running under automation (GitHub Copilot, etc.)
	# This prevents automation tools from polluting command history
	function Test-IsAutomatedSession {
		try {
			$currentProcess = Get-Process -Id $PID -ErrorAction Stop
			
			# Check if parent exists
			if ($null -eq $currentProcess.Parent) {
				return $false
			}
			
			$parentProcess = Get-Process -Id $currentProcess.Parent.Id -ErrorAction Stop
			$parentName = $parentProcess.ProcessName
			
			# Check for known automation parent processes
			# winpty-agent: Used by GitHub Copilot CLI and similar tools
			# conhost: Sometimes used by automation without a proper terminal
			# Note: We don't exclude 'Code' (VSCode) to maintain shell integration
			$automationProcesses = @('winpty-agent', 'node')
			
			# Additional check: if parent is node, check its command line for copilot indicators
			if ($parentName -eq 'node') {
				try {
					$parentCommandLine = $parentProcess.CommandLine
					if ($null -ne $parentCommandLine -and $parentCommandLine -match 'copilot|github.*cli') {
						return $true
					}
				}
				catch {
					# CommandLine may be inaccessible due to security restrictions
					# Continue with basic name check
				}
			}
			
			return $automationProcesses -contains $parentName
		}
		catch {
			# If we can't determine, assume it's a human session (safer default)
			return $false
		}
	}

	# Configure history handler to exclude commands from automated sessions
	Set-PSReadLineOption -AddToHistoryHandler {
		param($command)
		
		# Always exclude commands that start with space (common convention)
		if ($command -match '^\s') {
			return $false
		}
		
		# Exclude sensitive commands (those containing passwords, secrets, etc.)
		# Use case-insensitive matching to catch all variations
		if ($command -imatch 'password|secret|apikey|token') {
			return $false
		}
		
		# Exclude commands from automated sessions (Copilot, etc.)
		if (Test-IsAutomatedSession) {
			return $false
		}
		
		# Add everything else to history
		return $true
	}



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

	# --- Lazy load of oh-my-posh (git repo OR sustained idle) -----------------
	# oh-my-posh's init costs ~900ms, but the placeholder prompt below is
	# pixel-identical to its base prompt -- so for plain (non-git) directories
	# there is nothing to gain by paying that cost. We stay on the instant
	# placeholder and only swap in the real oh-my-posh when it actually adds
	# something: when you enter a Git repo (for the branch segment), OR after
	# the shell has sat idle at the prompt for a few seconds (so a long-lived
	# shell eventually gains full fidelity incl. the status segment for free).
	# Idea: https://matt.kotsenas.com/posts/pwsh-profiling-async-startup/
	$global:__ompConfig      = Join-Path $PSScriptRoot 'robbyrussell.json'
	$global:__ompLoad        = $false                              # load request flag
	$global:__ompIdleSeconds = 3                                   # idle delay before auto-load
	$global:__ompIdleSw      = [System.Diagnostics.Stopwatch]::StartNew()

	# Instant placeholder prompt, shown until oh-my-posh takes over.
	# Pixel-identical to the robbyrussell theme's base prompt: green arrow
	# (#98C379), then the cyan (#56B6C2) folder-style path (~ at home, else the
	# leaf folder), then a trailing space. While it renders it (a) requests the
	# real prompt the moment we're inside a Git repo via a cheap upward .git
	# walk (no git.exe), and (b) restarts the idle timer so the auto-load only
	# fires after genuine inactivity.
	function global:prompt {
		$e = [char]0x1b
		$p = $executionContext.SessionState.Path.CurrentLocation.ProviderPath
		if ($p -eq $HOME) { $leaf = '~' }
		else { $leaf = Split-Path $p -Leaf; if (-not $leaf) { $leaf = $p } }

		if (-not $global:__ompLoad) {
			$dir = $p
			while ($dir) {
				if (Test-Path -LiteralPath (Join-Path $dir '.git')) { $global:__ompLoad = $true; break }
				$dir = Split-Path $dir -Parent
			}
		}

		$global:__ompIdleSw.Restart()
		"$e[38;2;152;195;121m➜$e[0m  $e[38;2;86;182;194m$leaf$e[0m "
	}

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
}

Set-Alias codi code-insiders