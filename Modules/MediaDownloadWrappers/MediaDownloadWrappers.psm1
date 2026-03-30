function Get-DefaultDownloadLocation {
    $IsMacOS ? $HOME : (Test-Path 'R:\') ? 'R:\' : 'E:\Downloads'
}

function Get-BrowserCookiesArgumentList {
    $WindowsBrowserProfilePath = "$env:APPDATA\Floorp\Profiles\ul67hs29.default-release"
    $MacBrowserProfilePath = (
        "$HOME/Library/Application Support/Floorp/Profiles/o2pl6jz3.default-default"
    )

    $CurrentSystemPath = $IsWindows ? $WindowsBrowserProfilePath
                                    : $MacBrowserProfilePath

    '--cookies-from-browser', "firefox:$CurrentSystemPath"
}

function Get-OptimalYoutubePlayerClientArgumentList ([switch]$ForHistory) {
    $ClientConfiguration = $ForHistory ? 'default,-web_creator;use_ad_playback_context'
                                       : 'android_vr'

    '--extractor-args', "youtube:player_client=$ClientConfiguration"
}

function Get-UtcDate { Get-Date -Format 'yyyy-MM-dd' -AsUTC }

function Get-KemonoExternalUrlConfiguration {
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

function Group-MediaUrlByHost ([uri[]]$UrlCollection) {
    $GroupedUrls = @{}
    foreach ($Url in $UrlCollection) {
        if (-not $GroupedUrls.ContainsKey($Url.Host)) {
            $GroupedUrls.Add(
                $Url.Host,
                [System.Collections.Generic.List[uri]]::new()
            )
        }
        $GroupedUrls[$NormalizedHostName].Add($Url)
    }
    $GroupedUrls
}

function Invoke-YtDlp {
    [Alias('iyd')]param([switch]$Authenticated)

    $Arguments = @(
        '--buffer-size', '6M', '--no-resize-buffer'
        '--concurrent-fragments', '20'
        '--format', 'bestvideo*[format_note!*=?AI-upscaled]+bestaudio/best'
        '--output', '%(title)s_@%(id)s.%(ext)s'
        '--paths', (Get-DefaultDownloadLocation)
        '--sleep-subtitles', '1'
        '--sleep-requests', '0.75'
        '--min-sleep-interval', '1'
        '--max-sleep-interval', '3'

        if ($Authenticated) { Get-BrowserCookiesArgumentList }

        $args
    )

    yt-dlp $Arguments
}

function Invoke-GalleryDl {
    [Alias('igd')]param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ArgumentList = @(),

        [switch]$Authenticated
    )

    $PredefinedArguments = @(
        '--chunk-size', '6M'
        '--destination', (Get-DefaultDownloadLocation)
        '--option', 'extractor.directory=[]'
        '--sleep', '1-3'
        '--sleep-request', '0.75'

        if ($Authenticated) { Get-BrowserCookiesArgumentList }

        $ArgumentList
    )

    Write-Verbose ($PredefinedArguments -join ' ')
    gallery-dl $PredefinedArguments
}

function Save-Media {
    [Alias('svm')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [uri[]]$Url,

        [Alias('N')]
        [string]$Name,

        [string]$Path,
        [int]$Rate,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ArgumentList = @(),

        [Alias('A')]
        [switch]$AudioOnly,

        [Alias('ND')]
        [switch]$NoDate,

        [Alias('C')]
        [switch]$DefaultYoutubePlayerClient,

        [switch]$Authenticated,
        [switch]$WithYtDlp
    )

    $MediaHostNames = Group-MediaUrlByHost $Url
    $IsOutputVerbose = $PSBoundParameters.ContainsKey('Verbose')
    $IsDefaultPlayerClientRequired = $DefaultYoutubePlayerClient -or $Authenticated

    $ToolNeutralArguments = @(
        if ($Rate) { '--limit-rate', "${Rate}M" }
        $ArgumentList
    )

    $YtDlpHostPatterns = @('pornhub', 'twitch') -join '|'
    $YtDlpHostArguments = @(
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
            Get-OptimalYoutubePlayerClientArgumentList
        }
    )

    $VimeoArguments = '--add-headers', 'referer:https://patreon.com', '--no-warnings'
    $YoutubeArguments = '--sponsorblock-mark', 'all'

    $GalleryDlHostArguments = @(
        if ($Name) {
            '--filename'
            if ($NoDate -or $Name -match '\d{4}-\d{2}-\d{2}') { "$Name.{extension}" }
            else { "${Name}_$(Get-UtcDate).{extension}" }
        }

        if ($Path) { '--destination', $Path }
        if ($IsOutputVerbose) { '--verbose' }
    )

    foreach ($MediaHostName in $MediaHostNames.Keys) {
        $UrlArray = $MediaHostNames[$MediaHostName]

        switch ($true) {
            ($MediaHostName -match 'youtu') {
                Invoke-YtDlp @YtDlpHostArguments -Authenticated:$Authenticated `
                    @YoutubeArguments @ToolNeutralArguments @UrlArray

                break
            }
            ($MediaHostName -match 'vimeo') {
                Invoke-YtDlp @YtDlpHostArguments -Authenticated:$Authenticated `
                    @VimeoArguments @ToolNeutralArguments @UrlArray

                break
            }
            (($MediaHostName -match "\b($YtDlpHostPatterns)\b") -or $WithYtDlp) {
                Invoke-YtDlp @YtDlpHostArguments -Authenticated:$Authenticated `
                    @ToolNeutralArguments @UrlArray

                break
            }
            default {
                Invoke-GalleryDl @GalleryDlHostArguments -Authenticated:$Authenticated `
                    @ToolNeutralArguments @UrlArray

                break
            }
        }
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
        (Get-OptimalYoutubePlayerClientArgumentList -ForHistory)
        Get-BrowserCookiesArgumentList
        '--quiet', '--mark-watched', '--simulate'
        $YoutubeUrlOrIds
    )

    Invoke-YtDlp @Arguments
}

function Save-KemonoExternalUrlList {
    [Alias('svkemono')]param([string]$Url)

    gallery-dl (Get-KemonoExternalUrlConfiguration) --quiet $ConfigurationArguments `
        --no-download --destination (Get-DefaultDownloadLocation) $Url

    if ($LASTEXITCODE -eq 0) {
        $MetadataTxts = Get-ChildItem (Join-Path (Get-DefaultDownloadLocation) *.txt)
        $ExternalUrls = [System.Collections.Generic.HashSet[string]]::new()
        $UrlPattern = [regex]"https?://[^""'\s<>]+"

        foreach ($MetadataTxt in $MetadataTxts) {
            $Content = [System.IO.File]::ReadAllText($MetadataTxt.FullName)

            foreach ($PatternMatch in $UrlPattern.Matches($Content)) {
                [void]$ExternalUrls.Add($PatternMatch.Value)
            }
        }

        $ExternalUrls | Set-Content (Join-Path (Get-DefaultDownloadLocation) links.txt)
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
            Get-OptimalYoutubePlayerClientArgumentList
        }

        $Path
    )

    if ($Path -notmatch '^https?:') { mediainfo (Convert-Path $Path) }
    elseif ($Path -match 'youtu|^[0-9A-Za-z_-]{11}$|twitch|vimeo') {
        Invoke-YtDlp -Authenticated:$Authenticated @SourceSpecificArguments
    }
    else { Invoke-GalleryDl -Authenticated:$Authenticated --list-keywords $Path }
}