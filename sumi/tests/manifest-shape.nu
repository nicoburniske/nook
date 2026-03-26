def canonicalize-dispatch [dispatch] {
  let kind = ($dispatch | get kind)

  if $kind == "static" {
    $dispatch | reject value
  } else {
    let cases = (
      $dispatch
      | get cases
      | each {|case|
          if ("value" in ($case | columns)) {
            $case | reject value
          } else {
            $case
          }
        }
    )

    $dispatch | merge {cases: $cases}
  }
}

def canonicalize-file [file] {
  if ("dispatch" in ($file | columns)) {
    $file | merge {dispatch: (canonicalize-dispatch ($file | get dispatch))}
  } else {
    $file
  }
}

def canonicalize-manifest [manifest] {
  let files = (
    $manifest
    | get files
    | each {|file| canonicalize-file $file }
  )

  $manifest | merge {files: $files}
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
