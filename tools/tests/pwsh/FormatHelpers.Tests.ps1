Describe 'Format helpers CLI' {
    BeforeAll {
        $script:FormatCli = Join-Path $PSScriptRoot '../../format.ps1'
        if (-not (Test-Path $script:FormatCli)) {
            Skip "tools/format.ps1 not present yet"
        }
    }

    It 'shows help' {
        $result = & $script:FormatCli --help
        $LASTEXITCODE | Should -Be 0
        $result | Should -Match 'Format'
    }

    It 'returns 3 on dry-run when files provided' {
        $tempFile = Join-Path $TestDrive 'sample.sh'
        Set-Content -LiteralPath $tempFile -Value "#!/usr/bin/env bash`necho hi`n"

        & $script:FormatCli --dry-run --files $tempFile | Out-Null
        $LASTEXITCODE | Should -Be 3
    }

    It 'returns 3 on dry-run for markdown files' {
        $tempDoc = Join-Path $TestDrive 'sample.md'
        Set-Content -LiteralPath $tempDoc -Value "# heading`n`ncontent`n"

        & $script:FormatCli --dry-run --files $tempDoc | Out-Null
        $LASTEXITCODE | Should -Be 3
    }

    It 'returns 0 on dry-run with no files' {
        $staged = git diff --name-only --cached
        if ($LASTEXITCODE -eq 0 -and $staged) {
            Set-ItResult -Skipped -Because 'staged files detected'
            return
        }
        & $script:FormatCli --dry-run | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'staged wrapper succeeds when nothing staged' {
        $wrapper = Join-Path $PSScriptRoot '../../format-staged.ps1'
        $staged = git diff --name-only --cached
        if ($LASTEXITCODE -eq 0 -and $staged) {
            Set-ItResult -Skipped -Because 'staged files detected'
            return
        }
        & $wrapper --dry-run | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
