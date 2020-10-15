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
            try
            {
            If (((Get-Content -Encoding Byte -Path $PathToMachineRegistryPOLFile -TotalCount 4 -ErrorAction Stop) -join '') -ne '8082101103')
            {
                try
                {
                    #Delete it, if it's corrupted it is useless anyway
                    Remove-Item $PathToMachineRegistryPOLFile -Force -ErrorAction Stop
                }
                catch
                {
                    return $false
                }
            }
            
            }
            catch
            {
                return $false
            }
        }

        # Test for a User policy file - if there isn't one - as you were
        if(!(Test-Path -Path $PathToUserRegistryPOLFile -PathType Leaf)) {}
        #If there is a .pol file - test it
        else {
            try
            {
            If (((Get-Content -Encoding Byte -Path $PathToUserRegistryPOLFile -TotalCount 4 -ErrorAction Stop) -join '') -ne '8082101103')
            {
                try
                {
                    #Delete it, if it's corrupted it is useless anyway
                    Remove-Item $PathToUserRegistryPOLFile -Force -ErrorAction Stop
                }
                catch
                {
                    return $false
                }
            }
            
            }
            catch
            {
                return $false
            }
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

# CM doesn't care about the return nor does it rerun the discovery script after the remediation script has been run.
# If the remediation script failes it will still be reported as "Compliant".
# If you want to know if the remediation script failed, you need to catch the errors use an exit code, e.g. "Exit 1"

$Compliance