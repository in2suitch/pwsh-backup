function __DefaultDownloadLocation {
    $IsMacOS ? $HOME : (Test-Path 'R:\') ? 'R:\' : 'E:\Downloads'
}

function __BrowserCookiesArgumentList {
    $WindowsBrowserProfilePath = "$env:APPDATA\Floorp\Profiles\ul67hs29.default-release"
    $MacBrowserProfilePath = (
        "$HOME/Library/Application Support/Floorp/Profiles/o2pl6jz3.default-default"
    )

    $CurrentSystemPath = $IsWindows ? $WindowsBrowserProfilePath
                                    : $MacBrowserProfilePath

    '--cookies-from-browser', "firefox:$CurrentSystemPath"
}

function __OptimalYoutubePlayerClientArgumentList ([switch]$ForHistory) {
    $ClientConfiguration = $ForHistory ? 'default,-web_creator;use_ad_playback_context'
                                       : 'android_vr'

    '--extractor-args', "youtube:player_client=$ClientConfiguration"
}

function __UtcDate { Get-Date -Format 'yyyy-MM-dd' -AsUTC }

function __KemonoExtrnalUrlConfiguration {
    '--option', 'extractor.directory=[]'
    '--option', 'extractor.kemono.endpoint=posts+'
    '--option', 'extractor.kemono.postprocessors.name=metadata'
    '--option', 'extractor.kemono.postprocessors.event=post'
    '--option', 'extractor.kemono.postprocessors.filename={id}_links.txt'
    '--option', 'extractor.kemono.postprocessors.mode=custom'
    '--option'

    @(
        'extractor.kemono.postprocessors.format'
        '"Text: {content}\nDesc: {description}\nEmbed: {embed[url]}\n"'
    ) -join '='
}

function Invoke-YtDlp {
    [Alias('iyd')]param([switch]$Authenticated)

    $Arguments = @(
        '--buffer-size', '7.5M', '--no-resize-buffer'
        '--concurrent-fragments', '14'
        '--format', 'bestvideo*[format_note!*=?AI-upscaled]+bestaudio/best'
        '--output', '%(title)s_@%(id)s.%(ext)s'
        '--paths', (__DefaultDownloadLocation)
        '--sleep-subtitles', '1'
        '--sleep-requests', '0.75'
        '--min-sleep-interval', '1'
        '--max-sleep-interval', '3'

        if ($Authenticated) { __BrowserCookiesArgumentList }

        $args
    )

    yt-dlp $Arguments
}

function Invoke-GalleryDl {
    [Alias('igd')]param([switch]$Authenticated)

    $Arguments = @(
        '--chunk-size', '7.5M'
        '--destination', (__DefaultDownloadLocation)
        '--option', 'extractor.directory=[]'
        '--sleep', '1-3'
        '--sleep-request', '0.75'

        if ($Authenticated) { __BrowserCookiesArgumentList }

        $args
    )

    gallery-dl $Arguments
}

function Save-Media {
    [Alias('svm')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
            $UniqueHosts = $_.Host | Select-Object -Unique
            $UniqueHosts.Count -eq 1
        }, ErrorMessage = 'One host at a time.'
        )]
        [uri[]]$Url,

        [Alias('N')]
        [string]$Name,

        [string]$Path,
        [int]$Rate,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ArgumentList,

        [Alias('A')]
        [switch]$AudioOnly,

        [Alias('Mp4')]
        [switch]$AsMp4,

        [Alias('ND')]
        [switch]$NoDate,

        [Alias('C')]
        [switch]$DefaultYoutubePlayerClient,

        [switch]$Authenticated,
        [switch]$WithYtDlp
    )

    $IsOutputVerbose = $PSBoundParameters.ContainsKey('Verbose')
    $IsDefaultPlayerClientRequired = $DefaultYoutubePlayerClient -or $Authenticated

    $MediaHostName = $Url[0].Host -replace '^www\.'
    $ComplexHostNames = 'twitch.tv', 'player.vimeo.com'
    $SourceNeutralArguments = @(
        if ($Rate) { '--limit-rate', "${Rate}M" }
        $ArgumentList
        $Url
    )

    $ComplexHostArguments = @(
        if ($Name) {
            '--output'
            "${Name}_%(release_date>%Y-%m-%d,upload_date>%Y-%m-%d)s_@%(id)s.%(ext)s"
        }
        else {
            '--restrict-filenames'
        }

        if ($Path) { '--paths', $Path }
        if ($AudioOnly) { '-f', 'ba' }
        if (-not $IsOutputVerbose) { '--quiet', '--progress' }
        if (-not $IsDefaultPlayerClientRequired) {
            __OptimalYoutubePlayerClientArgumentList
        }

        if ($MediaHostName -match 'vimeo') {
            '--add-headers', 'referer:https://patreon.com'
            '--no-warnings'
        }
    )

    $OtherHostArguments = @(
        if ($Name) {
            '--filename'
            if ($NoDate -or $Name -match '\d{4}-\d{2}-\d{2}') { "$Name.{extension}" }
            else { "${Name}_$(__UtcDate).{extension}" }
        }

        if ($Path) { '--destination', $Path }
        if ($IsOutputVerbose) { '--verbose' }
    )

    $Mp4MuxingArguments = @(
        '--remux-video'

        if ($AudioOnly) {
            'm4a'
            '--postprocessor-args', 'ExtractAudio+ffmpeg:-codec copy -f mp4'
            '--postprocessor-args', 'Metadata+ffmpeg:-f mp4'
            '-x', '--audio-format', 'm4a'
        }
        else { 'mp4', '--merge-output-format', 'mp4' }
    )

    $CompleteYoutubeArguments = @(
        '--sponsorblock-mark', 'all'
        $ComplexHostArguments
        if ($AsMp4) { $Mp4MuxingArguments }
        $SourceNeutralArguments
    )

    if ($MediaHostName -match 'youtu') {
        Invoke-YtDlp -Authenticated:$Authenticated @CompleteYoutubeArguments
    }
    elseif (($MediaHostName -in $ComplexHostNames) -or $WithYtDlp) {
        Invoke-YtDlp @ComplexHostArguments -Authenticated:$Authenticated `
            @SourceNeutralArguments
    }
    else {
        Invoke-GalleryDl @OtherHostArguments -Authenticated:$Authenticated `
            @SourceNeutralArguments
    }
}

function Add-YoutubeHistory {
    [Alias('ayh')]
    param(
        [ValidatePattern(
            'youtu|^[0-9A-Za-z_-]{11}$|@[0-9A-Za-z_-]{11}',
            ErrorMessage = 'Not a YouTube URL or ID.'
        )]
        [string[]]$Url
    )

    $YoutubeUrlOrIds = foreach ($PossibleId in $Url) {
        ($PossibleId -match '@([0-9A-Za-z_-]{11})') ? $Matches[1] : $PossibleId
    }

    $Arguments = @(
        (__OptimalYoutubePlayerClientArgumentList -ForHistory)
        __BrowserCookiesArgumentList
        '--quiet', '--mark-watched', '--simulate'
        $YoutubeUrlOrIds
    )

    Invoke-YtDlp @Arguments
}

function Save-KemonoExternalUrlList {
    [Alias('svkemono')]param([string]$Url)

    gallery-dl (__KemonoExtrnalUrlConfiguration) --quiet $ConfigurationArguments `
        --no-download --destination (__DefaultDownloadLocation) $Url

    if ($LASTEXITCODE -eq 0) {
        $MetadataTxts = Get-ChildItem (Join-Path (__DefaultDownloadLocation) *.txt)
        $ExternalUrls = [System.Collections.Generic.HashSet[string]]::new()
        $UrlPattern = [regex]"https?://[^""'\s<>]+"

        foreach ($MetadataTxt in $MetadataTxts) {
            $Content = [System.IO.File]::ReadAllText($MetadataTxt.FullName)

            foreach ($PatternMatch in $UrlPattern.Matches($Content)) {
                [void]$ExternalUrls.Add($PatternMatch.Value)
            }
        }

        $ExternalUrls | Set-Content (Join-Path (__DefaultDownloadLocation) links.txt)
        $MetadataTxts | Remove-Item -Force
    }
}

function Get-MediaInfo {
    [Alias('gmi')]
    param(
        [string]$Path,
        [string]$Field,

        [Alias('C')]
        [switch]$DefaultYoutubePlayerClient,

        [switch]$Authenticated
    )

    $SourceSpecificArguments = @(
        if ($Field) { '--print', $Field }
        else { '--list-formats', '--quiet' }

        if (-not $DefaultYoutubePlayerClient -and -not $Authenticated) {
            __OptimalYoutubePlayerClientArgumentList
        }

        $Path
    )

    if ($Path -notmatch '^https?:') { mediainfo (Convert-Path $Path) }
    elseif ($Path -match 'youtu|^[0-9A-Za-z_-]{11}$|twitch|vimeo') {
        Invoke-YtDlp -Authenticated:$Authenticated @SourceSpecificArguments
    }
    else { Invoke-GalleryDl -Authenticated:$Authenticated --list-keywords $Path }
}