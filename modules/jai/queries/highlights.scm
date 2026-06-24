; Pinned from constantitus/tree-sitter-jai 073a0c64abecb9ff10b675cea601a0df72cec326.

[
  (import)
  (load)
] @include

[
  "inline"
  "no_inline"
  "struct"
  "union"
  "using"
  "enum"
  "enum_flags"
  "if"
  "then"
  "ifx"
  "else"
  "case"
  "for"
  "while"
  "break"
  "continue"
  "remove"
  "defer"
  "cast"
  "xx"
  "push_context"
] @keyword

[
  "return"
] @keyword.return

[
  "if"
  "else"
  "case"
  "break"
] @conditional

(if_expression
  [
    "then"
    "ifx"
    "else"
  ] @conditional.ternary)

[
  "for"
  "while"
  "continue"
] @repeat

name: (identifier) @variable
argument: (identifier) @variable
named_argument: (identifier) @variable
(member_expression (identifier) @variable)
(parenthesized_expression (identifier) @variable)

((identifier) @variable.builtin
  (#any-of? @variable.builtin "context"))

(import (identifier) @namespace)

(parameter (identifier) @parameter ":" "="? (identifier)? @constant)

(procedure_declaration (identifier) @function (block))

(call_expression function: (identifier) @function.call)

type: (types) @type
type: (identifier) @type
((types) @type)

modifier: (identifier) @keyword
keyword: (identifier) @keyword

((types (identifier) @type.builtin)
  (#any-of? @type.builtin
    "bool" "int" "string"
    "s8" "s16" "s32" "s64"
    "u8" "u16" "u32" "u64"
    "Type" "Any"))

(struct_declaration (identifier) @type ":" ":")

(enum_declaration (identifier) @type ":" ":")

(member_expression "." (identifier) @field)

(assignment_statement (identifier) @field "="?)
(update_statement (identifier) @field)

((identifier) @constant
  (#match? @constant "^_*[A-Z][A-Z0-9_]*$"))

(member_expression . "." (identifier) @constant)

(enum_declaration "{" (identifier) @constant)

(integer) @number
(float) @number

(string) @string

(string (escape_sequence) @string.escape)

(boolean) @boolean

[
  (uninitialized)
  (null)
] @constant.builtin

[
  ":"
  "="
  "+"
  "-"
  "*"
  "/"
  "%"
  ">"
  ">="
  "<"
  "<="
  "=="
  "!="
  "|"
  "~"
  "&"
  "&~"
  "<<"
  ">>"
  "<<<"
  ">>>"
  "||"
  "&&"
  "!"
  ".."
  "+="
  "-="
  "*="
  "/="
  "%="
  "&="
  "|="
  "^="
  "<<="
  ">>="
  "<<<="
  ">>>="
  "||="
  "&&="
] @operator

[ "{" "}" ] @punctuation.bracket

[ "(" ")" ] @punctuation.bracket

[ "[" "]" ] @punctuation.bracket

[
  "`"
  "->"
  "."
  ","
  ":"
  ";"
] @punctuation.delimiter

[
  (block_comment)
  (comment)
] @comment @spell

(ERROR) @error

(block_comment) @comment

directive: ("#") @keyword
type: ("type_of") @type

(compiler_directive) @keyword
(heredoc_start) @none
(heredoc_end) @none
(heredoc_body) @string
