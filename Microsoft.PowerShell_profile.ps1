function Clear-PersistentTerminalHistory {
    [Alias('clhistory')]param()
    Remove-Item (Get-PSReadLineOption).HistorySavePath
}

function Clear-RamDisk {
    [Alias('clrd')]param()
    Get-ChildItem 'R:\' | Remove-Item -Force
}