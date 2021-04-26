FUDir = "C:\FeatureUpgrade"

if ([System.IO.Directory]::Exists($FUDir) -eq $false)
{
    New-Item $FUDir -Type Directory -Force
}

$WebClient = New-Object System.Net.WebClient
$Url = "https://go.microsoft.com/fwlink/?LinkID=799445"
$File = "$($FUDir)\Win10Upgrade.exe"
$WebClient.DownloadFile($Url,$File)

#UnComment to execute upgrade
#Start-Process -FilePath $File -ArgumentList "/quietinstall /skipeula /auto upgrade /copylogs $FUDir"
#
