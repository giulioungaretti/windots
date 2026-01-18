if ($host.Name -eq 'ConsoleHost') {
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

	oh-my-posh init pwsh --config C:\Users\gungaretti\sources\repos\PS\robbyrussell.json | Invoke-Expression
	Remove-PSReadlineKeyHandler 'Ctrl+r'
	Import-Module PSFzf
	#replace 'Ctrl+t' and 'Ctrl+r' with your preferred bindings:
	Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
	# git autcompletion source
	Import-Module git-completion

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