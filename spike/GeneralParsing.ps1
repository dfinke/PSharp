cls

#IsPublic IsSerial Name                                     BaseType                                                                                                                       
#-------- -------- ----                                     --------                                                                                                                       
#True     False    ScriptBlockAst                           System.Management.Automation.Language.Ast                                                                                      
#True     False    NamedBlockAst                            System.Management.Automation.Language.Ast                                                                                      
#True     False    PipelineAst                              System.Management.Automation.Language.PipelineBaseAst                                                                          
#True     False    CommandExpressionAst                     System.Management.Automation.Language.CommandBaseAst                                                                           
#True     False    InvokeMemberExpressionAst                System.Management.Automation.Language.MemberExpressionAst                                                                      
#True     False    TypeExpressionAst                        System.Management.Automation.Language.ExpressionAst                                                                            
#True     False    StringConstantExpressionAst              System.Management.Automation.Language.ConstantExpressionAst 

#IsPublic IsSerial Name                        BaseType                                                   
#-------- -------- ----                        --------                                                   
#True     False    ScriptBlockAst              System.Management.Automation.Language.Ast                  
#True     False    NamedBlockAst               System.Management.Automation.Language.Ast                  
#True     False    FunctionDefinitionAst       System.Management.Automation.Language.StatementAst         
#True     False    ScriptBlockAst              System.Management.Automation.Language.Ast                  
#True     False    NamedBlockAst               System.Management.Automation.Language.Ast                  
#True     False    PipelineAst                 System.Management.Automation.Language.PipelineBaseAst      
#True     False    CommandExpressionAst        System.Management.Automation.Language.CommandBaseAst       
#True     False    StringConstantExpressionAst System.Management.Automation.Language.ConstantExpressionAst

$src=@'
#$a=@()
#$h=@{}
#$b=1
#1..10 | % {$_}
function t {
    param($a,$b) 
    
    $a+=1
    $a
}
#filter x {'t'}
#workflow y{'w'}
'@

$fileAST=[System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)
$fileAST.FindAll({
    param($ast)
    #1
    $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
},1) | % {
    $_.body.endblock.statements #.paramblock.parameters # parent.parent.parent #.gettype()
    #$_.extent.text
    #$_.PipelineElements.expression
} | ft -a