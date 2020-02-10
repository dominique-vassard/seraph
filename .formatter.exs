locals_without_parens = [
  property: 2,
  property: 3,
  outgoing_relationship: 2,
  outgoing_relationship: 3,
  outgoing_relationship: 4,
  incoming_relationship: 2,
  incoming_relationship: 3,
  incoming_relationship: 4,
  start_node: 1,
  end_node: 1
]

# Used by "mix format"
[
  import_deps: [:ecto],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
