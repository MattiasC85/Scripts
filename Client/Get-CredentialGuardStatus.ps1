$DevGuard = Get-CimInstance –ClassName Win32_DeviceGuard –Namespace root\Microsoft\Windows\DeviceGuard
$i=0
write-host $newLine
if ($DevGuard.SecurityServicesConfigured -contains 1) {write-host "Credential Guard is configured" -foregroundcolor "Green";$i=$i+2} else {write-host "Credential Guard is not configured" -foregroundcolor "Red"$i=$i-1}
if ($DevGuard.SecurityServicesRunning -contains 1) {write-host "Credential Guard service is running" -foregroundcolor "Green";$i=$i+3} else {write-host "Credential Guard service is not running" -foregroundcolor "Red";$i=$i-1}

#For silent status/return value
#Returns:
# -2 Non of the above are ok.
#  1 Only DevGuard.SecurityServicesConfigured is ok.
#  2 Only DevGuard.SecurityServicesRunning is ok.
#  5 Both are ok

#write-host $i
#return $i
