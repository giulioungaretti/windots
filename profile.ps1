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

	# oh-my-posh: dot-source a cached copy of its init script instead of spawning
	# the (WindowsApps-aliased, ~370ms) binary every launch. Regenerate the cache
	# only when the binary or theme changes -- filesystem stat only, no spawn.
	$ompTheme = Join-Path $PSScriptRoot 'robbyrussell.json'
	$ompCache = Join-Path $PSScriptRoot '.omp-init.ps1'
	$ompExe   = (Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
	$ompFresh = $ompExe -and (Test-Path $ompCache) -and
		((Get-Item $ompCache).LastWriteTimeUtc -ge (Get-Item $ompExe).LastWriteTimeUtc) -and
		((Get-Item $ompCache).LastWriteTimeUtc -ge (Get-Item $ompTheme).LastWriteTimeUtc)
	if (-not $ompFresh) {
		oh-my-posh init pwsh --config $ompTheme --print | Out-File -Encoding utf8 $ompCache
	}
	. $ompCache
	# The cached script bakes in a fixed POSH_SESSION_ID; give each shell a fresh one.
	$env:POSH_SESSION_ID = [guid]::NewGuid().ToString()

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

Set-Alias codi code-insiders