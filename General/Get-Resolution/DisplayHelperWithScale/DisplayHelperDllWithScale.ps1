#####################################################################################
#
#
#
#  2020-08-13
#  v 1.0.0.1
#  * Fixes and enables the use of RefreshRate (Hz) with "Set-Resolution"
#
#
#
#
#####################################################################################


Add-type -Path $PSScriptRoot\DisplayHelper.dll

Function Get-Monitors
{
    $DisplayHelper=[Displayhelper.DisplayInfo]::new()
    return $($DisplayHelper.GetDisplayMonitors())
}

Function Get-Resolution
{
    Param(
        [Parameter(Mandatory=$false)]
        [switch]$ShowAllResolutions
        )

        DynamicParam 
        {
                try
                {
                $Monitors='Monitors'
                $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
                $PSParamAttribute.Mandatory = $True
                $AttCol.Add($PSParamAttribute)
                $arrSet=([Displayhelper.DisplayInfo]::new() | % {$_.GetDisplayMonitors()} | Select-Object -Property Name).Name
                $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute([string[]]$arrset)    
                $AttCol.Add($ValidateSetAttribute)
                #$PSBoundParameters.Monitors=[string[]]$arrset
                $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($Monitors, [string[]], $AttCol)
                $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                $RuntimeParamDict.Add($Monitors, $RuntimeParameter)
                return $RuntimeParamDict
                }
                catch
                {
                    write-host $_

                }
          
        }
        Process 
        {
            $DisplayHelper=[Displayhelper.DisplayInfo]::new()
            $mons=$($DisplayHelper.GetDisplayMonitors())
            $return=foreach ($monitor in $mons)
            {
                
                if ($monitor.Name -in $PSBoundParameters.Monitors)
                {
                    if ($ShowAllResolutions -eq $false)
                    {
                        $monitor | Select-Object -Property Name,Width,Height,LogicalWidth,LogicalHeight,Scale
                    }
                    else
                    {
                        $current=$monitor | Select-Object -Property Name,Width,Height
                        $reslist=$monitor.GetResolutionList()
                        $reslist.Add([Displayhelper.Resolution]::new("Current",$current.Width,$current.Height,32,$monitor.Name))
                        #$dict = New-Object 'system.collections.generic.dictionary[[string],[System.Array]]'
                        $hasht=[hashtable]::new()
                        $hasht.Add($current.Name,$reslist)
                        #$hasht
                        $reslist
                                            
                    }
                }
            }

        return ($return)
        }
}

Function Set-Resolution
{
    [CmdletBinding()]
    Param
    
    ()

        DynamicParam 
        {
        $EC = $ExecutionContext.GetType().InvokeMember('_context', 'NonPublic, Instance, GetField', $null, $ExecutionContext, $null)
        $CCP = $EC.GetType().InvokeMember('CurrentCommandProcessor', 'NonPublic, Instance, GetProperty', $null, $EC, $null)
        $Binder = $CCP.GetType().InvokeMember('CmdletParameterBinderController', 'NonPublic, Instance, GetProperty', $null, $CCP, $null)
        $ValidProperties = 'ParameterNameSpecified', 'ParameterName', 'ArgumentSpecified', 'ArgumentValue'

        $UnboundArguments = $Binder.GetType().InvokeMember('UnboundArguments', 'NonPublic, Instance, GetProperty', $null, $Binder, $null) | ForEach-Object {

            if (-not $ValidProperties) 
            {
                $ValidProperties = $_.GetType().GetProperties('NonPublic, Instance').Name
            }

            $Props = [ordered] @{}

            foreach ($PropName in $ValidProperties) 
            {
                try 
                {
                    $Props[$PropName] = $_.GetType().InvokeMember($PropName, 'NonPublic, Instance, GetProperty', $null, $_, $null)
                }

                catch
                {
                }

            }

            [PSCustomObject] $Props

        }

        $fakeBoundNamed = @{}

        $fakeBoundUnNamed = New-Object System.Collections.ArrayList
        $CurrentParamName = $null

        foreach ($Arg in $UnboundArguments) 
        {

            if ($Arg.ParameterNameSpecified) 
            {
                if ($CurrentParamName) 
                {
                    $fakeBoundNamed[$CurrentParamName] = $true
                }

            $CurrentParamName = $Arg.ParameterName

            }

            if ($Arg.ArgumentSpecified) 
            {
                if (-not $CurrentParamName) 
                {
                    $fakeBoundUnNamed.Add($Arg.ArgumentValue) | Out-Null
                }

                else 
                {
                    $fakeBoundNamed[$CurrentParamName] = $Arg.ArgumentValue
                    $CurrentParamName = $null
                }

            }

        }

                $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                try
                {
                
                #MonitorName
                $MonitorName='MonitorName'
                $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
                $PSParamAttribute.Mandatory = $True
                $PSParamAttribute.ValueFromPipeline=$True
                $AttCol.Add($PSParamAttribute)
                $arrSet=([Displayhelper.DisplayInfo]::new() | % {$_.GetDisplayMonitors()} | Select-Object -Property Name).Name
                $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute([string[]]$arrset)    
                $AttCol.Add($ValidateSetAttribute)
                $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($MonitorName, [string], $AttCol)
                $RuntimeParamDict.Add($MonitorName, $RuntimeParameter)
                

                #Use the previous dynamicparam in the next

                if ($fakeBoundNamed.Count -gt 0)
                {
                    $Displ=$fakeBoundNamed["MonitorName"]
                    $Monitor=(Get-Monitors | Where-Object -Property Name -EQ $Displ)
                }

                #Resolution
                $Resolution='Resolution'
                $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
                $PSParamAttribute.Mandatory = $True
                $PSParamAttribute.ValueFromPipeline=$True
                $AttCol.Add($PSParamAttribute)
                $arrSet=([Displayhelper.DisplayInfo]::new() | % {$_.GetDisplayMonitors()} | Where-Object -Property Name -eq $Displ | % {$_.GetResolutionList()}).Name
                $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute([string[]]$arrset)
                $AttCol.Add($ValidateSetAttribute)
                $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($Resolution, [string], $AttCol)
                $RuntimeParamDict.Add($Resolution, $RuntimeParameter)
                
                if ($fakeBoundNamed.Count -gt 0)
                {
                    if ($fakeBoundNamed["Resolution"])
                    {
                        $ResOfChoice=$fakeBoundNamed["Resolution"]
                        Write-host "Resolution found"
                    }
                }


                #RefreshRate
                $RefreshRate='RefreshRate'
                $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
                $PSParamAttribute.Mandatory = $false
                $PSParamAttribute.ValueFromPipeline=$true
                $AttCol.Add($PSParamAttribute)
                $arrSet=(Get-Resolution -ShowAllResolutions -Monitors $Monitor.Name | Where-Object -Property Name -EQ $ResOfChoice).RefreshRates
                $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute([string[]]$arrset)
                $AttCol.Add($ValidateSetAttribute)
                $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($RefreshRate, [int], $AttCol)
                $RuntimeParamDict.Add($RefreshRate, $RuntimeParameter)
                
                
                }
                catch
                {
                    #$errMsg=[System.Windows.Forms.MessageBox]::Show($_)

                }
                return $RuntimeParamDict
          
        }
        Process 
        {
            $DisplayHelper=[Displayhelper.DisplayInfo]::new()
            $mons=$($DisplayHelper.GetDisplayMonitors())
            $return=foreach ($monitor in $mons)
            {
                
                if ($monitor.Name -in $PSBoundParameters.MonitorName)
                {
                       #$MsgHit=[System.Windows.Forms.MessageBox]::Show($monitor.Name)
                       #$MsgHit=[System.Windows.Forms.MessageBox]::Show($PSBoundParameters.Resolution)
                       $reslist=([Displayhelper.DisplayInfo+DisplayMonitor]$monitor).GetResolutionList()
                       $ChoosenRes=$reslist | Where-Object -Property Name -eq $PSBoundParameters.Resolution
                       if ($RefreshRate)
                       {
                            $var=([Displayhelper.DisplayInfo+DisplayMonitor]$monitor).SetMonitorResolution($ChoosenRes,$PSBoundParameters.RefreshRate)
                       }

                       $var
                }
                    
                
            }

        return $return
        }
}

Function Get-MonitorScale
{
    [CmdletBinding()]
    Param
    
    ()

        DynamicParam 
        {

                $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                try
                {
                
                    #MonitorName
                    $MonitorName='MonitorName'
                    $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
                    $PSParamAttribute.Mandatory = $True
                    $PSParamAttribute.ValueFromPipeline=$True
                    $AttCol.Add($PSParamAttribute)
                    $arrSet=([Displayhelper.DisplayInfo]::new() | % {$_.GetDisplayMonitors()} | Select-Object -Property Name).Name
                    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute([string[]]$arrset)    
                    $AttCol.Add($ValidateSetAttribute)
                    $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($MonitorName, [string], $AttCol)
                    $RuntimeParamDict.Add($MonitorName, $RuntimeParameter)
                
                }
                catch
                {
                    #$errMsg=[System.Windows.Forms.MessageBox]::Show($_)

                }
                return $RuntimeParamDict
          
        }
        Process 
        {
            $DisplayHelper=[Displayhelper.DisplayInfo]::new()
            $mons=$($DisplayHelper.GetDisplayMonitors())
            $return=foreach ($monitor in $mons)
            {
                if ($monitor.Name -eq $PSBoundParameters.MonitorName)
                {
                    $ret=$monitor.GetMonitorScaleInfo()
                    $ret                    
                }
                    
                
            }

        return $return
        }
}