export def row [
  id: string
  label: string
  right: string = ""
  action: string = "noop"
  data: record = {}
  active: bool = false
] {
  {
    id: $id
    label: $label
    right: $right
    action: $action
    data: $data
    active: $active
  }
}

export def page-row [
  id: string
  label: string
  page: string
  right: string = ""
  data: record = {}
] {
  row $id $label $right "page" {page: $page, data: $data}
}

export def apply-row [
  id: string
  label: string
  kind: string
  data: record = {}
  active: bool = false
  right: string = ""
] {
  row $id $label $right "apply" ({kind: $kind} | merge $data) $active
}
