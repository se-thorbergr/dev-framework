Describe 'LibConfig diff and schema behaviour' {
    BeforeAll {
        $script:LibConfigPath = Join-Path $PSScriptRoot '../../lib/config.ps1'
        if (-not (Test-Path $script:LibConfigPath)) {
            throw "LibConfig library not found at $script:LibConfigPath"
        }
        . $script:LibConfigPath
    }

    It 'emits add/update/remove actions for config diff' {
        $effective = [ordered]@{
            general = [ordered]@{
                keep     = '1'
                obsolete = 'old'
                change   = 'initial'
            }
        }

        $desired = [ordered]@{
            general = [ordered]@{
                keep   = '1'
                change = 'updated'
                newkey = '2'
            }
        }

        $diff = Diff-Local -Effective $effective -Desired $desired
        $diff | Should -Not -BeNullOrEmpty
        $diff.Changes | Should -Not -BeNullOrEmpty

        ($diff.Changes | Where-Object { $_.Action -eq 'remove' -and $_.Section -eq 'general' -and $_.Key -eq 'obsolete' }) | Should -Not -BeNullOrEmpty
        ($diff.Changes | Where-Object { $_.Action -eq 'add' -and $_.Key -eq 'newkey' -and $_.New -eq '2' }) | Should -Not -BeNullOrEmpty
        ($diff.Changes | Where-Object { $_.Action -eq 'update' -and $_.Key -eq 'change' -and $_.Old -eq 'initial' -and $_.New -eq 'updated' }) | Should -Not -BeNullOrEmpty

        $fragment = Render-Ini -Changes $diff.Changes
        $fragment | Should -Match "\[general\]"
        $fragment | Should -Match "newkey=2"
        $fragment | Should -Match "change=updated"
        $fragment | Should -Not -Match "obsolete"
    }

    It 'returns built-in schema catalogue entries' {
        $schema = Get-ConfigSchema -Name 'se-config.ini'
        $schema | Should -Not -BeNullOrEmpty
        $schema.Name | Should -Be 'se-config.ini'
        $schema.Sections | Should -Not -BeNullOrEmpty
        $schema.Sections.general | Should -Not -BeNullOrEmpty
        $schema.Sections.general.Keys | Should -Contain 'binarypath'
        $schema.Version | Should -Match '^v'

        $unknown = Get-ConfigSchema -Name 'does-not-exist'
        $unknown | Should -BeNullOrEmpty
    }
}
