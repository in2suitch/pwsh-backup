@{
    ModuleVersion = '1.0'
    RootModule = 'MediaManipulationTools.psm1'
    FunctionsToExport = @(
        'Convert-Audio'
        'Copy-Media'
        'Resize-Image'
    )
    AliasesToExport = @(
        'cva'
        'cpm'
        'rzi'
    )
    CmdletsToExport = @()
}