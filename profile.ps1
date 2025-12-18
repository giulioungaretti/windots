if ($host.Name -eq 'ConsoleHost') {
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

	oh-my-posh init pwsh --config C:\Users\gungaretti\sources\repos\PS\robbyrussell.json | Invoke-Expression
	Remove-PSReadlineKeyHandler 'Ctrl+r'
	Import-Module PSFzf
	#replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
	Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'



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
}

New-Alias codi code-insiders