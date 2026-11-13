function Get-WinUtilDangerReason {
    <#
    .SYNOPSIS
        Returns why an entry is on the RoKa Edition danger list, or nothing when it is not on it

    .DESCRIPTION
        The danger list lives in config/rokadanger.json. An entry on it is drawn in red, is never
        selected by a preset, an imported config or a headless run, and needs its own
        confirmation before it is applied. Pure data lookup, safe to call from a job worker.

    .PARAMETER Key
        The entry's config key or control name, such as WPFTweaksRemoveEdge.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($null -eq $sync -or $null -eq $sync.configs -or $null -eq $sync.configs.rokadanger) {
        return $null
    }

    $entry = $sync.configs.rokadanger.PSObject.Properties[$Key]
    if ($null -eq $entry) {
        return $null
    }

    return [string]$entry.Value.Reason
}
