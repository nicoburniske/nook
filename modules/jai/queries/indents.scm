; Pinned from constantitus/tree-sitter-jai 073a0c64abecb9ff10b675cea601a0df72cec326.

[
  (block)
  (enum_declaration "{")
  (struct_or_union_block "{")
  (struct_literal "{")
  (anonymous_struct_type "{")
  (anonymous_enum_type "{")
  (asm_statement "{")
  (array_literal "[")
  (index_expression "[")
  (literal)
  (assignment_parameters "(")
] @indent.begin

((modify_block) @indent.end)
((place_directive) @indent.branch)

(if_statement_condition_and_consequence
  consequence: (_
    ";" @indent.end) @_consequence
  (#not-match? @_consequence "{")
) @indent.begin

(else_clause) @indent.branch

(else_clause
  consequence: (_) @_consequence
  (#match? @_consequence "if")
) @indent.auto

(if_case_statement) @indent.begin
(switch_case ";") @indent.branch

((identifier) . (ERROR "(" @indent.begin))

(block
  "}" @indent.end)

[
  ")"
  "]"
  "}"
] @indent.branch @indent.end

[
  (comment)
  (block_comment)
  (string)
  (ERROR)
] @indent.auto
