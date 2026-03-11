function Get-ParameterAlias {
    [Alias('gpa')]
    param([string]$CommandName)

    $AdvancedParameterNames = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@(
            'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction'
            'ProgressAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable'
            'OutVariable', 'OutBuffer', 'PipelineVariable', 'WhatIf', 'Confirm'
        )
    )

    (Get-Command $CommandName).Parameters.Values |
        Where-Object { $_.Aliases -and (-not $AdvancedParameterNames.Contains($_.Name)) } |
        Select-Object Name, Aliases
}

function Invoke-ZapretDirectory {
    [Alias('iz')]
    param()

    Invoke-Item "$env:USERPROFILE\Documents\zapret\zapret-winws"
}

function Start-Media {
    [Alias('sam', 'm')]
    param(
        [string]$Path,

        [switch]$PrimaryMonitor,
        [switch]$Muted,
        [switch]$Minimized
    )

    $Arguments = @(
        (Convert-Path $Path)

        '/monitor'
        $PrimaryMonitor ? '1' : '2'

        if ($Muted) { '/mute' }
        if ($Minimized) { '/minimized', '/nofocus' }

        '/close'
        $args
    )

    mpc-hc64 $Arguments
}

function Invoke-Ffmpeg {
    [Alias('ifm')]
    param()

    ffmpeg -hide_banner $args
}

function Invoke-Ffprobe {
    [Alias('ifp')]
    param()

    ffprobe -hide_banner $args
}

function Get-YoutubeUrl {
    [Alias('gyt')]
    param([string]$Id)

    Set-Clipboard "https://youtube.com/watch?v=$Id" -PassThru
}

function Get-MediaDate {
    [Alias('gmd')]
    param([int]$UnixTime)

    Get-Date -UnixTimeSeconds $UnixTime -AsUTC
}