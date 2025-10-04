Describe 'LibDotnetProj library' {
    BeforeAll {
        $script:LibPath = Join-Path $PSScriptRoot '../../lib/dotnetproj.ps1'
        if (-not (Test-Path -LiteralPath $script:LibPath)) {
            throw "LibDotnetProj library not found at $script:LibPath"
        }
        . $script:LibPath

        function New-TestProject {
            param(
                [string]$Name,
                [string]$Content
            )
            $root = Join-Path $TestDrive $Name
            New-Item -ItemType Directory -Path $root | Out-Null
            $path = Join-Path $root "$Name.csproj"
            Set-Content -LiteralPath $path -Value $Content -NoNewline
            return $path
        }

        $script:SampleCsproj = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>PB.Script</RootNamespace>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="Program.cs" />
    <None Include="thumb.png" />
  </ItemGroup>
  <Import Project="Shared\PB.projitems" Label="Shared" />
</Project>
"@
    }

    It 'Read-DotnetProject returns normalized model' {
        $path = New-TestProject -Name 'Sample' -Content $script:SampleCsproj

        $result = Read-DotnetProject -Path $path

        $result.Kind | Should -Be 'csproj'
        $result.Model.Kind | Should -Be 'csproj'
        $result.Model.Properties.TargetFramework | Should -Be 'net8.0'
        ($result.Model.Items | Where-Object { $_.Item -eq 'None' }).Include | Should -Contain 'thumb.png'
        $result.Model.Imports.Project | Should -Contain 'Shared\PB.projitems'
    }

    It 'Validate-PbScriptProject flags missing TargetFramework' {
        $model = (Read-DotnetProject -Path (New-TestProject -Name 'MissingTfm' -Content "<Project><PropertyGroup><RootNamespace>Foo</RootNamespace></PropertyGroup></Project>")).Model

        $validation = Validate-PbScriptProject -Model $model

        $validation.IsValid | Should -BeFalse
        ($validation.Errors -join ' ') | Should -Match 'TargetFramework'
    }

    It 'Plan-ImportShared adds missing import' {
        $path = New-TestProject -Name 'NoImport' -Content "<Project><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>"
        $model = (Read-DotnetProject -Path $path).Model

        $plan = Plan-ImportShared -Model $model -ProjitemsPath 'Shared/Project.projitems'

        $plan.Actions | Should -HaveCount 1
        $plan.Actions[0].Op | Should -Be 'ensure-import'
        $plan.Actions[0].Project | Should -Be 'Shared/Project.projitems'

        # idempotent
        $model.Imports += [pscustomobject]@{ Project = 'Shared/Project.projitems'; Label = 'Shared'; Condition = $null }
        $secondPlan = Plan-ImportShared -Model $model -ProjitemsPath 'Shared/Project.projitems'
        $secondPlan.Actions | Should -BeNullOrEmpty
    }

    It 'Plan-AddItem and Plan-SetProperty are idempotent' {
        $model = (Read-DotnetProject -Path (New-TestProject -Name 'AddItem' -Content $script:SampleCsproj)).Model

        $itemPlan = Plan-AddItem -Model $model -Item 'None' -Include 'thumb.png'
        $itemPlan.Actions | Should -BeNullOrEmpty

        $newItemPlan = Plan-AddItem -Model $model -Item 'Content' -Include 'info.txt'
        $newItemPlan.Actions | Should -HaveCount 1
        $newItemPlan.Actions[0].Include | Should -Be 'info.txt'

        $propPlan = Plan-SetProperty -Model $model -Name 'RootNamespace' -Value 'PB.Script'
        $propPlan.Actions | Should -BeNullOrEmpty

        $propPlan2 = Plan-SetProperty -Model $model -Name 'RootNamespace' -Value 'PB.Script.Updated'
        $propPlan2.Actions | Should -HaveCount 1
        $propPlan2.Actions[0].Value | Should -Be 'PB.Script.Updated'
    }

    It 'Validate-PlanXml catches conflicting ensure-import actions' {
        $actions = @(
            [pscustomobject]@{ Op = 'ensure-import'; Project = 'Shared/One.projitems'; Label = 'Shared' },
            [pscustomobject]@{ Op = 'ensure-import'; Project = 'Shared/One.projitems'; Label = 'Other' }
        )

        $result = Validate-PlanXml -Actions $actions -Kind 'csproj'

        $result.IsValid | Should -BeFalse
        ($result.Errors -join ' ') | Should -Match 'ensure-import'
    }

    It 'Render-XmlPlan describes planned actions' {
        $actions = @(
            [pscustomobject]@{ Op = 'ensure-import'; Project = 'Shared/Lib.projitems'; Label = 'Shared' },
            [pscustomobject]@{ Op = 'ensure-item'; Item = 'Content'; Include = 'info.txt' },
            [pscustomobject]@{ Op = 'remove'; Selector = "ItemGroup/None[@Include='thumb.png']" }
        )

        $render = Render-XmlPlan -Actions $actions -Header 'plan:'

        $render | Should -Match 'ensure-import'
        $render | Should -Match 'ensure-item'
        $render | Should -Match 'remove'
    }
}
