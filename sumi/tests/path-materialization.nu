def assert-true [condition: bool message: string] {
  if not $condition {
    error make {msg: $message}
  }
}

def main [manifest_path: string source_path: string] {
  let manifest = open $manifest_path
  let raw_manifest = open --raw $manifest_path

  assert-true (($manifest | get facets.theme.variants.light | is-empty)) "facet payload leaked into manifest"

  let static_file = (
    $manifest
    | get files
    | where path == ".config/demo/static-source.txt"
    | first
  )
  let static_source = ($static_file | get source.path)
  assert-true ($static_source != $source_path) "static file source was not materialized"
  assert-true (($static_source | path exists)) "materialized static file source is missing"
  let static_contents = open --raw $static_source
  assert-true (($static_contents | str length) > 0) "static file source is empty"

  let dynamic_roots = ($manifest | get variantRoots.theme)
  for root in ($dynamic_roots | transpose variant path) {
    let generated = ($root.path | path join ".config/demo/asset-path.txt")
    assert-true (($generated | path exists)) $"generated file is missing: ($generated)"

    let contents = open --raw $generated
    assert-true (($contents | str contains "/nix/store/")) "generated file did not use a materialized facet asset"
    assert-true (not ($contents | str contains $source_path)) "generated file still uses the original source path"
  }

  let dynamic_hook = (
    $manifest
    | get hooks
    | where name == "asset-path"
    | first
  )
  let hook_cases = ($dynamic_hook | get command.variants)
  for case in ($hook_cases | transpose variant value) {
    let command = ($case | get value)
    assert-true (($command | str contains "/nix/store/")) "hook command did not use a materialized facet asset"
    assert-true (not ($command | str contains $source_path)) "hook command still uses the original source path"
  }

  assert-true (not ($raw_manifest | str contains $source_path)) "manifest still contains the original source path"
}
