function Convert-Audio {
    [Alias('cva')]
    param(
        [System.IO.FileInfo[]]$InputObject,

        [switch]$Unoptimized,
        [switch]$Aac
    )

    $InputObject | ForEach-Object -ThrottleLimit 6 -Parallel {
        $Aac = $using:Aac

        $FinalFileName = "$($_.BaseName).m4a"
        $ConvertedFilePath = Join-Path $_.DirectoryName "_copy_$FinalFileName"
        $FinalFilePath = Join-Path $_.DirectoryName $FinalFileName

        $MainConversionArguments = @(
            '-hide_banner'
            '-loglevel', 'warning'
            '-channel_layout', 'stereo'
            '-i', $_.FullName
            '-vn'

            if (-not $Aac) {
                '-codec:a', 'libopus', '-b:a', '128k', '-f', 'mp4', $ConvertedFilePath
            }
            else { '-f', 'wav', '-' }
        )

        $AacSpecificArguments = @(
            '--tvbr', '82'
            '--silent'
            '--no-optimize'
            '-o'
            $ConvertedFilePath
        )

        if (-not $Aac) { ffmpeg $MainConversionArguments }
        elseif ($_.Extension -eq '.wav') { qaac $_.FullName $AacSpecificArguments }
        else { ffmpeg $MainConversionArguments | qaac - $AacSpecificArguments }

        if (-not $using:Unoptimized -and ($LASTEXITCODE -eq 0)) {
            $OptimizedFilePath = Join-Path $_.DirectoryName "_optimized_$FinalFileName"
            mp4box -quiet -add $ConvertedFilePath -inter 500 -new $OptimizedFilePath

            if ($LASTEXITCODE -eq 0) { Remove-Item $ConvertedFilePath -Force }

            if (-not (Test-Path $FinalFilePath)) {
                Rename-Item $OptimizedFilePath $FinalFileName -Force
            }
            else { Write-Warning "File $FinalFileName already exists." }
        }
    }
}

function Copy-Media {
    [Alias('cpm')]
    param(
        [Parameter(ValueFromPipeline)]
        [System.IO.FileInfo[]]$InputObject,

        [ValidatePattern('^\.[a-zA-Z0-9]+', ErrorMessage = 'Incorrect extension.')]
        [Alias('E')]
        [string]$NewExtension,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ArgumentList,

        [Alias('NV', 'A')]
        [switch]$NoVideo,

        [switch]$Unoptimized
    )

    begin { $InputObjects = [System.Collections.Generic.List[object]]::new() }
    process { foreach ($Object in $InputObject) { $InputObjects.Add($Object) } }
    end {
        $InputObjects | ForEach-Object -ThrottleLimit 6 -Parallel {
            function __FullMp4Compatibility ($MediaObject) {
                $AudioCodecJson = (
                    ffprobe -loglevel quiet -select_streams a:0 `
                        -show_entries stream=codec_name -of json $MediaObject.FullName
                )
                ($AudioCodecJson | ConvertFrom-Json).streams.codec_name -ne 'opus'
            }

            $ArgumentList = $using:ArgumentList
            $NoVideo = $using:NoVideo
            $Unoptimized = $using:Unoptimized

            $OptimizableExtensions = '.mp4', '.m4v', '.m4a', '.mov'
            $NewExtension = $using:NewExtension ? $using:NewExtension : $_.Extension
            $IsOptimizable = $NewExtension -in $OptimizableExtensions

            $NewName = "$($_.BaseName)$NewExtension"
            $IsNewNameOccupied = Test-Path (Join-Path $_.DirectoryName $NewName)
            $NoNameCollisionPath = Join-Path $_.DirectoryName (
                $IsNewNameOccupied ? "_copy_$NewName" : $NewName
            )

            $CopyArguments = @(
                '-hide_banner', '-y'
                '-loglevel', 'warning'
                '-i', $_.FullName

                if (-not (__FullMp4Compatibility $_) -and $NewExtension -eq '.m4a') {
                    '-f', 'mp4'
                }

                $NoVideo ? '-vn', '-codec:a' : '-codec'
                'copy'

                $ArgumentList
                $NoNameCollisionPath
            )

            ffmpeg $CopyArguments

            if (-not $Unoptimized -and $IsOptimizable -and $LASTEXITCODE -eq 0) {
                $OptimizableMedia = $NoNameCollisionPath
                $OptimizedMedia = Join-Path $_.DirectoryName "_optimized_$NewName"
                mp4box -quiet -add $OptimizableMedia -inter 500 -new $OptimizedMedia

                if ($LASTEXITCODE -eq 0) {
                    Remove-Item -LiteralPath $OptimizableMedia
                    if (-not $IsNewNameOccupied) {
                        Rename-Item -LiteralPath $OptimizedMedia $NewName
                    }
                }
            }
        }
    }
}

function Resize-Image {
    [Alias('rzi')]
    param(
        [System.IO.FileInfo[]]$InputObject,

        [Alias('Px')]
        [int]$Size,

        [switch]$OptimalSize,
        [switch]$JpgOutput
    )

    $InputObject | ForEach-Object -ThrottleLimit 6 -Parallel {
        $JpgOutput = $using:JpgOutput
        $Size = $using:Size
        $IsJpeg = $_.Extension -eq '.jpg'

        $OutputName =
            if ($JpgOutput -and (-not $IsJpeg)) { "$($_.BaseName).jpg" }
            else { "__resized__$($_.BaseName)$($_.Extension)" }
        $OutputPath = Join-Path $_.DirectoryName $OutputName

        # Fixed argument order is enforced by magick.
        $Arguments = @(
            $_.FullName
            if ($JpgOutput -or $IsJpeg) { '-interlace', 'JPEG' }
            '-resize'

            if ($using:OptimalSize) { '1248x960>' }
            else { "${Size}x${Size}" }

            $OutputPath
        )

        magick $Arguments
    }
}