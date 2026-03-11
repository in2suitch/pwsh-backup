@{
    ModuleVersion = '1.0'
    RootModule = 'MediaManipulationTools.psm1'
    FunctionsToExport = @(
        'Convert-Audio'
        'Get-MediaItem'
        'Copy-Media'
        'Resize-Image'
    )
    AliasesToExport = @(
        'cva'
        'gmi'
        'cpm'
        'rzi'
    )
    CmdletsToExport = @()
}