#Verified in WinPE 10 / Win10
#Defaults to create an incoming rule which allows the TCP protocol on choosen port(s)

Param (
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$true)]
   [ValidateNotNullOrEmpty()]
   [string] $Name,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$true)]
   [string[]] $Ports,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$false)]
   [System.Net.Sockets.ProtocolType] $Protocol=[System.Net.Sockets.ProtocolType]::TCP,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$false)]
   [string] $ApplicationPath,
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$false)]
   [ValidateSet('In','Out')]
   [string]$Direction="In",
   [Parameter(ValueFromPipelineByPropertyName,Mandatory=$false)]
   [ValidateSet('Allow','Block')]
   [string]$Action="Allow"


)

$fw=New-Object -ComObject HNetcfg.FWpolicy2
$rule=New-Object -ComObject HNetCfg.FWRule

if ($ApplicationPath -notin ($null,""))
{
$rule.ApplicationName=$ApplicationPath
}

$rule.Direction=switch($Direction){"In" {1} "Out" {2}}
$rule.Name=$Name
$rule.Protocol=$Protocol.Value__
$rule.LocalPorts=$Ports -join ","
$rule.EdgeTraversal=$false

switch($Action)
{
'Allow' {$rule.Action=1} 
'Block' {$rule.Action=0}
}

$rule.Enabled=$true
$fw.Rules.Add($rule)
