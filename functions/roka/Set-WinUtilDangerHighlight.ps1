function Set-WinUtilDangerHighlight {
    <#
    .SYNOPSIS
        Marks every danger-listed control that exists so far in red, outlines it and puts the
        reason in its tooltip

    .DESCRIPTION
        RoKa Edition. Tabs are built lazily, so this runs after each tab build and skips the
        controls it has already marked, which it tells by the tooltip it gave them. It touches
        controls directly and therefore has to run on the interface thread, which is where tabs
        are built.
    #>

    if ($null -eq $sync.configs.rokadanger -or -not (Test-WinUtilUIAlive)) {
        return
    }

    # The checkbox template only paints a background, so the outline is drawn into that
    # background and redrawn whenever the control changes size
    $drawOutline = {
        $box = $args[0]
        if ($box.ActualWidth -le 4 -or $box.ActualHeight -le 4) {
            return
        }

        $pen = [Windows.Media.Pen]::new([Windows.Media.Brushes]::Red, 2)
        $frame = [Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(1, 1, $box.ActualWidth - 2, $box.ActualHeight - 2))
        $drawing = [Windows.Media.GeometryDrawing]::new([Windows.Media.Brushes]::Transparent, $pen, $frame)
        $box.Background = [Windows.Media.DrawingBrush]::new($drawing)
    }

    foreach ($entry in $sync.configs.rokadanger.PSObject.Properties) {
        $key = $entry.Name
        $control = $sync[$key]

        if ($control -isnot [Windows.Controls.Control]) {
            continue
        }

        $reason = "DANGER: $($entry.Value.Reason)"
        $existingToolTip = [string]$control.ToolTip
        if ($existingToolTip.StartsWith($reason)) {
            continue
        }

        try {
            $control.Foreground = [Windows.Media.Brushes]::Red
            $control.FontWeight = [Windows.FontWeights]::Bold
            $control.BorderBrush = [Windows.Media.Brushes]::Red

            $control.ToolTip = if ([string]::IsNullOrWhiteSpace($existingToolTip)) { $reason } else { "$reason`n`n$existingToolTip" }

            if ($control -is [Windows.Controls.Primitives.ToggleButton]) {
                $control.Add_SizeChanged($drawOutline)
                & $drawOutline $control
            } else {
                # The button template draws its border at the theme's thickness, so the thicker
                # outline is handed to it as a resource of its own
                $control.Resources["ButtonBorderThickness"] = [Windows.Thickness]::new(2)
            }
        } catch {
            Write-WinUtilLog -Level "WARN" -Component "Danger" -Message "Could not highlight '$key': $($_.Exception.Message)"
        }
    }
}
