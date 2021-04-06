Function Reset-UpdateStore
{
    param(
        [Parameter(Mandatory=$False)]
        [int]$TriggerInstall=0
    )

    Stop-service UsoSvc
    $status=(Get-Service UsoSvc).status
    #write-host "UsoSvc StartType: $((Get-Service UsoSvc).StartType)"

    while ($status -ne "Stopped")
    {
	    write-host "waiting for stop"
	    start-sleep -s 1
	    $status=(Get-Service UsoSvc).status
    }

    $SystemSettingsProc=Get-Process SystemSettings -ErrorAction SilentlyContinue
    if ($SystemSettingsProc -ne $null)
    {
	    Write-host "Found SystemSettings process, killing it"
	    $stoppr=Stop-Process $SystemSettingsProc -Force
    }

    $etls=Get-ChildItem -Path C:\ProgramData\USO*\*.etl -Recurse
    $etls.FullName | % {Remove-Item $_}

    $xmls=Get-ChildItem -Path C:\ProgramData\USO*\*.xml -Recurse
    $xmls.FullName | % {Remove-Item $_}

    $etls=Get-ChildItem -Path C:\ProgramData\USO*\*.etl -Recurse
    $xmls=Get-ChildItem -Path C:\ProgramData\USO*\*.xml -Recurse

    #Windows 10 1904x

    $dbs=Get-ChildItem -Path C:\ProgramData\USO*\*.db -Recurse
    if ($dbs)
    {
        $dbs.FullName | % {Remove-Item $_}
        $dbs=Get-ChildItem -Path C:\ProgramData\USO*\*.db -Recurse
    }

    if ($etls -eq $null -and $xmls-eq $null)
    {
        Write-host "Removed old USO etl- and xml-files sucessfully"
    }


    $Wuares=restart-service wuauserv
    $UsoStart=start-service UsoSvc
    $status=(Get-Service UsoSvc).status
    while ($status -ne "Running")
    {
	    write-host "waiting for start"
	    start-sleep -s 1
	    $status=(Get-Service UsoSvc).status
    }

    $Wuares=restart-service wuauserv
    Start-Sleep -seconds 2
    $Usostatus=(Get-Service UsoSvc).status

    Write-host "Starting scan"
    Start-Process -FilePath C:\Windows\system32\UsoClient.exe -ArgumentList {"startscan"} -Wait
    if ($TriggerInstall -eq 1)
    {
        Start-Process -FilePath C:\Windows\system32\UsoClient.exe -ArgumentList {"ScanInstallWait"} -Wait
        start-sleep -seconds 5
        Write-host "Starting install..."
        Start-Process -FilePath C:\Windows\system32\UsoClient.exe -ArgumentList {"startInstall"}
        write-host "After Install"
    }
    write-host "Done"
}
