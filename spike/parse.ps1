cls

function Get-WhereClause {
    param($s)

    $h=@{
        v='variable'
        f='function'
        c='command'
    }

    if($s -and $s.IndexOf(':') -eq 1) {
        $type, $name = $s.split(':')    
        'where {{ $_.type -eq "{0}" -and $_.name -match "{1}" }}' -f $h.$type, $name
    }
}

Get-WhereClause 'v:$ast'
Get-WhereClause 'f:$ast'
Get-WhereClause 'c:$ast'