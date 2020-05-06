defprotocol Seraph.Query.Stringifier do
  @spec stringify(any, atom()) :: String.t()
  def stringify(operation_data, operation \\ :match)
end

alias Seraph.Query.Builder
alias Seraph.Query.Stringifier

defimpl Stringifier, for: Tuple do
  def stringify({operation, data}, _) do
    apply(Seraph.Query.Stringifier.Operation, :stringify, [operation, data])
  end
end

defimpl Stringifier, for: Builder.NodeExpr do
  def stringify(%Builder.NodeExpr{alias: node_alias, variable: variable}, :return)
      when not is_nil(node_alias) do
    "#{variable} AS #{node_alias}"
  end

  def stringify(%Builder.NodeExpr{variable: variable}, :return) do
    variable
  end

  def stringify(
        %Builder.NodeExpr{
          variable: variable,
          labels: labels,
          properties: properties
        },
        _
      )
      when is_list(labels) and map_size(properties) == 0 do
    labels_str =
      Enum.map(labels, fn label ->
        ":#{label}"
      end)
      |> Enum.join()

    "(#{variable}#{labels_str})"
  end

  def stringify(
        %Builder.NodeExpr{
          variable: variable,
          labels: labels,
          properties: properties
        },
        _
      )
      when is_list(labels) do
    labels_str =
      Enum.map(labels, fn label ->
        ":#{label}"
      end)
      |> Enum.join()

    props = Stringifier.Helper.stringify_props(properties)

    "(#{variable}#{labels_str}#{props})"
  end

  def stringify(%Builder.NodeExpr{variable: variable}, _) do
    "(#{variable})"
  end

  def stringify(%Builder.NodeExpr{labels: labels}, _) when is_list(labels) do
    labels_str =
      Enum.map(labels, fn label ->
        ":#{label}"
      end)
      |> Enum.join()

    "(#{labels_str})"
  end
end

defimpl Stringifier, for: Builder.RelationshipExpr do
  def stringify(%Builder.RelationshipExpr{alias: rel_alias, variable: variable}, :return)
      when not is_nil(rel_alias) do
    "#{variable} AS #{rel_alias}"
  end

  def stringify(%Builder.RelationshipExpr{variable: variable}, :return) do
    variable
  end

  def stringify(
        %Builder.RelationshipExpr{
          start: start_node,
          end: end_node,
          type: rel_type,
          variable: variable,
          properties: properties
        },
        _
      )
      when map_size(properties) > 0 do
    cql_type =
      unless is_nil(rel_type) do
        ":#{rel_type}"
      end

    props = Stringifier.Helper.stringify_props(properties)

    Stringifier.stringify(start_node) <>
      "-[#{variable}#{cql_type}#{props}]->" <> Stringifier.stringify(end_node)
  end

  def stringify(
        %Builder.RelationshipExpr{
          start: start_node,
          end: end_node,
          type: rel_type,
          variable: variable
        },
        _
      ) do
    cql_type =
      unless is_nil(rel_type) do
        ":#{rel_type}"
      end

    Stringifier.stringify(start_node) <>
      "-[#{variable}#{cql_type}]->" <> Stringifier.stringify(end_node)
  end
end

defimpl Stringifier, for: Builder.FieldExpr do
  def stringify(%Builder.FieldExpr{variable: variable, name: field, alias: alias}, _) do
    field_name = Atom.to_string(field)

    case alias do
      nil -> "#{variable}.#{field_name}"
      field_alias -> "#{variable}.#{field_name} AS #{field_alias}"
    end
  end
end

defmodule Seraph.Query.Stringifier.Helper do
  def stringify_props(properties) do
    props_str =
      Enum.map(properties, fn {prop, bound_name} ->
        "#{Atom.to_string(prop)}: $#{bound_name}"
      end)
      |> Enum.join(",")

    " {#{props_str}}"
  end
end

defmodule Seraph.Query.Stringifier.Operation do
  def stringify(:match, data) do
    match =
      Enum.map(data, &Stringifier.stringify(&1, :match))
      |> Enum.join(",\n\t")

    if String.length(match) > 0 do
      "MATCH \n\t" <> match
    end
  end

  def stringify(:where, data) do
    where = Seraph.Query.Condition.stringify_condition(data)

    if String.length(where) > 0 do
      "WHERE \n\t" <> where
    end
  end

  def stringify(:return, %Builder.ReturnExpr{fields: fields, distinct?: distinct?}) do
    distinct =
      if distinct? do
        "DISTINCT "
      end

    fields =
      fields
      |> Enum.map(&Stringifier.stringify(&1, :return))
      |> Enum.join(", ")

    if String.length(fields) > 0 do
      "RETURN \n\t#{distinct} \n\t" <> fields
    end
  end

  def stringify(operation, data) do
    # IO.inspect(data)
    "stringify #{inspect(operation)}"
  end
end
