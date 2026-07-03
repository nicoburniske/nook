def canonicalize-file [file] {
  if ($file.source.kind == "static") {
    $file | upsert source ($file.source | reject path)
  } else {
    $file
  }
}

def canonicalize-hook [hook] {
  if ($hook.command.kind == "static") {
    $hook
  } else {
    $hook | upsert command ($hook.command | upsert variants {})
  }
}

def canonicalize-variant-roots [roots] {
  $roots | transpose facet variants | each {|row|
    {
      facet: $row.facet
      variants: ($row.variants | transpose variant path | each {|v| {variant: $v.variant, path: "<store>"}})
    }
  }
}

def canonicalize-manifest [manifest] {
  let files = (
    $manifest
    | get files
    | each {|file| canonicalize-file $file }
  )
  let hooks = (
    $manifest
    | get hooks
    | each {|hook| canonicalize-hook $hook }
  )
  let variant_roots = (canonicalize-variant-roots ($manifest | get variantRoots))

  $manifest | merge {files: $files hooks: $hooks variantRoots: $variant_roots}
}

def main [manifest_path: string expected_json: string] {
  let actual = (canonicalize-manifest (open $manifest_path))
  let expected = (canonicalize-manifest ($expected_json | from json))

  if $actual != $expected {
    print "manifest shape mismatch"
    print "actual:"
    print ($actual | to json --raw)
    print "expected:"
    print ($expected | to json --raw)
    error make {msg: "manifest shape mismatch"}
  }
}
