Describe 'Lint helpers CLI' {
    BeforeAll {
        $script:LintCli = Join-Path $PSScriptRoot '../../lint.ps1'
        if (-not (Test-Path $script:LintCli)) {
            Skip "tools/lint.ps1 not present yet"
        }
    }

    It 'shows help' {
        $result = & $script:LintCli --help
        $LASTEXITCODE | Should -Be 0
        $result | Should -Match 'Lint'
    }

    It 'returns 3 on dry-run when files provided' {
        $tempFile = Join-Path $TestDrive 'sample.sh'
        Set-Content -LiteralPath $tempFile -Value "#!/usr/bin/env bash`necho hi`n"

        & $script:LintCli --dry-run --files $tempFile | Out-Null
        $LASTEXITCODE | Should -Be 3
    }

    It 'returns 3 on dry-run for markdown files' {
        $tempDoc = Join-Path $TestDrive 'sample.md'
        Set-Content -LiteralPath $tempDoc -Value "# heading`n`ncontent`n"

        & $script:LintCli --dry-run --files $tempDoc | Out-Null
        $LASTEXITCODE | Should -Be 3
    }

    It 'lints markdown file without optional arguments' {
        $tempDoc = Join-Path $TestDrive 'lint-sample.md'
        Set-Content -LiteralPath $tempDoc -Value "# heading`n`ntext`n"

        & $script:LintCli --files $tempDoc | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'fails with code 1 when file missing' {
        $missing = Join-Path $TestDrive 'missing.sh'
        & $script:LintCli --files $missing | Out-Null
        $LASTEXITCODE | Should -Be 1
    }

    It 'staged wrapper succeeds when nothing staged' {
        $wrapper = Join-Path $PSScriptRoot '../../lint-staged.ps1'
        $staged = git diff --name-only --cached
        if ($LASTEXITCODE -eq 0 -and $staged) {
            Set-ItResult -Skipped -Because 'staged files detected'
            return
        }
        & $wrapper --dry-run | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'warns but succeeds when unsupported files are provided' {
        $unsupported = Join-Path $PSScriptRoot '../../puppeteer/headless.json'
        Test-Path $unsupported | Should -BeTrue

        $output = & $script:LintCli --dry-run --files $unsupported
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'Unsupported file type'
    }
}
