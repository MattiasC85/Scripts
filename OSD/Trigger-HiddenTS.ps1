<#

Edit2:
Oh, think I know what happend now... Went from 1810->1906 a week ago and the pre-production went live this Sunday.
Darn _*-Policies :P

Only tested this to after the "state restore"-group.
I made a big mistake, assuming that if it works up until then, it would work for the rest of the OSD as well.
But the client agent is actually initiated for program/application installations. And that will fail since the 
client will recieve the unmodified policy.
Working on  a fix atm.

#>
Param (
        [parameter(Mandatory = $true)]
        [string]$TSDeploymentID
    )


$date=(Get-date)

$SMSClient=[wmiclass]"root/ccm:SMS_Client"

$pol=Get-CimInstance -class ccm_Policy -Namespace root/ccm/Policy/Machine/ActualConfig | Where-Object {($_.ADV_AdvertisementID -eq $TSDeploymentID)}
$MainTS=$pol | Where-Object {($_.CimClass.CimClassName -eq "CCM_TaskSequence") -and ($_.TS_Type -eq "2")}
$MainTS.ADV_MandatoryAssignments=$true
$MainTS | Set-CimInstance

[xml]$TSReqs=$MainTS.Prg_Requirements
$SchedID=$TSReqs.SWDReserved.ScheduledMessageID


if ($pol)
{
    foreach ($cim in $pol)
    {
        write-host $Cim.PKG_Name $Cim.ADV_ActiveTime
        $cimInstance=Get-CimInstance $cim
        $out=Set-CimInstance -InputObject $cimInstance -Property @{ADV_ActiveTime=[datetime]::Today} -PassThru | out-null

    }
}

([wmiclass]"root\ccm:SMS_Client").TriggerSchedule($SchedID)
