Import-module PSRedmine -Force

InModuleScope PSRedmine {
    Describe 'Redmine API' {
        Context 'New-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/projects.json" }
            It 'project' { New-RedmineResource project -identifier test99 -name testproject }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/projects/*/versions.json" }
            It 'version' { New-RedmineResource version -project_id 475 -name testversion }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'POST' -and $Body -and $Uri -like "/issues.json" }
            It 'issue' { New-RedmineResource issue -project_id test99 -subject testissue }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 3 -Exactly
        }
        Context 'Search-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects.json?offset=*&limit=*" }
            It 'project' { Search-RedmineResource project -keyword testproject }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*/memberships.json?offset=*&limit=*" }
            It 'membership' { Search-RedmineResource membership -project_id test99 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*/versions.json" }
            It 'version' { Search-RedmineResource version -keyword testversion -project_id test99 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/issues.json?offset=*&limit=*" }
            It 'issue' { Search-RedmineResource issue -keyword testissue }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/users.json?offset=*&limit=*" }
            It 'user' { Search-RedmineResource user -keyword testuser }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 5 -Exactly
        }
        Context 'Get-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/projects/*.json" }
            It 'project' { Get-RedmineResource project -id test99 }
            It 'project' { Get-RedmineResource project 12 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/memberships/*.json" }
            It 'membership' { Get-RedmineResource membership 123 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/versions/*.json" }
            It 'version' { Get-RedmineResource version 123 }

            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'GET' -and $Uri -like "/issues/*.json?include=journals,watchers" }
            It 'issue' { Get-RedmineResource issue 1234 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 5 -Exactly
        }
        Context 'Edit-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'PUT' -and $Body -and $Uri -like "/*/*.json" }
            It 'project' { Edit-RedmineResource project -id 12 -description 'change description' }
            It 'version' { Edit-RedmineResource version -id 123 -description 'add desc' -due_date 2018-09-29 }
            It 'issue' { Edit-RedmineResource issue -id 1234 -version_id 123 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 3 -Exactly
        }
        Context 'Remove-RedmineResource' {
            Mock Send-HTTPRequest -MockWith { $true } -ParameterFilter { $Method -eq 'DELETE' -and $Uri -like "/*/*.json" }
            It 'project' { Remove-RedmineResource project -id 12 }
            It 'version' { Remove-RedmineResource version -id 123 }
            It 'issue' { Remove-RedmineResource issue -id 1234 }
            It 'user' { Remove-RedmineResource user -id 20 }

            Assert-MockCalled -CommandName Send-HTTPRequest -Times 4 -Exactly
        }
    }
}
