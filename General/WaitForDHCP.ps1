#Done this way in order to work in WinPE

$ip=[System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
while (!($IPv4=$ip.GetUnicastAddresses() | ? Address -ne 127.0.0.1 |? Address -like '*.*.*.*'| ? SuffixOrigin -eq "OriginDhcp")){sleep -Milliseconds 3000}
write-host "DHCP-Address:" $IPv4.Address.ToString()