def canonicalize-manifest [manifest] {
  $manifest
  | update files {|row|
      $row.files
      | each {|file|
          if ("rules" in ($file | columns)) {
            $file
            | update rules {|file_row|
                $file_row.rules
                | each {|rule|
                    if ("source" in ($rule | columns)) {
                      $rule | reject source
                    } else {
                      $rule
                    }
                  }
              }
          } else {
            $file
          }
        }
    }
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
