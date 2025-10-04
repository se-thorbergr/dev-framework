#!/usr/bin/env bats

load_helper() {
  LIB_PATH="${BATS_TEST_DIRNAME}/../../lib/dotnetproj.sh"
  if [[ ! -f "$LIB_PATH" ]]; then
    echo "LibDotnetProj library not found at $LIB_PATH" >&2
    return 1
  fi
  # shellcheck source=/dev/null
  source "$LIB_PATH"
}

setup() {
  load_helper || skip "LibDotnetProj shell library not present"
}

write_csproj() {
  local path="$1"
  cat >"$path" <<'XML'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>PB.Script</RootNamespace>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="Program.cs" />
    <None Include="thumb.png" />
  </ItemGroup>
  <Import Project="Shared/PB.projitems" Label="Shared" />
</Project>
XML
}

@test "dotproj_read returns normalized model" {
  tmp_dir="$BATS_TEST_TMPDIR/read"
  mkdir -p "$tmp_dir"
  write_csproj "$tmp_dir/Sample.csproj"

  run dotproj_read "$tmp_dir/Sample.csproj"
  [ "$status" -eq 0 ]
  kind=$(python3 - "$output" <<'PY'
import json, sys
print(json.loads(sys.argv[1])['model']['kind'])
PY
)
  [[ "$kind" == "csproj" ]]
}

@test "dotproj_plan_import_shared adds missing import" {
  tmp_dir="$BATS_TEST_TMPDIR/import"
  mkdir -p "$tmp_dir"
  cat >"$tmp_dir/Project.csproj" <<'XML'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup>
</Project>
XML
  model_json=$(dotproj_read "$tmp_dir/Project.csproj")
  run dotproj_plan_import_shared "$model_json" "Shared/Lib.projitems"
  [ "$status" -eq 0 ]
  actions=$(python3 - "$output" <<'PY'
import json, sys
print(len(json.loads(sys.argv[1])['actions']))
PY
)
  [[ "$actions" == "1" ]]
}

@test "dotproj_plan_set_property is idempotent" {
  tmp_dir="$BATS_TEST_TMPDIR/property"
  mkdir -p "$tmp_dir"
  write_csproj "$tmp_dir/Project.csproj"
  model_json=$(dotproj_read "$tmp_dir/Project.csproj")

  run dotproj_plan_set_property "$model_json" RootNamespace "PB.Script"
  [ "$status" -eq 0 ]
  actions=$(python3 - "$output" <<'PY'
import json, sys
print(len(json.loads(sys.argv[1])['actions']))
PY
)
  [[ "$actions" == "0" ]]
}

@test "dotproj_plan_render renders actions" {
  actions='{"actions":[{"op":"ensure-import","project":"Shared/Lib.projitems"},{"op":"remove","selector":"ItemGroup/None[@Include='"'"thumb.png"'"']"}]}'
  run dotproj_plan_render "$actions" "plan:"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ensure-import"* ]]
}
