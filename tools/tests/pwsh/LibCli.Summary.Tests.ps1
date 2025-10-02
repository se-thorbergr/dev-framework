Describe 'LibCli summary and version handling' {
    BeforeAll {
        $script:LibCliPath = Join-Path $PSScriptRoot '../../lib/cli.ps1'
        if (-not (Test-Path $script:LibCliPath)) {
            Throw "LibCli library not found at $script:LibCliPath"
        }
        . $script:LibCliPath
    }

    BeforeEach {
        Initialize-Cli -Args @()
    }

    It 'parses summary flags and emits schema v1 JSON with CI metadata' {
        $context = Initialize-Cli -Args @('--summary', '--summary-format', 'json', '--ci')

        $context.Flags.summary | Should -BeTrue
        $context.Flags.summary_format | Should -Be 'json'
        $context.Flags.ci | Should -BeTrue

        Add-SummaryItem -Kind 'info' -Message 'first item'
        Add-SummaryItem -Kind 'warning' -Message 'second item'

        $json = Emit-Summary -Format 'json'
        $payload = $json | ConvertFrom-Json

        $payload.schema | Should -Be 'v1'
        $payload.summary.Count | Should -Be 2
        $payload.summary[0].kind | Should -Be 'info'
        $payload.summary[0].message | Should -Be 'first item'
        $payload.ci.enabled | Should -BeTrue
    }

    It 'includes api_version in version output' {
        $output = Emit-Version -Version '1.2.3' -Commit 'abc123' -ApiVersion '2025.10'
        $output | Should -Match 'api_version'
        $output | Should -Match '2025.10'
    }
}
