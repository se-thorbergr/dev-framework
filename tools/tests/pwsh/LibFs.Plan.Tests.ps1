Describe 'LibFs planning helpers' {
    BeforeAll {
        $script:LibFsPath = Join-Path $PSScriptRoot '../../lib/fs.ps1'
        if (-not (Test-Path -LiteralPath $script:LibFsPath)) {
            throw "LibFs library not found at $script:LibFsPath"
        }
        . $script:LibFsPath
    }

    It 'returns mkdir and write actions without mutating the filesystem' {
        $root = Join-Path $TestDrive 'libfs-plan'
        $dirPath = Join-Path $root 'data'
        $filePath = Join-Path $dirPath 'note.txt'

        $dirPlan = Plan-EnsureDirectory -Path $dirPath
        $filePlan = Plan-EnsureFile -Path $filePath -Content 'hello world' -Mode 'create'

        $actions = @()
        if ($dirPlan.Actions) { $actions += $dirPlan.Actions }
        if ($filePlan.Actions) { $actions += $filePlan.Actions }

        $conflicts = @()
        if ($dirPlan.Conflicts) { $conflicts += $dirPlan.Conflicts }
        if ($filePlan.Conflicts) { $conflicts += $filePlan.Conflicts }

        $plan = [pscustomobject]@{
            Actions   = $actions
            Conflicts = $conflicts
        }

        Test-Path -LiteralPath $dirPath | Should -BeFalse
        Test-Path -LiteralPath $filePath | Should -BeFalse

        $validation = Validate-Plan -Plan $plan

        $validation.IsValid | Should -BeTrue
        $validation.Errors | Should -BeNullOrEmpty

        $rendered = Render-Plan -Plan $plan -Header 'plan:'
        $rendered | Should -Match 'write'
    }

    It 'includes hash diff metadata for if-changed updates' {
        $root = Join-Path $TestDrive 'libfs-diff'
        $filePath = Join-Path $root 'config.ini'
        New-Item -ItemType Directory -Path $root | Out-Null
        Set-Content -LiteralPath $filePath -Value 'old value' -NoNewline

        $plan = Plan-EnsureFile -Path $filePath -Content 'new value' -Mode 'if-changed'
        $plan.Actions.Count | Should -Be 1
        $action = $plan.Actions[0]
        $action.Diff | Should -Not -BeNullOrEmpty
        $action.Diff.OldHash | Should -Not -BeNullOrEmpty
        $action.Diff.NewHash | Should -Not -BeNullOrEmpty
    }

    It 'rejects writes targeting protected paths' {
        $root = Join-Path $TestDrive 'libfs-protected'
        $protectedPath = Join-Path $root 'Project.mdk.ini'

        $plan = Plan-EnsureFile -Path $protectedPath -Content 'unsafe' -Mode 'create'
        $validation = Validate-Plan -Plan $plan
        $validation.IsValid | Should -BeFalse
        ($validation.Errors -join ' ') | Should -Match '\.mdk\.ini'
    }

    It 'allows .mdk.local.ini overrides' {
        $root = Join-Path $TestDrive 'libfs-local'
        $localPath = Join-Path $root 'Project.mdk.local.ini'

        $plan = Plan-EnsureFile -Path $localPath -Content 'safe override' -Mode 'create'
        $validation = Validate-Plan -Plan $plan
        $validation.IsValid | Should -BeTrue
    }

    It 'rejects writes to se-config.ini' {
        $root = Join-Path $TestDrive 'libfs-se-config'
        $basePath = Join-Path $root 'se-config.ini'

        $plan = Plan-EnsureFile -Path $basePath -Content 'auto=override' -Mode 'create'
        $validation = Validate-Plan -Plan $plan
        $validation.IsValid | Should -BeFalse
        ($validation.Errors -join ' ') | Should -Match 'se-config\.ini'
    }

    It 'allows se-config.local.ini overrides' {
        $root = Join-Path $TestDrive 'libfs-se-config-local'
        $localPath = Join-Path $root 'se-config.local.ini'

        $plan = Plan-EnsureFile -Path $localPath -Content 'binarypath=C:\\Steam' -Mode 'create'
        $validation = Validate-Plan -Plan $plan
        $validation.IsValid | Should -BeTrue
    }
}
