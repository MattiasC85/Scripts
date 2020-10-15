<# 
   .SYNOPSIS 
    Check for local Policy corruption issue

   .DESCRIPTION
   Checks the local policy files for corruption

#>

#Main Function which checks the policy files for corruption
Function Test-IsRegistryPOLGood
    {
       $PathToMachineRegistryPOLFile = "$ENV:Windir\System32\GroupPolicy\Machine\Registry.pol"
       $PathToUserRegistryPOLFile = "$ENV:Windir\System32\GroupPolicy\User\Registry.pol"


       # Test for a Machine policy file - if there isn't one - all good
        if(!(Test-Path -Path $PathToMachineRegistryPOLFile -PathType Leaf)) {}
        #If there is a .pol file - test it
        else{
        If (((Get-Content -Encoding Byte -Path $PathToMachineRegistryPOLFile -TotalCount 4) -join '') -ne '8082101103'){Return $False}
        }

        # Test for a User policy file - if there isn't one - as you were
        if(!(Test-Path -Path $PathToUserRegistryPOLFile -PathType Leaf)) {}
        #If there is a .pol file - test it
        else {
        If (((Get-Content -Encoding Byte -Path $PathToUserRegistryPOLFile -TotalCount 4) -join '') -ne '8082101103'){Return $False}
        }
      #if we made it here alles gut
       return $true
    }
  
#Set the default
$Compliance = "Compliant"  
   
#Then test the policy file using the function above - returns non-compliant if EITHER machine/user policy file is found to be corrupt.
If ((Test-IsRegistryPOLGood) -eq $true)
{
$Compliance = "Compliant"
}
else
{
   $Compliance = "Non-Compliant"
}
$Compliance