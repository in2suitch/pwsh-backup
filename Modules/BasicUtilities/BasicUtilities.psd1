@{
    ModuleVersion = '1.0'
    RootModule = 'BasicUtilities.psm1'
    FunctionsToExport = @(
        'Get-ParameterAlias'
        'Invoke-ZapretDirectory'
        'Start-Media'
        'Invoke-Ffmpeg'
        'Invoke-Ffprobe'
        'Get-YoutubeUrl'
        'Get-MediaDate'
        'Invoke-Losslesscut'
    )
    AliasesToExport = @(
        'gpa'
        'iz'
        'sam'
        'm'
        'ifm'
        'ifp'
        'gyt'
        'gmd'
        'ilc'
    )
    CmdletsToExport = @()
}