@{
    ModuleVersion = '1.0'
    RootModule = 'MediaDownloadWrappers.psm1'
    FunctionsToExport = @(
        'Invoke-YtDlp'
        'Invoke-GalleryDl'
        'Save-Media'
        'Add-YoutubeHistory'
        'Save-KemonoExternalUrlList'
        'Get-MediaInfo'
    )
    AliasesToExport = @(
        'iyd'
        'igd'
        'svm'
        'ayh'
        'svkemono'
        'gminfo'
    )
    CmdletsToExport = @()
}