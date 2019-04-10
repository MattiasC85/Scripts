Param (
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$false)]
   [string[]] $Categories=@(""),
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$false)]
   [string[]] $KBFilter=""
)

$Session = New-Object -ComObject Microsoft.Update.Session 
$Searcher = $Session.CreateUpdateSearcher()
$HistoryCount = $Searcher.GetTotalHistoryCount()
# http://msdn.microsoft.com/en-us/library/windows/desktop/aa386532%28v=vs.85%29.aspx
$Updates=$Searcher.QueryHistory(0,$HistoryCount)

Function Get-InstalledUpdates([string]$IncludedCategories, $IncludeKB)
{

#Read-Host
$Installed=0
$All=0     #In order to display more info about the update e.g. $Update[199] while excluding failed installations.

write-host "-------------------------------------"
Foreach ($Update in $updates)
{
    $KB=[regex]::match($Update.Title,"KB(\d+)")
    If (($Update.Categories[0].Name -match $IncludedCategories) -and ($Update.Title -match $IncludeKB))
    {
        if ($Update.operation -eq 1 -and $Update.resultcode -eq 2) 
        {
            write-host "Index:" $All
            write-host "Category:" $Update.Categories[0].Name
            write-host "Title:" $Update.Title
            write-host "Install Date:" $Update.Date
            write-host "UpdateID:" $update.UpdateIdentity.UpdateID
            write-host "KB:" $KB
            write-host "-------------------------------------"
            $Installed++
        }
    }
$All++
}
Write-host "`nTotal number of updates returned by the search:" ($Installed)
return $Installed
}

Get-InstalledUpdates $Categories $KBFilter
#@("Windows 10","Office 2016") 
#@("KB4090007")


#$Searcher.QueryHistory(0,$HistoryCount) | ForEach-Object {$_} | Out-File C:\temp\UpdateHistory.log

