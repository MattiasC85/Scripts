#Used in WinPE due to lack of nslookup
Param (
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$True)]
   [string] $Hostname,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$true)]
   [string] $Port
)

function Test-Port($hostname, $port)
{
    try {
        $ip = [System.Net.Dns]::GetHostAddresses($hostname) | 
            select-object IPAddressToString -expandproperty  IPAddressToString
        if($ip.GetType().Name -eq "Object[]")
        {
            $ip = $ip[0]
        }
    } catch {
        Write-Host "DNS lookup for $hostname failed."
        return $false
    }
    $t = New-Object Net.Sockets.TcpClient
    try
    {
        $t.Connect($ip,$port)
    } catch {}

    if($t.Connected)
    {
        $t.Close()
        $msg = "Successfully connected to $hostname on port $port."
    }
    else
    {
        $msg = "Failed to connect to $hostname on port $port."
        return $false                               
    }
    Write-Host $msg
    return $true
}

Test-Port $Hostname $Port