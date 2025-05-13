[DscResource()]
class nxScript {
    [DscProperty()]
    [ValidateSet("PowerShell", "Bash")]
    [System.String] $ScriptType = "PowerShell"

    [DscProperty()]
    [System.String] $GetScript

    [DscProperty(Key)]
    [System.String] $TestScript

    [DscProperty()]
    [System.String] $SetScript

    [DscProperty()]
    [Reason[]] $Reasons

    [nxScript] Get() {
        if ([string]::IsNullOrEmpty($this.GetScript)) {
            $Reason = [Reason]::new()
            $Reason.Code = "Script:Script:GetScriptNotDefined"
            $Reason.Phrase = "Cannot determine reason for non-compliance. Please define Reasons in the hashtable returned from the GetScript script block to return reasons for non-compliance."
            $this.Reasons = @($Reason)
            return $this
        }
        if ($this.ScriptType -eq 'PowerShell') {
            $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($this.GetScript)
            $invokeScriptResult = $this.InvokeScript($scriptBlock)
            if ($invokeScriptResult -is [System.Management.Automation.ErrorRecord]) {
                throw "The GetScript script block returned an error: $invokeScriptResult."
            }

            $isValid = $this.TestGetScriptOutput($invokeScriptResult)
            if (-not $isValid) {
                throw "The GetScript script block must return a hashtable that contains a non-empty list of Reason objects under the Reasons key."
            }

            $this.Reasons = $invokeScriptResult.Reasons
            return $this
        }
        elseif ($this.ScriptType -eq 'Bash') {
            $CurrentState = [nxScript]::new()
            #write-verbose "executing the get script"
            $rnd = Get-Random -Minimum 100 -Maximum 999
            "$($this.getscript)" | out-file "\tmp\getscript$rnd$(".sh")" -force
            Set-Location \tmp
            $res = Invoke-Expression "sudo sh getscript$rnd.sh" | out-null 
            Remove-Item "\tmp\getscript$rnd$(".sh")" -force
            $CurrentState.ConfigurationScope = $this.ConfigurationScope
            $this.CachedCurrentState = $CurrentState
            return $CurrentState
        }
    }

    [bool] Test() {
        if ($this.ScriptType -eq 'PowerShell') {
            $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($this.TestScript)
            $invokeScriptResult = $this.InvokeScript($scriptBlock)
            if ($invokeScriptResult -is [System.Management.Automation.ErrorRecord]) {
                throw "The TestScript script block returned an error: $invokeScriptResult."
            }

            if ($null -eq $invokeScriptResult -or -not ($invokeScriptResult -is [System.Boolean])) {
                throw "The TestScript script block must return a Boolean."
            }

            return $invokeScriptResult
        }
        elseif ($this.ScriptType -eq 'Bash') {
            $rnd = Get-Random -Minimum 100 -Maximum 999
            "$($this.testscript)" | out-file "\tmp\testscript$rnd$(".sh")" -force
            Set-Location \tmp
            [int]$res = Invoke-Expression "sudo sh testscript$rnd.sh"
            Remove-Item "\tmp\testscript$rnd$(".sh")" -force
            return $res
        }
        else {
            throw "Unsupported script type: $($this.ScriptType). Supported types are 'PowerShell' and 'Bash'."
        }
    }

    [void] Set() {
        if ([string]::IsNullOrEmpty($this.SetScript)) {
            # The SetScript script block was not defined
            return
        }
        if ($this.ScriptType -eq 'PowerShell') {
            $scriptBlock = [System.Management.Automation.ScriptBlock]::Create($this.SetScript)
            $null = $this.InvokeScript($scriptBlock)
        }
        elseif ($this.ScriptType -eq 'Bash') {
            $rnd = Get-Random -Minimum 100 -Maximum 999
            "$($this.SetScript)" | out-file "\tmp\setscript$rnd$(".sh")" -force
            Set-Location \tmp
            [int]$res = Invoke-Expression "sudo sh setscript$rnd.sh" | out-null
            Remove-Item "\tmp\setscript$rnd$(".sh")" -force
        }
        else {
            throw "Unsupported script type: $($this.ScriptType). Supported types are 'PowerShell' and 'Bash'."
        }
        
    }

    [System.Object] InvokeScript([System.Management.Automation.ScriptBlock] $ScriptBlock) {
        $scriptResult = $null
        try {
            $scriptResult = & $ScriptBlock
        }
        catch {
            # Surfacing the error thrown by the execution of the script
            $scriptResult = $_
        }

        return $scriptResult
    }

    [bool] TestGetScriptOutput([System.Object] $GetScriptOutput) {
        if ($GetScriptOutput -isnot [System.Collections.Hashtable]) {
            Write-Verbose -Message "The GetScript script block must return a hashtable"
            return $false
        }

        if (-not $GetScriptOutput.ContainsKey("Reasons")) {
            Write-Verbose -Message "The hashtable returned by GetScript does not contain a Reasons key"
            return $false
        }

        $outputReasons = $GetScriptOutput["Reasons"]
        if ($outputReasons.Count -eq 0) {
            Write-Verbose -Message "The Reasons list returned by GetScript is empty"
            return $false
        }

        foreach ($outputReason in $outputReasons) {
            if ($outputReason -isnot [Reason]) {
                Write-Verbose -Message "One of the Reasons returned by GetScript is not a Reason object"
                return $false
            }
        }

        return $true
    }
}
