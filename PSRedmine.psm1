<#

http://www.redmine.org/projects/redmine/wiki/Rest_api

#>

Add-Type -TypeDefinition @'
public enum ResourceType {
    project,
    version,
    issue,
    membership,
    user
}
public enum StatusType {
    open,
    locked,
    closed
}
public enum SharingType {
    none,
    descendants,
    hierarchy,
    tree,
    system
}
'@

##########

Function Connect-Redmine {
<#
   .SYNOPSIS
    Connect to the Redmine server
   .DESCRIPTION
    Connect to the Redmine server and set the authorization variable in script scope
   .EXAMPLE
    Connect-Redmine http://testredmine
   .EXAMPLE
    Connect-Redmine testredmine
   .LINK
    https://github.com/hamletmun/PSRedmine
#>

    Param(
        [Parameter(Mandatory=$True)][String]$script:Server
    )

    $Credential = Get-Credential -UserName $env:USERNAME -Message "Credential for $script:Server"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
<#
    $WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $IWRParams = @{
        Credential = $Credential
        SessionVariable = Get-Variable -name WebSession -ValueOnly
        Method = 'GET'
        Uri = $script:Server + '/login'
    }
    $Response = Invoke-WebRequest @IWRParams

    $script:WebSession = Get-Variable -name $WebSession -ValueOnly
#>
#
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(
        ('{0}:{1}' -f $Credential.UserName, $Credential.GetNetworkCredential().Password)
    )
    $script:Authorization = 'Basic {0}' -f ([Convert]::ToBase64String($bytes))

    $IWRParams = @{
        Headers = @{ Authorization = $script:Authorization }
        Method = 'GET'
        Uri = $script:Server + '/login'
    }

    $Response = Invoke-WebRequest @IWRParams
#>

<#
    #$Response.Content -match "<meta name=`"csrf-token`" content=`"(.*)`" />" | Out-Null
    #$script:CSRFToken = $Matches[1]

    #$script:CSRFToken = ($Response.ParsedHtml.getElementsByTagName('META') | ? { $_.name -eq 'csrf-token' }).content

    #$script:CSRFToken = $Response.Forms.Fields['authenticity_token']

    #$script:WebSession = Get-Variable -name $script:WebSession -ValueOnly

#>
}

Function Disconnect-Redmine {
<#
   .SYNOPSIS
    Disconnect from the Redmine server
   .DESCRIPTION
    Disconnect from the Redmine server
   .EXAMPLE
    Connect-Redmine http://demo.redmine.org
   .EXAMPLE
    Connect-Redmine demo.redmine.org
   .LINK
    https://github.com/hamletmun/PSRedmine
#>
    #Remove-Variable -Name WebSession -Scope script
    Remove-Variable -Name Authorization -Scope script
}

##########

Function Send-HTTPRequest {
    Param(
        [Parameter(Mandatory=$true)][String]$Method,
        [Parameter(Mandatory=$true)][String]$Uri,
        [String]$Body
    )
    $IRMParams = @{
        #WebSession = $script:WebSession
        Headers = @{ Authorization = $script:Authorization }
        Method = $Method
        Uri = $script:Server + $Uri
    }
    If ($Body) {
        $UTF8 = [System.Text.Encoding]::UTF8
        $IRMParams += @{
            ContentType = 'application/json'
            Body = $UTF8.GetBytes($Body)
        }
    }
    $Response = Invoke-RestMethod @IRMParams

    Return $Response
}

Function Get-Multipages {
    Param(
        [Parameter(Mandatory=$true)][String]$URI
    )
    $offset = 0
    $limit = 100
    $Response = Send-HTTPRequest -Method GET -URI "$URI`?offset=$offset&limit=$limit"
    $remain = $Response.total_count
    While ($remain -gt 0) {
        [Array]$collection += $Response.$("$type`s")
        $remain -= $limit
        $offset += $limit
        if ($remain -lt 100) { $limit = $remain}
        #Write-Host $offset $limit $remain
        $Response = Send-HTTPRequest -Method GET -URI "$URI`?offset=$offset&limit=$limit"
    }
    Return $collection
}

##########

Function Search-RedmineResource {
<#
   .SYNOPSIS
    Search Redmine resource by keyword
   .DESCRIPTION
    Search Redmine resource by keyword
   .EXAMPLE
    Search-RedmineResource project demoproj
   .EXAMPLE
    Search-RedmineResource version demover -project_id demoproj
   .LINK
    https://github.com/hamletmun/PSRedmine
#>
    Param(
        [Parameter(Mandatory=$true)][ResourceType]$type,
        [String]$keyword,
        [String]$project_id
    )

    Switch ($type) {
        'version' {
            $Response = Send-HTTPRequest -Method GET -URI "/projects/$project_id/$type`s.json"
            $collection = $Response.$("$type`s")
        }
        'membership' { $collection = Get-Multipages "/projects/$project_id/$type`s.json" }
        default { $collection = Get-Multipages "/$type`s.json" }
    }

    Switch ($type) {
        'issue' { Return ($collection | Where-Object { $_.subject -Match $keyword }) }
        'user' { Return ($collection | Where-Object { $_.login -Match $keyword }) }
        'membership' { Return ($collection | Where-Object { $_.user.name -Match $keyword }) }
        default { Return ($collection | Where-Object { $_.name -Match $keyword }) }
    }
}

Function New-RedmineResource {
<#
   .SYNOPSIS
    Create a new Redmine resource
   .DESCRIPTION
    Create a new Redmine resource
   .EXAMPLE
    New-RedmineResource project -identifier test13 -name test13
   .EXAMPLE
    New-RedmineResource version -project_id test13 -name testver
   .EXAMPLE
    New-RedmineResource issue -project_id test13 -subject testissue
   .LINK
    https://github.com/hamletmun/PSRedmine
#>
    Param(
        [Parameter(Mandatory=$true)][ResourceType]$type,
        [String]$project_id,
        [String]$identifier,
        [String]$name,
        [String]$description,
        [Int]$default_version_id,
        [Int]$issue_id,
        [Int]$tracker_id,
        [String]$status_id,
        [Int]$version_id,
        [String]$subject,
        [String]$notes,
        [Datetime]$due_date,
        [StatusType]$status,
        [SharingType]$sharing
    )

    If ($type -eq 'issue') {
        $JSON = @{ issue = @{} }
        If ($project_id) { $JSON.issue.Add( 'project_id', $project_id )}
        If ($tracker_id) { $JSON.issue.Add( 'tracker_id', $tracker_id )}
        If ($status_id) { $JSON.issue.Add( 'status_id', $status_id )}
        If ($version_id) { $JSON.issue.Add( 'fixed_version_id', $version_id )}
        If ($subject) { $JSON.issue.Add( 'subject', $subject )}
        If ($description) { $JSON.issue.Add( 'description', $description )}
        If ($notes) { $JSON.issue.Add( 'notes', $notes )}
        $JSON = $JSON | ConvertTo-Json

        #Write-Host $JSON

        $Response = Send-HTTPRequest -Method POST -URI /issues.json -Body $JSON
    }
    Elseif ($type -eq 'version') {
        $JSON = @{ version = @{} }
        If ($name) { $JSON.version.Add( 'name', $name )}
        If ($description) { $JSON.version.Add( 'description', $description )}
        If ($due_date) { $JSON.version.Add( 'due_date', $due_date.ToString("yyyy-MM-dd") )}
        If ($status) { $JSON.version.Add( 'status', $status.ToString() )}
        If ($sharing) { $JSON.version.Add( 'sharing', $sharing.ToString() )}
        $JSON = $JSON | ConvertTo-Json

        #Write-Host $JSON

        $Response = Send-HTTPRequest -Method POST -URI /projects/$project_id/versions.json -Body $JSON
    }
    Elseif ($type -eq 'project') {
        $JSON = @{ project = @{} }
        If ($name) { $JSON.project.Add( 'name', $name )}
        If ($description) { $JSON.project.Add( 'description', $description )}
        If ($identifier) { $JSON.project.Add( 'identifier', $identifier )}
        If ($default_version_id) { $JSON.project.Add( 'default_version_id', $default_version_id )}
        $JSON = $JSON | ConvertTo-Json

        #Write-Host $JSON

        $Response = Send-HTTPRequest -Method POST -URI "/projects.json" -Body $JSON
    }

    $Response
}

Function Get-RedmineResource {
<#
   .SYNOPSIS
    Get Redmine resource item by id
   .DESCRIPTION
    Get Redmine resource item by id
   .EXAMPLE
    Get-RedmineResource project 438
   .EXAMPLE
    Get-RedmineResource version 398
   .LINK
    https://github.com/hamletmun/PSRedmine
#>
    Param(
        [Parameter(Mandatory=$true)][ResourceType]$type,
        [Parameter(Mandatory=$true)][String]$id
    )

    Switch -Regex ($type) {
        '\A(issue)\Z' { $Response = (Send-HTTPRequest -Method GET -URI "/$type`s/$id.json?include=journals,watchers").issue }
        '\A(user)\Z' { $Response = (Send-HTTPRequest -Method GET -URI "/$type`s/$id.json?include=memberships,groups").user }
        default { $Response = (Send-HTTPRequest -Method GET -URI "/$type`s/$id.json").$type }
    }

    $Response
}

Function Edit-RedmineResource {
<#
   .SYNOPSIS
    Edit a Redmine resource
   .DESCRIPTION
    Edit a Redmine resource
   .EXAMPLE
    Edit-RedmineResource project -id test13 -description 'change description'
   .EXAMPLE
    Edit-RedmineResource version -id 406 -due_date 2018-09-29
   .EXAMPLE
    Edit-RedmineResource issue -id 29551 -version_id 406
   .LINK
    https://github.com/hamletmun/PSRedmine
#>
    Param(
        [Parameter(Mandatory=$true)][ResourceType]$type,
        [Parameter(Mandatory=$true)][String]$id,
        [String]$project_id,
        [String]$name,
        [String]$description,
        [Int]$default_version_id,
        [Int]$issue_id,
        [Int]$tracker_id,
        [String]$status_id,
        [Int]$version_id,
        [String]$subject,
        [String]$notes,
        [Datetime]$due_date,
        [StatusType]$status,
        [SharingType]$sharing
    )

    If ($type -eq 'issue') {
        $JSON = @{ issue = @{} }
        If ($project_id) { $JSON.issue.Add( 'project_id', $project_id )}
        If ($tracker_id) { $JSON.issue.Add( 'tracker_id', $tracker_id )}
        If ($status_id) { $JSON.issue.Add( 'status_id', $status_id )}
        If ($version_id) { $JSON.issue.Add( 'fixed_version_id', $version_id )}
        If ($subject) { $JSON.issue.Add( 'subject', $subject )}
        If ($description) { $JSON.issue.Add( 'description', $description )}
        If ($notes) { $JSON.issue.Add( 'notes', $notes )}
        $JSON = $JSON | ConvertTo-Json

        $Response = Send-HTTPRequest -Method PUT -URI /issues/$id.json -Body $JSON

    } Elseif ($type -eq 'version') {
        $JSON = @{ version = @{} }
        If ($name) { $JSON.version.Add( 'name', $name )}
        If ($description) { $JSON.version.Add( 'description', $description )}
        If ($due_date) { $JSON.version.Add( 'due_date', $due_date.ToString("yyyy-MM-dd") )}
        If ($status) { $JSON.version.Add( 'status', $status.ToString() )}
        If ($sharing) { $JSON.version.Add( 'sharing', $sharing.ToString() )}
        $JSON = $JSON | ConvertTo-Json

        $Response = Send-HTTPRequest -Method PUT -URI /versions/$id.json -Body $JSON

    } Elseif ($type -eq 'project') {
        $JSON = @{ project = @{} }
        If ($name) { $JSON.project.Add( 'name', $name )}
        If ($description) { $JSON.project.Add( 'description', $description )}
        If ($default_version_id) { $JSON.project.Add( 'default_version_id', $default_version_id )}
        $JSON = $JSON | ConvertTo-Json

        $Response = Send-HTTPRequest -Method PUT -URI "/projects/$id.json" -Body $JSON
    }
}

Function Remove-RedmineResource {
<#
   .SYNOPSIS
    Remove a Redmine resource
   .DESCRIPTION
    Remove a Redmine resource. You need administrator permission to delete a project.
   .EXAMPLE
    Remove-RedmineResource issue 29551
   .LINK
    https://github.com/hamletmun/PSRedmine
#>
    Param(
        [Parameter(Mandatory=$true)][ResourceType]$type,
        [Parameter(Mandatory=$true)][String]$id
    )

    $Response = Send-HTTPRequest -Method DELETE -URI "/$type`s/$id.json"
}
