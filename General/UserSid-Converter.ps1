Param
(
  $in
)

$NumOfParams = 1
#write-host $PSBoundParameters.Count
If (($PSBoundParameters.values | Measure-Object | Select-Object -ExpandProperty Count) -lt $NumOfParams){Write-Host "Wrong number of arguments." ;Exit }

If ($in -match "s-*-*-*-")
{
$objSID = New-Object System.Security.Principal.SecurityIdentifier ($in)
$objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
return $objUser.Value
}
else{
$AdObj  = New-Object System.Security.Principal.NTAccount($in) 
$strSID = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
return $strSID.Value
}
