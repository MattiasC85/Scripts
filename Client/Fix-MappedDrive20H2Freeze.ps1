<######################################################################################################
#                                                                                                     #
#   When computers with Win10 20H2 have a mapped network share with certain options                   # 
#   and is unable to reach that drive (working offline) any proccess that tries to access             #
#   or list the drive (Read "My computer", Office templates") will freeze for ~10-15 mins             # 
#   once per reboot.                                                                                  #
#                                                                                                     #
#   I have no idea why, but I think it has something to do with SMB+Netbios names.                    #
#   Either username (ShortDomainName\User) or the mapping (\\ShortServerName\share)                   #
#                                                                                                     #
#   https://docs.microsoft.com/en-us/answers/questions/141745/windows-10-20h2-network-connection.html #
#                                                                                                     #
#   This is probably one of many possible fixes.                                                      #
#   Needs to be run in user context followed by a reboot.                                             #
#                                                                                                     #
######################################################################################################>

Function Fix-MappedDrive20H2Freeze([string]$drvletter)
{
    $NetworkKey=Get-item HKCU:\Network
    $Subs=$NetworkKey.GetSubKeyNames()
    if ($Subs -contains $drvletter)
    {
        Write-Host "$($drvletter+":") was found"

        #ProviderFlags 0 = not a DFS root (?)
        #ProviderFlags 1 = DFS root       (?)

        $PropertyName="ProviderFlags"
        $PropertyValue= 1

        $SubKey=$NetworkKey.OpenSubKey($drvletter,$true)
        $SubKey.SetValue($PropertyName, $PropertyValue,[Microsoft.Win32.RegistryValueKind]::DWord)
        if ($SubKey.GetValue($PropertyName) -eq $PropertyValue)
        {
            Write-Host "Successfully set $PropertyName value to $PropertyValue for $($drvletter+":")"
        }
    }
    else
    {
        Write-Host "$($drvletter+":") was not found"
    }
}

Fix-MappedDrive20H2Freeze -drvletter "Ltr"