#Requires -Version 5.0

$DebugPreference = "SilentlyContinue"

enum ResourceType {
	project
	issue
	membership
	user
	version
}

enum StatusType {
	open
	locked
	closed
}

enum SharingType {
	none
	descendants
	hierarchy
	tree
	system
}

#region Class

Class Redmine {
	Hidden [Parameter(Mandatory=$True)][String]$Server
	Hidden [Microsoft.PowerShell.Commands.WebRequestSession]$Session
	Hidden [String]$CSRFToken
	$project
	$issue
	$membership
	$user
	$version

	# Constructors

	Redmine([String]$Server, [Hashtable]$IWRParams) {
		$this.Server = $Server
		$this.signin($IWRParams)
	}

	# Methods

	Hidden signin($IWRParams) {
		$sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
		$IWRParams += @{
			SessionVariable = Get-Variable -name sess -ValueOnly
			Method = 'GET'
			Uri = "$($this.Server)/login"
		}
		$Response = Invoke-WebRequest @IWRParams
		$this.CSRFToken = $Response.Forms.Fields['authenticity_token']
		$this.Session = Get-Variable -name $sess -ValueOnly

		$this.project = $this.new('project')
		$this.issue = $this.new('issue')
		$this.membership = $this.new('membership')
		$this.version = $this.new('version')
		$this.user = $this.new('user')
	}

	Hidden signout() {
		$IRMParams = @{
			WebSession = $this.Session
			Method = 'POST'
			Uri = "$($this.Server)/logout"
			Headers = @{'X-CSRF-Token'=$this.CSRFToken}
		}
		Invoke-RestMethod @IRMParams
	}

	[PSCustomObject]request($IRMParams) {
		$IRMParams += @{
			WebSession = $this.Session
		}
		$Response = Invoke-RestMethod @IRMParams
		return $Response
	}

	[PSCustomObject]new($type) {
		$Object = New-Object $type
		$Object.Server = $this.Server
		$Object.Session = $this.Session
		return $Object
	}

}

Class BaseResource {
	Hidden [Parameter(Mandatory=$True)][String]$Server
	Hidden [Microsoft.PowerShell.Commands.WebRequestSession]$Session
	[String]$id
	[String]$description
	[String]$created_on
	[String]$updated_on

	# Methods

	[Array]to_json() {
		$type = $this.GetType().Name.ToLower()
		$UTF8 = [System.Text.Encoding]::UTF8
		$JSON = @{ $type = @{} }
		foreach ( $property in $this.psobject.properties.name ) {
			If ([String]::IsNullOrWhiteSpace($this.$property)) { 
				Switch ($property) {
					'watchers' { $JSON.$type.Add( 'watcher_user_ids', $this.watchers.id ) }
				}
			} Else {
				Switch ($property) {
					'project' { $JSON.$type.Add( 'project_id', $this.project.id ) }
					'tracker' { $JSON.$type.Add( 'tracker_id', $this.tracker.id ) }
					'status' { $JSON.$type.Add( 'status_id', $this.status.id ) }
					'priority' { $JSON.$type.Add( 'priority_id', $this.priority.id ) }
					'parent' { $JSON.$type.Add( 'parent_issue_id', $this.parent.id ) }
					'assigned_to' { $JSON.$type.Add( 'assigned_to_id', $this.assigned_to.id ) }
					'category' { $JSON.$type.Add( 'category_id', $this.category.id ) }
					default { $JSON.$type.Add( $property, $this.$property ) }
				}
			}
		}
		$JSON = $JSON | ConvertTo-Json -Depth 10
		return $UTF8.GetBytes($JSON)
	}

	[PSCustomObject]request($Method, $Uri) {
		$IRMParams = @{
			WebSession = $this.Session
			Method = $Method
			Uri = $this.Server + '/' + $Uri
		}
		If ($Method -Match 'POST|PUT') {
			$IRMParams += @{
				ContentType = 'application/json'
				Body = $this.to_json()
			}
		}
		$Response = Invoke-RestMethod @IRMParams
		return $Response
	}

	[PSCustomObject]get($id) {
		$type = $this.GetType().Name.ToLower()

		$Object = New-Object $type
		$Object.Server = $this.Server
		$Object.Session = $this.Session

		$Response = $this.request('GET', $this.setname + '/' + $id + '.json' + $this.include)
		foreach ( $property in $Response.$type.psobject.Properties.Name ) {
			$Object.$property = $Response.$type.$property
		}
		return $Object
	}

	[Hashtable]allpages($base_url,$filter) {
		$offset = 0
		$limit = 100

		$Response = $this.request('GET', $base_url + '?offset=' + $offset + '&limit=' + $limit) # + $this.include + $filter)
		$remain = $Response.total_count

		$collection = @{}
		While ($remain -gt 0) {
			$Response.$($this.setname) | % {
				#$collection.Add($_.id, $_)
				$item = $_ -as ($type -as [type])
				$collection.Add($item.id, $item)
			}
			$remain -= $limit
			$offset += $limit
			Write-Debug $offset
			Write-Debug $remain
			if ($remain -lt 100) { $limit = $remain}

			$Response = $this.request('GET', $base_url + '?offset=' + $offset + '&limit=' + $limit) # + $this.include + $filter)
		}
		return $collection
	}

	[Hashtable]all() { return $this.all('',$null) }
	[Hashtable]all($filter) { return $this.all($filter,$null) }
	[Hashtable]all($filter,$project_id) {
		$type = $this.GetType().Name.ToLower()
		$path = Switch ($type) {
			{$_ -in 'membership','version'} { 'projects/' + $project_id + '/' + $this.setname }
			default { $this.setname }
		}
		Write-Debug $path
		$collection = @{}
		Switch ($type) {
			{$_ -in 'version'} { $this.request('GET', $path + '.json').$($this.setname) | % { $item = $_ -as ($type -as [type]); $collection.Add($item.id, $item) } }
			default { $collection = $this.allpages($path + '.json', $filter) }
		}

		return $collection
	}

	clear() {
		foreach ( $property in $this.psobject.properties.name ) {
			$this.$property = $Null
		}
	}

	[PSCustomObject]create() {
		$type = $this.GetType().Name.ToLower()
		$path = Switch ($type) {
			{$_ -in 'membership','version'} { 'projects/' + $this.project.id + '/' + $this.setname }
			default { $this.setname }
		}
		$Response = $this.request('POST', $path + '.json')
		$this.clear()

		return ($Response.$type)
	}

	read() {
		$type = $this.GetType().Name.ToLower()
		$Response = $this.request('GET', $this.setname + '/' + $this.id + '.json')
		foreach ( $property in $Response.$type.psobject.Properties.Name ) {
			$this.$property = $Response.$type.$property
		}

	}

	update() {
		$this.request('PUT', $this.setname + '/' + $this.id + '.json')
		$this.clear()
	}

	delete() {
		$this.request('DELETE', $this.setname + '/' + $this.id + '.json')
	}
}

Class Project : BaseResource {
	# projects/id.json
	# projects.json
	Hidden [String]$setname = 'projects'
	Hidden [String]$include = '?include=trackers,issue_categories,enabled_modules,time_entry_activities'

	[String]$name
	[String]$identifier
	[String]$homepage
	[PSCustomObject]$parent
	[String]$status
	[Bool]$is_public

	[PSCustomObject[]]$trackers
	[PSCustomObject[]]$issue_categories
	[PSCustomObject[]]$enabled_modules
	[PSCustomObject[]]$time_entry_activities
}

Class Issue : BaseResource {
	# issues/id.json
	# projects/project_id/issues.json
	Hidden [String]$setname = 'issues'
	Hidden [String]$include = '?include=children,attachments,relations,journals,watchers'

	[PSCustomObject]$project
	[PSCustomObject]$tracker
	[PSCustomObject]$status
	[PSCustomObject]$priority
	[PSCustomObject]$author
	[String]$subject
	[PSCustomObject]$fixed_version
	[PSCustomObject]$parent
	[String]$start_date
	[String]$due_date
	#[validaterange(0,100)]
	[Int]$done_ratio
	[Decimal]$estimated_hours
	[Decimal]$total_estimated_hours
	[Decimal]$spent_hours
	[Decimal]$total_spent_hours
	[PSCustomObject[]]$custom_fields
	[String]$closed_on
	[Bool]$is_private
	[PSCustomObject]$assigned_to
	[PSCustomObject]$category
	####
	[PSCustomObject[]]$children
	[PSCustomObject[]]$attachments
	[PSCustomObject[]]$uploads
	[PSCustomObject[]]$relations
	[PSCustomObject[]]$journals
	[String]$notes
	[PSCustomObject[]]$watchers

	AddWatcher($user_id) {
		$IRMParams = @{
			Method = 'POST'
			Uri = $this.Server + '/issues/' + $this.id + '/watchers.json'
			ContentType = 'application/json'
			Body = '{ "user_id": "' + $user_id + '" }'
		}
		Invoke-RestMethod @IRMParams
	}
	RemoveWatcher($user_id) {
		$IRMParams = @{
			Method = 'DELETE'
			Uri = $this.Server + '/issues/' + $this.id + '/watchers/' + $user_id + '.json'
		}
		Invoke-RestMethod @IRMParams
	}
}

Class Membership : BaseResource {
	# memberships/id.json
	# projects/project_id/memberships.json
	Hidden [String]$setname = 'memberships'

	[PSCustomObject]$project
	[PSCustomObject]$group
	[PSCustomObject]$user
	[PSCustomObject[]]$roles
}

Class User : BaseResource {
	# users/id.json
	# users.json
	Hidden [String]$setname = 'users'
	Hidden [String]$include = '?include=memberships,groups'

	[String]$login
	[String]$firstname
	[String]$lastname
	[String]$mail
	[String]$last_login_on
	[String]$api_key
	[String]$status
	[PSCustomObject[]]$memberships
	[PSCustomObject[]]$groups
}

Class Version : BaseResource {
	# versions/id.json
	# projects/project_id/versions.json
	Hidden [String]$setname = 'versions'

	[String]$name
	[PSCustomObject]$project
	#[validateSet('open','locked','closed')]
	[String]$status
	[String]$due_date
	[String]$sharing
}

#endregion

#region Function

Function Connect-Redmine{
	<#
   .SYNOPSIS
    Connect to the Redmine server
   .DESCRIPTION
    Connect to the Redmine server and set the authorization variable in script scope
   .EXAMPLE
    Connect-Redmine https://testredmine
   .EXAMPLE
    Connect-Redmine testredmine
   .LINK
    https://github.com/hamletmun/PSRedmine
	#>
	Param(
		[Parameter(Mandatory=$True)][String]$Server,
		[String]$Key,
		[String]$Username,
		[String]$Password
	)

	Remove-Variable -Name Redmine -Scope script -EA 0

	If ($Key) {
		$IWRParams = @{
			Headers = @{'X-Redmine-API-Key'=$Key}
		}
	} Else {
		If (!($Username)) { If (!($Username = Read-Host "Enter username or blank for [$env:USERNAME]")) { $Username = $env:USERNAME } }
		If ($Password) { [Security.SecureString]$Password = ConvertTo-SecureString $Password -AsPlainText -Force }
		Else { [Security.SecureString]$Password = Read-Host "Enter password for [$Username]" -AsSecureString }
		$cred = New-Object System.Management.Automation.PSCredential ($Username, $Password)
		$IWRParams = @{
			Credential = $cred
		}
	}
	$Script:Redmine = [Redmine]::new($Server, $IWRParams)

}

Function Disconnect-Redmine {
	<#
   .SYNOPSIS
    Disconnect from the Redmine server
   .DESCRIPTION
    Disconnect from the Redmine server
   .EXAMPLE
    Disconnect-Redmine
   .EXAMPLE
    Disconnect-Redmine
   .LINK
    https://github.com/hamletmun/PSRedmine
	#>

	Remove-Variable -Name Redmine -Scope script
}

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

	$filter = If ($project_id) { $filter = '&project_id=' + $project_id }

	$collection = Switch ($type) {
	{$_ -in 'membership','version'} { $Redmine.$type.all('',$project_id) }
	default { $Redmine.$type.all($filter) }
    }

	$filtered = @{}
	Switch ($type) {
		'issue' { $collection.Keys | % { if ($collection[$_].subject -Match $keyword) { $filtered[$_] = $collection[$_] } } }
		'user' { $collection.Keys | % { if ($collection[$_].login -Match $keyword) { $filtered[$_] = $collection[$_] } } }
		'membership' { $collection.Keys | % { if ($collection[$_].user.name -Match $keyword) { $filtered[$_] = $collection[$_] } } }
		default { $collection.Keys | % { if ($collection[$_].name -Match $keyword) { $filtered[$_] = $collection[$_] } } }
	}
	return $filtered
}

Function Set-RedmineResource {
	Param(
		[Parameter(Mandatory=$true)][ResourceType]$type,
		[Int]$project_id,
		[Int]$tracker_id,
		[Int]$status_id,
		[Int]$priority_id,
		[Int]$assigned_to_id,
		[Int]$category_id,
		[Int]$version_id,
		[Int]$parent_issue_id,
		[Datetime]$due_date,
		[Int[]]$watcher_user_ids,
		[String]$description,
		[String]$identifier,
		[String]$name,
		[String]$subject,
		[Int]$default_version_id,
		[String]$notes
	)

	$resource = $Redmine.new($type)

	foreach ($boundparam in $PSBoundParameters.GetEnumerator()) {
		If ($boundparam.Value -eq $null) { continue }
		Switch ($boundparam.Key) {
			'type' { continue }
			'project_id' { $resource.project = [PSCustomObject]@{ id = $boundparam.Value } }
			'tracker_id' { $resource.tracker = [PSCustomObject]@{ id = $boundparam.Value } }
			'status_id' { $resource.status = [PSCustomObject]@{ id = $boundparam.Value } }
			'priority_id' { $resource.priority = [PSCustomObject]@{ id = $boundparam.Value } }
			'assigned_to_id' { $resource.assigned_to = [PSCustomObject]@{ id = $boundparam.Value } }
			'category_id' { $resource.category = [PSCustomObject]@{ id = $boundparam.Value } }
			'version_id' { $resource.fixed_version = [PSCustomObject]@{ id = $boundparam.Value } }
			'parent_issue_id' { $resource.parent = [PSCustomObject]@{ id = $boundparam.Value } }
			'due_date' { $resource.due_date = $due_date.ToString("yyyy-MM-dd") }
			'watcher_user_ids' { $boundparam.Value | % { $resource.watchers += [PSCustomObject]@{ id = $_ } } }
			default { If ($boundparam.Key -In $resource.PSobject.Properties.Name) {
				$resource.$($boundparam.Key) = $boundparam.Value
			}}
		}
    }

	return $resource
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
		[Int]$project_id,
		[Int]$tracker_id,
		[Int]$status_id,
		[Int]$priority_id,
		[Int]$assigned_to_id,
		[Int]$category_id,
		[Int]$version_id,
		[Int]$parent_issue_id,
		[Datetime]$due_date,
		[Int[]]$watcher_user_ids,
		[String]$description,
		[String]$identifier,
		[String]$name,
		[String]$subject,
		[Int]$default_version_id,
		[String]$notes
	)

	$resource = Set-RedmineResource @PSBoundParameters

	$resource.create()
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

	$Redmine.$type.get($id)
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
		[Int]$project_id,
		[Int]$tracker_id,
		[Int]$status_id,
		[Int]$priority_id,
		[Int]$assigned_to_id,
		[Int]$category_id,
		[Int]$version_id,
		[Int]$parent_issue_id,
		[Datetime]$due_date,
		[Int[]]$watcher_user_ids,
		[String]$description,
		[String]$identifier,
		[String]$name,
		[String]$subject,
		[Int]$default_version_id,
		[String]$notes
	)
	$resource = Set-RedmineResource @PSBoundParameters
	$resource.id = $id

	$resource.update()
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

	$Redmine.$type.get($id).delete()
}

#endregion
