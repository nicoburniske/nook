def assert-true [condition: bool message: string] {
  if not $condition {
    error make {msg: $message}
  }
}

def main [manifest_path: string source_path: string] {
  let manifest = open $manifest_path
  let raw_manifest = open --raw $manifest_path

  let facet_asset = ($manifest | get facets.theme.variants.light.asset)
  assert-true ($facet_asset != $source_path) "facet asset path was not materialized"
  assert-true (($facet_asset | path exists)) "materialized facet asset is missing"

  let static_file = (
    $manifest
    | get files
    | where path == ".config/demo/static-source.txt"
    | first
  )
  let static_source = ($static_file | get dispatch.value)
  assert-true ($static_source != $source_path) "static file source was not materialized"
  assert-true (($static_source | path exists)) "materialized static file source is missing"
  let static_contents = open --raw $static_source
  let facet_contents = open --raw $facet_asset
  assert-true ($static_contents == $facet_contents) "static file source did not preserve the original file contents"

  let dynamic_file = (
    $manifest
    | get files
    | where path == ".config/demo/asset-path.txt"
    | first
  )
  let dynamic_cases = ($dynamic_file | get dispatch.cases)
  for case in $dynamic_cases {
    let generated = ($case | get value)
    assert-true (($generated | path exists)) $"generated file is missing: ($generated)"

    let contents = open --raw $generated
    assert-true (($contents | str contains $facet_asset)) "generated file did not use the materialized facet asset"
    assert-true (not ($contents | str contains $source_path)) "generated file still uses the original source path"
  }

  let dynamic_hook = (
    $manifest
    | get hooks
    | where name == "asset-path"
    | first
  )
  let hook_cases = ($dynamic_hook | get dispatch.cases)
  for case in $hook_cases {
    let command = ($case | get value)
    assert-true (($command | str contains $facet_asset)) "hook command did not use the materialized facet asset"
    assert-true (not ($command | str contains $source_path)) "hook command still uses the original source path"
  }

  assert-true (not ($raw_manifest | str contains $source_path)) "manifest still contains the original source path"
}
