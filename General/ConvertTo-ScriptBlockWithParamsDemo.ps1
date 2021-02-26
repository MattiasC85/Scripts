<##########################################################################################################

V.0.0.1 Alpha

Demo of 'ConvertTo-ScriptBlockWithParams'

Making it easier to pass a param, such as a [switch], to a powershell function while using 
"Invoke-Command" to execute it on a remote computer.


eg.
Invoke-CommandWithAnyParamsDemo -ComputerName "x" -ShouldForce
Invoke-CommandWithAnyParamsDemo -ShouldForce
Invoke-CommandWithAnyParamsDemo -DemoInt 2 -ComputerName "x"

2021-02-26: Initial Alpha release 



##########################################################################################################>

Function Invoke-CommandWithAnyParamsDemo
{
[CmdletBinding()]
    param(
        [Parameter(Mandatory=$False)]
        [string]$ComputerName,
        [Parameter(Mandatory=$False)]
        [int]$DemoInt=30,
        [Parameter(Mandatory=$False)]
        [switch]$ShouldForce=$False
    )

    Function Get-HostName
    {
        param(
            [Parameter(Mandatory=$True,
            ParameterSetName="ShutdownType1")]
            [Switch]$Restart,
            [Parameter(Mandatory=$True,
            ParameterSetName="ShutdownType2")]
            [Switch]$Shutdown,
            [Parameter(Mandatory=$False)]
            [Switch]$Force,
            [Parameter(Mandatory=$False)]
            [int]$Countdown=30,
            [Parameter(Mandatory=$False)]
            [bool]$BoolTest=$false,
            [Parameter(Mandatory=$False)]
            [string]$MyTestString="TestString"
            )

            $OsInstallDate=([WMI]'').ConvertToDateTime((Get-WmiObject Win32_OperatingSystem).InstallDate)

            Write-host "Restart: $Restart > Type: $($Restart.GetType().Name)"
            write-host "Shutdown: $Shutdown > Type: $($Shutdown.GetType().Name)"
            write-host "Force: $Force > Type: $($Force.GetType().Name)"
            write-host "CountDown: $Countdown > Type: $($Countdown.GetType().Name)"
            write-host "BoolTest: $BoolTest > Type: $($BoolTest.GetType().Name)"
            write-host "MyTestString: $MyTestString > Type: $($MyTestString.GetType().Name)"

            $name=hostname
            Write-Host "The command was executed on $name"
            write-host "OsInstallDate: $($OsInstallDate.ToLocalTime())"
    }

    Function ConvertTo-ScriptBlockWithParams
    {
        param(
        [Parameter(Mandatory=$True)]
        [String]$FunctionName,
        [Parameter(Mandatory=$True)]
        [Hashtable]$Parameters

        )
    
        try
        {
            $MyFunction=(get-item Function:$FunctionName)
            $params=$Parameters
            $ScriptBlock=[ScriptBlock]::Create(".{$($MyFunction.ScriptBlock)} $(&{$args} @params)")
        }

        catch{
        Write-host "error getting function"
        }
        return $ScriptBlock
    
    }
    
########################### MAIN ########################### 

    if (!($ComputerName))
    {
        $ComputerName=$env:COMPUTERNAME
    }
 
    $MyFunction=(get-item Function:\Get-HostName)
    $GetHostNameParams = @{
        "Restart"='$true'                   #Please notice only here to show how to override the default without a param
        "Countdown"=$DemoInt
        "MyTestString"='"Edited string"'    #Please notice the '" "' surrounding the string when a space is present 
        "BoolTest"='$true'
        "Force"="`$$($ShouldForce.IsPresent)"
        }
    
    #write-host "`$$($ShouldForce.IsPresent)"
    Write-Host -ForegroundColor Cyan "`$GetHostNameParams = @{
        'Restart'='$true'                 #Please notice only here to show how to override the default without a param
        'Countdown'=$DemoInt
        'MyTestString'='Edited string'    #Please notice the '" "' surrounding the string when a space is present 
        'BoolTest'='$true'
        'Force'='$($ShouldForce.IsPresent)'
        }"

    'Invoke-Command -ScriptBlock ${Function:Get-HostName} -ComputerName $ComputerName -ArgumentList $GetHostNameParams' | % {Write-host $_; Invoke-Expression $_}
    'Invoke-Command -ScriptBlock ${Function:Get-HostName} -ComputerName $ComputerName -ArgumentList ("-Restart: $true")' | % {Write-host $_; Invoke-Expression $_}
    'Invoke-Command -ScriptBlock ${Function:Get-HostName} -ComputerName $ComputerName -ArgumentList ("Restart:$true")' | % {Write-host $_; Invoke-Expression $_}
    'Invoke-Command -ScriptBlock ${Function:Get-HostName} -ComputerName $ComputerName -ArgumentList ("Restart"="$true")' | % {Write-host $_; Invoke-Expression $_}

    Write-Host -ForegroundColor Yellow "I must be doing something wrong. This isn't working"
    Write-Host -ForegroundColor Yellow "I'm no PoSh guru, took one 'Introduction class' once, so there must be something that I havn't thought of."
    Write-Host -ForegroundColor Yellow "That beeing said. If I need it, there's surely more ppl needing it as well."
    Write-Host ""
    write-host -ForegroundColor Green "Now lets try 'ConvertTo-ScriptBlockWithParams'"
    Read-Host -Prompt "Push Enter to continue"
    '$GetHostNameSB=(ConvertTo-ScriptBlockWithParams -FunctionName "Get-HostName" -Parameters $GetHostNameParams)' | % {Write-host $_ -ForegroundColor Cyan; Invoke-Expression $_}
    #Write-host "################### output of Get-HostName ###################"
    #Write-Host ""
    'Invoke-Command -ScriptBlock $GetHostNameSB -ComputerName $ComputerName' | % {Write-host -ForegroundColor Yellow $_;Write-host "################### output of Get-HostName ###################";Write-Host ""; Invoke-Expression $_}
    
}