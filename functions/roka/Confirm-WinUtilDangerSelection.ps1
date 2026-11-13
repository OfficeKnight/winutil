function Confirm-WinUtilDangerSelection {
    <#
    .SYNOPSIS
        Asks before danger-listed entries are applied and returns the keys that may run

    .DESCRIPTION
        RoKa Edition. When the selection holds entries from config/rokadanger.json, the user is
        asked once for all of them: Yes applies everything, No leaves the danger-listed entries
        out and goes on with the rest, Cancel applies nothing.

        Without a window Show-WinUtilMessage answers "No", so a headless run always leaves them
        out.

    .PARAMETER Keys
        The selected keys that are about to be applied.

    .OUTPUTS
        An object with Proceed (whether to go on at all) and Keys (what may be applied).
    #>
    param(
        [string[]]$Keys = @()
    )

    $allKeys = @($Keys | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $dangerKeys = @($allKeys | Where-Object { Get-WinUtilDangerReason -Key $_ })

    if ($dangerKeys.Count -eq 0) {
        return [pscustomobject]@{ Proceed = $true; Keys = $allKeys }
    }

    $lines = foreach ($key in $dangerKeys) {
        "- $(Get-WinUtilTweakDisplayName -Key $key): $(Get-WinUtilDangerReason -Key $key)"
    }
    $message = "Your selection contains $($dangerKeys.Count) entr$(if ($dangerKeys.Count -eq 1) { 'y' } else { 'ies' }) from the danger list:`n`n" +
        ($lines -join "`n`n") +
        "`n`nYes: apply everything, including the entries above.`nNo: leave the entries above out and apply the rest.`nCancel: apply nothing."

    $answer = Show-WinUtilMessage -Message $message -Title "Danger list" -Button "YesNoCancel" -Icon "Warning"

    switch ("$answer") {
        "Yes" {
            Write-WinUtilLog -Level "WARN" -Component "Danger" -Message "Danger-listed entries confirmed by the user: $($dangerKeys -join ', ')"
            return [pscustomobject]@{ Proceed = $true; Keys = $allKeys }
        }
        "No" {
            Write-WinUtilLog -Level "WARN" -Component "Danger" -Message "Danger-listed entries left out: $($dangerKeys -join ', ')"
            return [pscustomobject]@{ Proceed = $true; Keys = @($allKeys | Where-Object { $dangerKeys -notcontains $_ }) }
        }
        default {
            Write-WinUtilLog -Component "Danger" -Message "Run cancelled at the danger list confirmation."
            return [pscustomobject]@{ Proceed = $false; Keys = @() }
        }
    }
}
