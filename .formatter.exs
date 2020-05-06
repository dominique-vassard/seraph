locals_without_parens = [
  property: 2,
  property: 3,
  outgoing_relationship: 4,
  outgoing_relationship: 5,
  incoming_relationship: 4,
  incoming_relationship: 5,
  start_node: 1,
  end_node: 1,
  defrelationship: 3,
  defrelationship: 4,

  # Query
  match: 2
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
