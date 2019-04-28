# Should exclude most (3rd party) VPN-connections as well.

$wired=$null
$wireless=$null
$excluded=(0,7,$null)
$types = Get-WmiObject -Namespace "root/WMI" -Query "SELECT * FROM MSNdis_PhysicalMediumType"
$nicConfig = Get-WmiObject -Namespace "root/CIMV2" -Query "SELECT MacAddress,DNSDomain FROM Win32_NetworkAdapterConfiguration"
$nics = Get-WmiObject -Namespace "root/CIMV2" -Query "SELECT * FROM Win32_NetworkAdapter"| Where-Object {($excluded -NotContains $_.NetConnectionStatus) -and ($_.PNPDeviceID -notmatch "ROOT\\NET")} | ?{$_.physicaladapter}

$nics|%{
 $nicinstance = $_
 $types|%{
 if($_.instancename -eq $nicinstance.name)
 {
    switch ($_.NdisPhysicalMediumType)
    {
    0 {
        #"Wired adapter:"
        # "ServiceName: "+$nicinstance.servicename
        # "MACAddress: "+$nicinstance.MACAddress
        # "AdapterType: "+$nicinstance.AdapterType
        # "DeviceID: "+$nicinstance.DeviceID
        #"Name: "+$nicinstance.Name
        #"NdisPhysicalMediumType : "+$_
        # "`n" 
        $wired += ,$nicinstance
      }
      
    9 {
        #"Wireless adapter:"
        # "ServiceName: "+$nicinstance.servicename
        # "MACAddress: "+$nicinstance.MACAddress
        # "AdapterType: "+$nicinstance.AdapterType
        # "DeviceID: "+$nicinstance.DeviceID
        #"Name: "+$nicinstance.Name
        #"NdisPhysicalMediumType: "+$_
        # "`n"
        $wireless += ,$nicinstance
      }
 }

}
}
}

if ($Wired -eq $null)
{
$ValidCon=0
}
else
{
$ValidCon=($wired.Count)
}
write-host "Valid Wired connections:" ($ValidCon)
