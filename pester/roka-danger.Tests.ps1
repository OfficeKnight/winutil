#===========================================================================
# Tests - RoKa Edition danger list
#===========================================================================

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    . (Join-Path $script:repoRoot "functions\roka\Get-WinUtilDangerReason.ps1")
    . (Join-Path $script:repoRoot "functions\roka\Confirm-WinUtilDangerSelection.ps1")
    . (Join-Path $script:repoRoot "functions\private\Update-WinUtilSelections.ps1")
    . (Join-Path $script:repoRoot "functions\private\Get-WinUtilTweakDisplayName.ps1")
    . (Join-Path $script:repoRoot "functions\public\Invoke-WPFtweaksbutton.ps1")

    function Write-WinUtilLog {
        param($Level, $Component, $Message)
    }
    function Show-WinUtilMessage {
        param($Message, $Title, $Button, $Icon)
    }
    function Start-WinUtilJob {
        param($Name, $Description, [switch]$QueueIfBusy, $Parameters, $ScriptBlock)
    }

    function script:Get-RokaConfig {
        param([string]$Name)

        Get-Content -Path (Join-Path $script:repoRoot "config\$Name.json") -Raw | ConvertFrom-Json
    }

    function script:New-RokaSync {
        $script:sync = [Hashtable]::Synchronized(@{
            selectedApps     = [System.Collections.Generic.List[string]]::new()
            selectedTweaks   = [System.Collections.Generic.List[string]]::new()
            selectedToggles  = [System.Collections.Generic.List[string]]::new()
            selectedFeatures = [System.Collections.Generic.List[string]]::new()
            selectedAppx     = [System.Collections.Generic.List[string]]::new()
            WPFchangedns     = [pscustomobject]@{ text = "Default" }
            configs          = @{
                applicationsHashtable = @{}
                appxHashtable         = @{}
                feature               = [pscustomobject]@{}
                tweaks                = [pscustomobject]@{
                    WPFTweaksTelemetry  = [pscustomobject]@{ Content = "Telemetry - Disable" }
                    WPFTweaksRemoveEdge = [pscustomobject]@{ Content = "Microsoft Edge - Remove" }
                }
                rokadanger            = [pscustomobject]@{
                    WPFTweaksRemoveEdge = [pscustomobject]@{ Reason = "Breaks things." }
                }
            }
        })
    }
}

AfterAll {
    Remove-Variable -Name sync -Scope Script -ErrorAction SilentlyContinue
}

Describe "config/rokadanger.json" {
    BeforeAll {
        $script:danger = Get-RokaConfig -Name "rokadanger"
        $script:tweaks = Get-RokaConfig -Name "tweaks"
        $script:xaml = Get-Content -Path (Join-Path $script:repoRoot "xaml\inputXML.xaml") -Raw
    }

    It "lists at least one entry" {
        @($script:danger.PSObject.Properties).Count | Should -BeGreaterThan 0
    }

    It "gives every entry a reason" {
        foreach ($entry in $script:danger.PSObject.Properties) {
            [string]$entry.Value.Reason | Should -Not -BeNullOrEmpty -Because "$($entry.Name) is shown to the user with its reason"
        }
    }

    It "only names tweaks or controls that exist" {
        foreach ($entry in $script:danger.PSObject.Properties) {
            $isTweak = $null -ne $script:tweaks.PSObject.Properties[$entry.Name]
            $isControl = $script:xaml -match "Name=`"$([regex]::Escape($entry.Name))`""
            ($isTweak -or $isControl) | Should -BeTrue -Because "$($entry.Name) has to match a tweak key or a named control"
        }
    }
}

Describe "Get-WinUtilDangerReason" {
    BeforeEach {
        New-RokaSync
    }

    It "returns the reason for a danger-listed key, whatever its casing" {
        Get-WinUtilDangerReason -Key "WPFTweaksRemoveEdge" | Should -Be "Breaks things."
        Get-WinUtilDangerReason -Key "wpftweaksremoveedge" | Should -Be "Breaks things."
    }

    It "returns nothing for other keys and when there is no danger list" {
        Get-WinUtilDangerReason -Key "WPFTweaksTelemetry" | Should -BeNullOrEmpty

        $script:sync.configs.Remove("rokadanger")
        Get-WinUtilDangerReason -Key "WPFTweaksRemoveEdge" | Should -BeNullOrEmpty
    }
}

Describe "Update-WinUtilSelections with a danger list" {
    BeforeEach {
        New-RokaSync
        Mock Write-WinUtilLog { }
    }

    It "leaves a danger-listed entry out and keeps the rest" {
        Update-WinUtilSelections -flatJson @("WPFTweaksTelemetry", "WPFTweaksRemoveEdge") -Replace

        $script:sync.selectedTweaks | Should -Contain "WPFTweaksTelemetry"
        $script:sync.selectedTweaks | Should -Not -Contain "WPFTweaksRemoveEdge"
        Should -Invoke -CommandName Write-WinUtilLog -Times 1 -Exactly -ParameterFilter {
            $Level -eq "WARN" -and $Message -match "WPFTweaksRemoveEdge"
        }
    }

    It "does not report a danger-listed entry as unknown" {
        $skipped = @(Update-WinUtilSelections -flatJson @("WPFTweaksTelemetry", "WPFTweaksRemoveEdge") -SkipUnknown)

        $skipped | Should -BeNullOrEmpty
        $script:sync.selectedTweaks | Should -Not -Contain "WPFTweaksRemoveEdge"
    }

    It "keeps every shipped preset free of danger-listed entries" {
        $script:sync.configs.tweaks = Get-RokaConfig -Name "tweaks"
        $script:sync.configs.rokadanger = Get-RokaConfig -Name "rokadanger"
        $presets = Get-RokaConfig -Name "preset"

        foreach ($preset in $presets.PSObject.Properties | Where-Object { $_.Name -ne "AppxDefault" }) {
            Update-WinUtilSelections -flatJson @($preset.Value) -Replace

            foreach ($key in $script:sync.selectedTweaks) {
                Get-WinUtilDangerReason -Key $key | Should -BeNullOrEmpty -Because "preset $($preset.Name) must not select $key"
            }
        }
    }
}

Describe "Confirm-WinUtilDangerSelection" {
    BeforeEach {
        New-RokaSync
        Mock Write-WinUtilLog { }
    }

    It "goes ahead without asking when nothing is danger-listed" {
        Mock Show-WinUtilMessage { "Cancel" }

        $decision = Confirm-WinUtilDangerSelection -Keys @("WPFTweaksTelemetry")

        $decision.Proceed | Should -BeTrue
        $decision.Keys | Should -Be @("WPFTweaksTelemetry")
        Should -Invoke -CommandName Show-WinUtilMessage -Times 0 -Exactly
    }

    It "names the entry and its reason when asking" {
        Mock Show-WinUtilMessage { "Cancel" }

        Confirm-WinUtilDangerSelection -Keys @("WPFTweaksRemoveEdge") | Out-Null

        Should -Invoke -CommandName Show-WinUtilMessage -Times 1 -Exactly -ParameterFilter {
            $Button -eq "YesNoCancel" -and $Message -match "Microsoft Edge - Remove" -and $Message -match "Breaks things\."
        }
    }

    It "keeps everything on Yes" {
        Mock Show-WinUtilMessage { "Yes" }

        $decision = Confirm-WinUtilDangerSelection -Keys @("WPFTweaksTelemetry", "WPFTweaksRemoveEdge")

        $decision.Proceed | Should -BeTrue
        $decision.Keys | Should -Be @("WPFTweaksTelemetry", "WPFTweaksRemoveEdge")
    }

    It "drops the danger-listed entries on No, which is also what a run without a window answers" {
        Mock Show-WinUtilMessage { "No" }

        $decision = Confirm-WinUtilDangerSelection -Keys @("WPFTweaksTelemetry", "WPFTweaksRemoveEdge")

        $decision.Proceed | Should -BeTrue
        $decision.Keys | Should -Be @("WPFTweaksTelemetry")
    }

    It "stops the run on Cancel" {
        Mock Show-WinUtilMessage { "Cancel" }

        $decision = Confirm-WinUtilDangerSelection -Keys @("WPFTweaksTelemetry", "WPFTweaksRemoveEdge")

        $decision.Proceed | Should -BeFalse
    }
}

Describe "Invoke-WPFtweaksbutton with a danger list" {
    BeforeEach {
        New-RokaSync
        $script:sync.selectedTweaks.Add("WPFTweaksTelemetry")
        $script:sync.selectedTweaks.Add("WPFTweaksRemoveEdge")
        $script:capturedParameters = $null

        Mock Write-WinUtilLog { }
        Mock Start-WinUtilJob { $script:capturedParameters = $Parameters }
    }

    It "starts no job when the confirmation is cancelled" {
        Mock Show-WinUtilMessage { "Cancel" }

        Invoke-WPFtweaksbutton

        Should -Invoke -CommandName Start-WinUtilJob -Times 0 -Exactly
    }

    It "runs only the remaining tweaks when the danger-listed ones are declined" {
        Mock Show-WinUtilMessage { "No" }

        Invoke-WPFtweaksbutton

        Should -Invoke -CommandName Start-WinUtilJob -Times 1 -Exactly
        $script:capturedParameters.Tweaks | Should -Be @("WPFTweaksTelemetry")
    }

    It "runs everything once the danger-listed tweaks are confirmed" {
        Mock Show-WinUtilMessage { "Yes" }

        Invoke-WPFtweaksbutton

        $script:capturedParameters.Tweaks | Should -Be @("WPFTweaksTelemetry", "WPFTweaksRemoveEdge")
    }

    It "starts no job when declining leaves nothing to do" {
        Mock Show-WinUtilMessage { "No" }
        $script:sync.selectedTweaks.Remove("WPFTweaksTelemetry") | Out-Null

        Invoke-WPFtweaksbutton

        Should -Invoke -CommandName Start-WinUtilJob -Times 0 -Exactly
    }
}

Describe "Danger list wiring" {
    It "marks the danger-listed controls after a tab is built" {
        $tabScript = Get-Content -Path (Join-Path $script:repoRoot "functions\private\Initialize-WinUtilTabContent.ps1") -Raw

        $tabScript | Should -Match 'Set-WinUtilDangerHighlight'
    }

    It "ships the highlight function with the compiled script" {
        Join-Path $script:repoRoot "functions\roka\Set-WinUtilDangerHighlight.ps1" | Should -Exist
    }
}
