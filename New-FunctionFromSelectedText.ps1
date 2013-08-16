function New-FunctionFromSelectedText 
{
    function Get-VariableExtentText
    {
        param (
            [parameter(ValueFromPipeline)]
            [System.Management.Automation.Language.Ast]
            $ast
        )
        begin
        {
            $VariablesToExclude = '$_', '$true', '$false', '$?', '$$', '${', 
                '{', '$PSCmdlet', '$PSScriptRoot'
        }
        process
        {
            $variableType = [System.Management.Automation.Language.VariableExpressionAst]
            $ast.FindAll({$args[0] -is $variableType }, $false).Extent.Text |
                foreach {$_ -replace '@', '$' } |
                where {($VariablesToExclude -notcontains $_) }  |
                sort -Unique
        }
    }

    function Get-UnAssignedVariable
    {
        param ($Scriptblock)

        $ScriptblockAst = [scriptblock]::Create($Scriptblock).Ast
    
        $AllVariables = $ScriptblockAst | Get-VariableExtentText

        $Assignments = $ScriptblockAst.FindAll({$args[0] -is [System.Management.Automation.Language.AssignmentStatementAst]},$false)
        if ($Assignments)
        {
            $AssignedToVariable = $Assignments.left | Get-VariableExtentText
            Compare-Object $AssignedToVariable $AllVariables  | 
            where {$_.sideindicator -like '=>'} | 
            select -ExpandProperty InputObject
        }
        else
        {
            $AllVariables
        }
    }

    function Get-NewFunctionName
    {
        $MainWindow=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Topmost="True"
        WindowStartupLocation="CenterScreen"
        Title="PSHarp" Height="350" Width="425">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="35" />
            <RowDefinition Height="35" />
        </Grid.RowDefinitions>        

        <TextBox x:Name="NameBox" Grid.Row="0" Margin="5"></TextBox>
        <Button x:Name="DoneButton" Grid.Row="1" IsDefault="True" Margin="5">OK</Button>
    </Grid>
</Window>
'@

        $Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$MainWindow)))
        $NameBox=$Window.FindName("NameBox")
        $Button = $Window.FindName("DoneButton")
        $Button.add_Click({
            param($sender, $data)            
            $Window.close()
        })
        
        

        [void]$NameBox.Focus()
        [void]$Window.ShowDialog()
        $Namebox.text
    }

    $Name = Get-NewFunctionName

    $SourceFile = $psISE.CurrentFile
    $Scriptblock = $SourceFile.Editor.SelectedText
    $Parameters = Get-UnAssignedVariable $Scriptblock 

    $Definition = "Function $Name `n{"
    $Definition += "`n`t param (`n"
    
    $OFS = ",`n`t`t"
    $Definition += "`t`t$Parameters"
    
    $Definition += "`n`t)`n"
    $Definition += $Scriptblock
    $Definition += "`n}"    
    
    $ReplaceCommand = "$Name "
    foreach ($p in $Parameters)
    {
        $parameter = $p -replace '\$'
        $ReplaceCommand += "-{0} {1} " -f $parameter, $p
    }
    
    $HighlightStartLine = $SourceFile.Editor.CaretLine
    $HighlightStartColumn = $SourceFile.Editor.CaretColumn

    $EscapedText =  [regex]::Escape($SourceFile.Editor.SelectedText)
    $SourceFile.Editor.Text = $SourceFile.editor.text -replace $EscapedText, $ReplaceCommand
    

    $ISEFile=$psISE.CurrentPowerShellTab.Files.Add()
    $psISE.CurrentPowerShellTab.Files.SetSelectedFile($ISEFile)   
    $ISEFile.Editor.Text = $Definition    

}