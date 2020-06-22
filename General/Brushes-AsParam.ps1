[CmdletBinding()]
Param
(

[Parameter(Mandatory=$false, position=1)]
[System.ConsoleColor]$ConsoleColor



)
 DynamicParam {
        Add-Type -AssemblyName System.Drawing, PresentationCore
        
        $DynColor = 'DynColor'
        $AttCol = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $PSParamAttribute = New-Object System.Management.Automation.ParameterAttribute
        $PSParamAttribute.Mandatory = $False
        $AttCol.Add($PSParamAttribute) 
        $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttCol.Add($ValidateSetAttribute)
        $PSBoundParameters.DynColor= "White"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($DynColor, [string], $AttCol)
        $RuntimeParamDict.Add($DynColor, $RuntimeParameter)
        
        return $RuntimeParamDict
    }


Process
{
    Add-Type -AssemblyName System.Windows.Forms
    #$ParamColor=$PSBoundParameters.DynColor

    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Form=New-Object system.Windows.Forms.Form
    
    $Form.ClientSize='400,400'
    
    $Form.text="Form"

    $Form.TopMost=$false
    $Form.BackColor=$PSBoundParameters.DynColor
    $Form.ShowDialog()
}
