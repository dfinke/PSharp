$MainWindow=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Topmost="True"
        WindowStartupLocation="CenterScreen"
        Title="PSHarp" Height="350" Width="425">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="35" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <Button 
            IsDefault="True" IsCancel="True" 
            Background="Transparent" Margin="3"/>

        <TextBox x:Name="SearchBox" Grid.Row="0" Margin="5"></TextBox>
        <ListView x:Name="ResultsPane" Grid.Row="1" Margin="5" IsSynchronizedWithCurrentItem="True">
            <ListView.View>
            <GridView>
                <GridViewColumn Width="140" Header="Type" DisplayMemberBinding="{Binding Type}"/>
                <GridViewColumn Width="140" Header="Name" DisplayMemberBinding="{Binding Name}"/>
            </GridView>
            </ListView.View>
        </ListView>
    </Grid>
</Window>
'@

function New-ASTItem {
    param($Type, $Name, $Extent)

    [PSCustomObject]@{
        Type              = $Type
        Name              = $Name
        StartLineNumber   = $Extent.StartLineNumber
        StartColumnNumber = $Extent.StartColumnNumber
        EndLineNumber     = $Extent.EndLineNumber
        EndColumnNumber   = $Extent.EndColumnNumber
        #FullName          = $FullName
        #FileName          = Split-Path -Leaf $FullName -ErrorAction SilentlyContinue
    }
}

function Get-AstDetail {
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        $FullName
    )

    Begin {
        $FunctionDefinitionAst = [System.Management.Automation.Language.FunctionDefinitionAst]
        $VariableExpressionAst = [System.Management.Automation.Language.VariableExpressionAst]
        $CommandAst = [System.Management.Automation.Language.CommandAst]            
    }

    Process {

        if(!$FullName) {
            $src=$psISE.CurrentFile.Editor.Text
        } else {
            $src=[System.IO.File]::ReadAllText($FullName)
        }

        $fileAST=[System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)
        
        $details = {
            param($ast)

            if($ast -is $FunctionDefinitionAst) {
                $ast
            } elseif ($ast -is $VariableExpressionAst) {
                $ast
            } elseif ($ast -is $CommandAst) {
                $as
            }
        }

        $filteredAST = $fileAST.FindAll($details,$true)

        switch ($filteredAST) {
            {$_ -is $FunctionDefinitionAst} { New-ASTItem Function $_.name $_.extent }
            {$_ -is $CommandAst}            { New-ASTItem Command  $_.Extent.Text $_.extent }
            {$_ -is $VariableExpressionAst} { New-ASTItem Variable $_.extent.text $_.extent }
        }
    }
}

function Out-SearchView {
    param(
        $list,
        [ScriptBlock]$PreviewKeyUp,
        [ScriptBlock]$SelectionChanged
    )

    if(!$PreviewKeyUp) {
        $PreviewKeyUp = {        
            param($sender, $info)        
        
            if($info.key -eq 'down') {
                $ResultsPane.Focus()
                $ResultsPane.SelectedIndex=0
            
                return
            }
        
            try {
                DoParseSearch $SearchBox.Text
            } catch {}
        }
    }

    if(!$SelectionChanged) {
        $SelectionChanged = {
            param($sender, $data)
            if($data.AddedItems) {
                $Selected=$data.AddedItems
                $psISE.CurrentFile.Editor.Select(
                    $Selected.StartLineNumber, 
                    $Selected.StartColumnNumber, 
                    $Selected.EndLineNumber, 
                    $Selected.EndColumnNumber
                )
            }
        }
    }

    $Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$MainWindow)))
    $SearchBox=$Window.FindName("SearchBox")
    $ResultsPane=$Window.FindName("ResultsPane")

    $ResultsPane.ItemsSource=@($list)
    $ResultsPane.DisplayMemberPath="Name"

    [void]$SearchBox.Focus()

    $SearchBox.add_PreviewKeyUp($PreviewKeyUp)
    $ResultsPane.add_SelectionChanged($SelectionChanged)

    [void]$Window.ShowDialog()
}


$ShowIt = { Out-SearchView (Get-AstDetail) }

function DoParseSearch ($search) {

    if(!$search) {return}

    $h=@{
        v='variable'
        f='function'
        c='command'
    }

    $whereBlock = {$_.name -match $search}
    if($search -and $search.IndexOf(':') -eq 1) {
        $type, $name = $search.split(':')    
        $whereBlock = '{{ $_.type -eq "{0}" -and $_.name -match "{1}" }}' -f $h.$type, $name | Invoke-Expression            
    } 

    $ResultsPane.ItemsSource = @($list | Where $whereBlock)
}

function Get-ScriptItem {

    # Used/Refactored Get-CurrentToken from ISEPack
    $currentFile = $psise.CurrentFile.Editor
    $tokens = [Management.Automation.PSParser]::Tokenize($currentFile.Text, [ref]$null)
    $line   = $currentFile.CaretLine
    $column = $currentFile.CaretColumn

    foreach ($token in $tokens) {
        if ($token.StartLine -eq $line -and $token.EndLine -eq $line) {
            if ($token.StartColumn -le $column -and $token.EndColumn -ge $column) {
                $token
            }
        }        
    }
}

function Find-DetailByType {
    $token = Get-ScriptItem
    
    $token.Type|Out-Host
    switch -regex ($token.Type) {
        "CommandArgument|Command" {
            $TokenType="Command|Function"
            $Name='\b{0}\b' -f $token.Content
        }

        "Variable" {
            $TokenType="Variable"
            $Name='\$' + $token.Content + '\b'
        }
    }
    
    $list  = Get-AstDetail | where {$_.Type -match $TokenType -and $_.Name -match $Name}
    Out-SearchView $list
}

function Add-MenuItem {
    param([string]$DisplayName, [scriptblock]$SB, [string]$ShortCut)
    
    $menu=$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | Where {$_.DisplayName -Match $DisplayName}
    
    if($menu) {
        [void]$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Remove($menu)
    }
    
    [void]$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add($DisplayName, $SB, $ShortCut)
}


Add-MenuItem "_PSharp" $ShowIt "CTRL+Shift+X"
Add-MenuItem "_Get ScriptItem" ([scriptblock]::Create((Get-Command Find-DetailByType).Definition)) "CTRL+Shift+T"