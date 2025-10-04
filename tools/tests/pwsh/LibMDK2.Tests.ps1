Describe 'LibMDK2 library' {
    BeforeAll {
        $script:LibPath = Join-Path $PSScriptRoot '../../lib/mdk2.ps1'
        if (-not (Test-Path -LiteralPath $script:LibPath)) {
            throw "LibMDK2 library not found at $script:LibPath"
        }
        . $script:LibPath
    }

    It 'Find-Mdk2Configs returns sorted absolute paths' {
        $root = Join-Path $TestDrive 'mdk2-configs'
        New-Item -ItemType Directory -Path $root | Out-Null
        $tracked = Join-Path $root 'Alpha.mdk.ini'
        $local = Join-Path $root 'Alpha.mdk.local.ini'
        Set-Content -LiteralPath $tracked -Value "[mdk]`nType=programmableblock`n" -NoNewline
        Set-Content -LiteralPath $local -Value "[mdk]`noutput=auto`n" -NoNewline

        $result = Find-Mdk2Configs -Root $root

        $result.Paths | Should -HaveCount 2
        $result.Paths | Should -BeExactly @($tracked, $local)
    }

    It 'Read-Mdk2Config normalizes section keys' {
        $root = Join-Path $TestDrive 'mdk2-read'
        New-Item -ItemType Directory -Path $root | Out-Null
        $configPath = Join-Path $root 'Beta.mdk.ini'
        @"
[mdk]
Type=programmableblock
Trace=off
Minify=trim
"@ | Set-Content -LiteralPath $configPath

        $result = Read-Mdk2Config -Path $configPath

        $result.Source | Should -Be $configPath
        $result.Data.mdk.type | Should -Be 'programmableblock'
        $result.Data.mdk.minify | Should -Be 'trim'
    }

    It 'Validate-Mdk2Config enforces required [mdk] section' {
        $invalid = @{ other = @{ key = 'value' } }
        $valid = @{ mdk = @{ type = 'programmableblock'; trace = 'off'; minify = 'none' } }

        $invalidResult = Validate-Mdk2Config -Data $invalid
        $invalidResult.IsValid | Should -BeFalse
        ($invalidResult.Errors -join ' ') | Should -Match '\[mdk\]'

        $validResult = Validate-Mdk2Config -Data $valid
        $validResult.IsValid | Should -BeTrue
        $validResult.Errors | Should -BeNullOrEmpty
    }

    It 'Validate-Mdk2Project aggregates diagnostics and detects conflicts' {
        $root = Join-Path $TestDrive 'mdk2-project'
        New-Item -ItemType Directory -Path $root | Out-Null
        $tracked = Join-Path $root 'Project.mdk.ini'
        $local = Join-Path $root 'Project.mdk.local.ini'
        @"
[mdk]
type=programmableblock
trace=off
minify=none
"@ | Set-Content -LiteralPath $tracked
        @"
[mdk]
type=mod
output=auto
binarypath=auto
"@ | Set-Content -LiteralPath $local
        New-Item -ItemType Directory -Path (Join-Path $root 'MDK') | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'MDK/Templates.version.txt') -Value '2.2.31'
        New-Item -ItemType Directory -Path (Join-Path $root 'Scripts') | Out-Null

        $diag = Validate-Mdk2Project -ProjectRoot $root -MinTemplate '2.2.0'

        $diag.IsValid | Should -BeTrue
        ($diag.Warnings -join ' ') | Should -Match 'type'
        $diag.Info.HasTemplates | Should -BeTrue
        $diag.Info.TemplateVersion | Should -Be '2.2.31'
        $diag.Info.ScriptsPath | Should -Be (Join-Path $root 'Scripts')
    }

    It 'Validate-Mdk2Project reports missing configs' {
        $root = Join-Path $TestDrive 'mdk2-missing'
        New-Item -ItemType Directory -Path $root | Out-Null

        $diag = Validate-Mdk2Project -ProjectRoot $root

        $diag.IsValid | Should -BeFalse
        ($diag.Errors -join ' ') | Should -Match 'MDK-001'
    }

    It 'Render-Mdk2Summary emits ASCII summary' {
        $diagnostics = [pscustomobject]@{
            IsValid  = $false
            Errors   = @('MDK-001: no configs found')
            Warnings = @('minify mismatch')
        }

        $summary = Render-Mdk2Summary -Diagnostics $diagnostics

        $summary | Should -Match 'errors: 1'
        $summary | Should -Match 'warnings: 1'
    }
}
