defmodule Neo4jex.Query.Builder do
  @moduledoc """
  `Neo4jex.Builder` is designed to build Cypher queries programmatically.
  It has functions to build essential parts of a Cypher Builder and its `to_string` returns a valid
  cypher query.

  ## Example

      # MATCH
      #   (n:User)
      # WHERE
      #   n.uuid = "my-user-uid"
      # RETURN
      # n
      alias Neo4jex.Builder

      node = %Builder.NodeExpr{
        index: 0,
        variable: "n",
        labels: ["User"]
      }

      condition = %Neo4jex.Query.Condition{
        source: node.variable,
        field: :uuid,
        operator: :==,
        value: "user_uuid"
      }

      params = %{
        user_uuid: "my-user-uid"
      }

      return = %Builder.ReturnExpr{
        distinct?: false,
        fields: [
          node
        ]
      }

      {cql, params} =
      Builder.new()
      |> Builder.match([node])
      |> Builder.where(condition)
      |> Builder.return(return)
      |> Builder.params(params)

      IO.puts(cql)
      "MATCH\\n  (n:User)\\n\\nWHERE\\n  n.uuid = {user_uuid}\\n\\n\\n\\n\\n\\nRETURN\\n  n\\n\\n\\n\\n\\n"

      IO.inspect(params)
      %{user_uuid: "my-user-uid"}
  """
  defmodule NodeExpr do
    defstruct [:index, :variable, :labels, :alias, properties: %{}]

    @type t :: %__MODULE__{
            index: nil | integer(),
            variable: String.t(),
            labels: nil | [String.t()],
            alias: nil | String.t(),
            properties: map
          }
  end

  defmodule RelationshipExpr do
    defstruct [:index, :variable, :start, :end, :type, :alias]

    @type t :: %__MODULE__{
            index: nil | integer(),
            variable: String.t(),
            start: NodeExpr.t(),
            end: NodeExpr.t(),
            type: String.t(),
            alias: nil | String.t()
          }
  end

  @type entity_expr :: NodeExpr.t() | RelationshipExpr.t()

  defmodule FieldExpr do
    defstruct [:alias, :variable, :name]

    @type t :: %__MODULE__{
            alias: String.t(),
            variable: String.t(),
            name: atom()
          }
  end

  defmodule Fragment do
    defstruct [:expr, :alias]

    @type t :: %__MODULE__{
            expr: String.t(),
            alias: String.t()
          }
  end

  defmodule LabelOperationExpr do
    defstruct [:variable, :set, :remove]

    @type t :: %__MODULE__{
            variable: String.t(),
            set: [String.t()],
            remove: [String.t()]
          }
  end

  defmodule ValueExpr do
    defstruct [:name, :variable, :value]

    @type t :: %__MODULE__{
            name: atom(),
            variable: String.t(),
            value: any
          }
  end

  defmodule OrderExpr do
    defstruct [:field, order: :asc]

    @type t :: %__MODULE__{
            field: FieldExpr.t(),
            order: atom()
          }
  end

  defmodule AggregateExpr do
    defstruct [:alias, :operator, :field, :entity, distinct?: false]

    @type t :: %__MODULE__{
            alias: String.t(),
            operator: atom(),
            field: nil | FieldExpr.t(),
            entity: nil | NodeExpr.t() | RelationshipExpr.t(),
            distinct?: boolean()
          }
  end

  defmodule CollectExpr do
    defstruct [:alias, :variable]

    @type t :: %__MODULE__{
            alias: String.t(),
            variable: String.t()
          }
  end

  defmodule ReturnExpr do
    defstruct [:fields, distinct?: false]

    @type t :: %__MODULE__{
            fields: [
              nil
              | FieldExpr.t()
              | AggregateExpr.t()
              | NodeExpr.t()
              | RelationshipExpr.t()
              | CollectExpr.t()
              | ValueExpr.t()
              | Fragment.t()
            ],
            distinct?: boolean()
          }
  end

  defmodule SetExpr do
    defstruct [:field, :value, :increment]

    @type t :: %__MODULE__{
            field: FieldExpr.t(),
            value: any(),
            increment: integer()
          }
  end

  defmodule MergeExpr do
    defstruct [:expr, on_create: [], on_match: []]

    @type t :: %__MODULE__{
            expr: Neo4jex.Query.Builder.entity_expr(),
            on_create: [SetExpr.t()],
            on_match: [SetExpr.t()]
          }
  end

  defmodule BatchExpr do
    defstruct [:with, :skip, :limit]

    @type t :: %__MODULE__{
            with: ReturnExpr.t(),
            skip: nil | integer | atom,
            limit: nil | integer | atom
          }
  end

  defmodule Batch do
    defstruct [:type, :chunk_size, :__expr, is_batch?: false]

    @type t :: %__MODULE__{
            is_batch?: boolean,
            type: :basic | :with_skip,
            chunk_size: integer(),
            __expr: nil | BatchExpr.t()
          }
  end

  defstruct [
    :operation,
    :optional_match,
    :match,
    :create,
    :merge,
    :delete,
    :where,
    :return,
    :set,
    :label_ops,
    :params,
    :order_by,
    :skip,
    :limit,
    :batch
  ]

  @type t :: %__MODULE__{
          operation: atom(),
          match: [entity_expr],
          optional_match: [entity_expr],
          create: [entity_expr],
          merge: [MergeExpr.t()],
          delete: [entity_expr],
          where: nil | Neo4jex.Query.Condition.t(),
          set: [SetExpr.t()],
          label_ops: [LabelOperationExpr.t()],
          return: nil | ReturnExpr.t(),
          params: map(),
          order_by: [OrderExpr.t()],
          skip: nil | integer() | atom(),
          limit: nil | integer() | atom(),
          batch: Batch.t()
        }

  alias Neo4jex.Query.Builder

  @chunk_size Application.get_env(:ecto_neo4j, Neo4jex, chunk_size: 10_000)
              |> Keyword.get(:chunk_size)
  @is_batch? Application.get_env(:ecto_neo4j, Neo4jex, batch: false)
             |> Keyword.get(:batch)

  @doc """
  Initilaize the Builder struct
  """
  @spec new(atom()) :: Builder.t()
  def new(operation \\ :match) do
    %Builder{
      operation: operation,
      match: [],
      optional_match: [],
      create: [],
      merge: [],
      where: nil,
      set: [],
      label_ops: [],
      delete: [],
      return: nil,
      params: %{},
      order_by: [],
      skip: nil,
      limit: nil,
      batch: %Batch{
        is_batch?: @is_batch?,
        type: :basic,
        chunk_size: @chunk_size
      }
    }
  end

  @doc """
  Adds information regarding batch query.

  See `Neo4jex.batch_query\4` for more info about batch queries.
  """
  @spec batch(Builder.t(), Batch.t()) :: Builder.t()
  def batch(query, %Batch{} = batch_opt) do
    batch =
      case query.operation in [:update, :update_all] do
        true ->
          %{batch_opt | type: :with_skip}

        _ ->
          %{batch_opt | type: :basic}
      end

    %{query | batch: Map.merge(query.batch, batch)}
  end

  @doc """
  Adds MATCH data
  """
  @spec match(Builder.t(), [entity_expr]) :: Builder.t()
  def match(query, match) when is_list(match) do
    %{query | match: query.match ++ match}
  end

  @doc """
  Adds CREATE data
  """
  @spec create(Builder.t(), [entity_expr]) :: Builder.t()
  def create(query, create) when is_list(create) do
    %{query | create: query.create ++ create}
  end

  @doc """
  Adds OPTIONAL MATCH data
  """
  @spec optional_match(Builder.t(), [entity_expr]) :: Builder.t()
  def optional_match(query, optional_match) when is_list(optional_match) do
    %{query | optional_match: query.optional_match ++ optional_match}
  end

  @doc """
  Adds MERGE data
  """
  @spec merge(Builder.t(), [MergeExpr.t()]) :: Builder.t()
  def merge(query, merges) when is_list(merges) do
    {merge_list, params} =
      Enum.reduce(merges, {[], %{}}, fn merge, {treated_merges, params} ->
        {expr, new_params} = parameterize_expr(merge.expr)
        new_merge = %{merge | expr: expr}
        {[new_merge | treated_merges], Map.merge(params, new_params)}
      end)

    query
    |> params(params)
    |> Map.put(:merge, query.merge ++ merge_list)
  end

  defp parameterize_expr(%NodeExpr{properties: props} = node) do
    data =
      Enum.reduce(props, %{properties: %{}, params: %{}}, fn {prop, value}, acc ->
        bound_name = node.variable <> "_" <> Atom.to_string(prop)

        %{
          acc
          | properties: Map.put(acc.properties, prop, bound_name),
            params: Map.put(acc.params, String.to_atom(bound_name), value)
        }
      end)

    node = Map.put(node, :properties, data.properties)

    {node, data.params}
  end

  defp parameterize_expr(expr) do
    {expr, %{}}
  end

  @doc """
  Adds DELETE data
  """
  @spec delete(Builder.t(), [entity_expr]) :: Builder.t()
  def delete(query, delete) when is_list(delete) do
    %{query | delete: query.delete ++ delete}
  end

  @doc """
  Adds WHERE data
  """
  @spec where(Builder.t(), nil | Neo4jex.Query.Condition.t()) :: Builder.t()
  def where(%Builder{where: nil} = query, %Neo4jex.Query.Condition{} = condition) do
    %{query | where: condition}
  end

  def where(%Builder{where: query_cond} = query, %Neo4jex.Query.Condition{} = condition) do
    new_condition = %Neo4jex.Query.Condition{
      operator: :and,
      conditions: [
        query_cond,
        condition
      ]
    }

    %{query | where: new_condition}
  end

  def where(query, nil) do
    query
  end

  @doc """
  Adds SET data
  """
  @spec set(Builder.t(), nil | [SetExpr.t()]) :: Builder.t()
  def set(query, sets) when is_list(sets) do
    %{query | set: query.set ++ sets}
  end

  def set(query, nil) do
    query
  end

  @spec label_ops(Builder.t(), [LabelOperationExpr.t()]) :: Builder.t()
  def label_ops(query, label_ops) when is_list(label_ops) do
    %{query | label_ops: query.label_ops ++ label_ops}
  end

  @doc """
  Adds RETLURN data
  """
  @spec return(Builder.t(), ReturnExpr.t()) :: Builder.t()
  def return(query, %ReturnExpr{} = return) do
    %{query | return: return}
  end

  @doc """
  Adds params
  """
  @spec params(Builder.t(), map) :: Builder.t()
  def params(query, %{} = params) do
    %{query | params: Map.merge(query.params, params)}
  end

  @doc """
  Adds ORDER BY data
  """
  @spec order_by(Builder.t(), [OrderExpr.t()]) :: Builder.t()
  def order_by(query, order_by) do
    %{query | order_by: order_by}
  end

  @doc """
  Adds LIMIT data
  """
  @spec limit(Builder.t(), nil | integer()) :: Builder.t()
  def limit(query, nil) do
    query
  end

  def limit(query, limit) do
    %{query | limit: limit}
  end

  @doc """
  Adds SKIP data
  """
  @spec skip(Builder.t(), nil | integer() | atom()) :: Builder.t()
  def skip(query, nil) do
    query
  end

  def skip(query, skip) do
    %{query | skip: skip}
  end

  @spec batchify_query(Builder.t()) :: Builder.t()
  defp batchify_query(%Builder{batch: %{is_batch?: true}, operation: operation} = query)
       when operation in [:update, :update_all, :delete, :delete_all] do
    node = List.first(query.match)

    return = %ReturnExpr{
      fields: [
        %AggregateExpr{
          alias: "nb_touched_nodes",
          operator: :count,
          entity: node,
          distinct?: false
        }
      ],
      distinct?: false
    }

    batch_with = %ReturnExpr{
      fields: [
        Map.put(node, :alias, node.variable)
      ],
      distinct?: false
    }

    batch_skip =
      if operation in [:update, :update_all] do
        :skip
      end

    batch_expr = %BatchExpr{
      with: batch_with,
      skip: batch_skip,
      limit: :limit
    }

    query
    |> Builder.return(return)
    |> Builder.skip(nil)
    |> Builder.limit(nil)
    |> Builder.order_by([])
    |> Builder.params(%{limit: query.batch.chunk_size})
    |> Builder.batch(%{query.batch | __expr: batch_expr})
  end

  defp batchify_query(query) do
    query
  end

  @spec to_string(Builder.t()) :: {String.t(), map}
  def to_string(bare_query) do
    query = batchify_query(bare_query)

    match =
      query.match
      |> MapSet.new()
      |> MapSet.to_list()
      |> stringify_match()

    optional_match =
      query.optional_match
      |> MapSet.new()
      |> MapSet.to_list()
      |> stringify_match()

    create =
      query.create
      |> MapSet.new()
      |> MapSet.to_list()
      |> stringify_match()

    cql_merge = stringify_merges(query.merge)
    where = stringify_where(query.where)
    return = stringify_return(query.return)
    delete = stringify_delete(query.delete)
    order_by = stringify_order_by(query.order_by)
    limit = stringify_limit(query.limit)
    skip = stringify_skip(query.skip)
    cql_batch = stringify_batch(query.batch)

    cql_match =
      if String.length(match) > 0 do
        """
        MATCH
          #{match}
        """
      end

    cql_optional_match =
      if String.length(optional_match) > 0 do
        """
        OPTIONAL MATCH
          #{optional_match}
        """
      end

    cql_create =
      if String.length(create) > 0 do
        """
        CREATE
          #{create}
        """
      end

    cql_return =
      if String.length(return) > 0 do
        """
        RETURN
          #{return}
        """
      end

    cql_set =
      if length(query.set) > 0 do
        sets =
          query.set
          |> Enum.map(&stringify_set/1)
          |> Enum.join(",\n  ")

        """
        SET
          #{sets}
        """
      end

    cql_label_op =
      if length(query.label_ops) > 0 do
        query.label_ops
        |> Enum.map(&stringify_label_ops/1)
        |> Enum.join("\n")
      end

    cql_where =
      if String.length(where) > 0 do
        """
        WHERE
          #{where}
        """
      end

    cql_order_by =
      if String.length(order_by) > 0 do
        """
        ORDER BY
          #{order_by}
        """
      end

    cql_skip =
      if String.length(skip) > 0 do
        """
        SKIP #{skip}
        """
      end

    cql_limit =
      if String.length(limit) > 0 do
        """
        LIMIT #{limit}
        """
      end

    cql_delete =
      if String.length(delete) > 0 do
        """
        DETACH DELETE
          #{delete}
        """
      end

    cql = """
    #{cql_match}
    #{cql_where}
    #{cql_optional_match}
    #{cql_create}
    #{cql_merge}
    #{cql_batch}
    #{cql_delete}
    #{cql_set}
    #{cql_label_op}
    #{cql_return}
    #{cql_order_by}
    #{cql_skip}
    #{cql_limit}
    """

    {cql, query.params}
  end

  @spec stringify_match([entity_expr]) :: String.t()
  defp stringify_match(matches) do
    Enum.map(matches, &stringify_match_entity/1)
    |> Enum.join(",\n")
  end

  # @spec stringify_match_entity(entity_expr) :: String.t()
  # defp stringify_match_entity(%NodeExpr{variable: variable, labels: [label]}) do
  #   "(#{variable}:#{label})"
  # end

  defp stringify_match_entity(%NodeExpr{
         variable: variable,
         labels: labels,
         properties: properties
       })
       when is_list(labels) do
    labels_str =
      Enum.map(labels, fn label ->
        ":#{label}"
      end)
      |> Enum.join()

    props = stringify_entity_props(properties)

    "(#{variable}#{labels_str}#{props})"
  end

  defp stringify_match_entity(%NodeExpr{variable: variable}) do
    "(#{variable})"
  end

  defp stringify_match_entity(%NodeExpr{labels: labels}) when is_list(labels) do
    labels_str =
      Enum.map(labels, fn label ->
        ":#{label}"
      end)
      |> Enum.join()

    "(#{labels_str})"
  end

  defp stringify_match_entity(%RelationshipExpr{
         start: start_node,
         end: end_node,
         type: rel_type,
         variable: variable
       }) do
    cql_type =
      unless is_nil(rel_type) do
        ":#{rel_type}"
      end

    stringify_match_entity(start_node) <>
      "-[#{variable}#{cql_type}]->" <> stringify_match_entity(end_node)
  end

  defp stringify_entity_props(properties) do
    props_str =
      Enum.map(properties, fn {prop, bound_name} ->
        "#{Atom.to_string(prop)}: $#{bound_name}"
      end)
      |> Enum.join(",")

    " {#{props_str}}"
  end

  @spec stringify_merges([MergeExpr.t()]) :: String.t()
  defp stringify_merges(merges) do
    merges
    |> Enum.map(&stringify_merge/1)
    |> Enum.join(" \n")
  end

  @spec stringify_merge(nil | MergeExpr.t()) :: String.t()
  defp stringify_merge(%MergeExpr{expr: entity, on_create: create_sets, on_match: match_sets}) do
    cql_create =
      if length(create_sets) > 0 do
        sets =
          create_sets
          |> Enum.map(&stringify_set/1)
          |> Enum.join(",\n  ")

        """
        ON CREATE SET
          #{sets}
        """
      end

    cql_match_set =
      if length(match_sets) > 0 do
        sets =
          match_sets
          |> Enum.map(&stringify_set/1)
          |> Enum.join(",\n  ")

        """
        ON MATCH SET
          #{sets}
        """
      end

    """
    MERGE
      #{stringify_match_entity(entity)}
    #{cql_create}
    #{cql_match_set}
    """
  end

  defp stringify_merge(_) do
    ""
  end

  @spec stringify_delete([]) :: String.t()
  defp stringify_delete(deletes) do
    Enum.map(deletes, fn %{variable: variable} ->
      variable
    end)
    |> Enum.join(", ")
  end

  @spec stringify_where(nil | Neo4jex.Query.Condition.t()) :: String.t()
  defp stringify_where(condition) do
    Neo4jex.Query.Condition.stringify_condition(condition)
  end

  @spec stringify_return(ReturnExpr.t()) :: String.t()
  defp stringify_return(%ReturnExpr{fields: fields, distinct?: distinct?}) do
    distinct =
      if distinct? do
        "DISTINCT "
      end

    fields_cql =
      Enum.map(fields, fn
        nil ->
          "NULL"

        %NodeExpr{} = node ->
          stringify_node(node)

        %RelationshipExpr{} = relationship ->
          stringify_relationship(relationship)

        %AggregateExpr{} = aggregate ->
          stringify_aggregate(aggregate)

        %CollectExpr{} = collect ->
          stringify_collect(collect)

        %FieldExpr{} = field ->
          stringify_field(field)

        %ValueExpr{} = value ->
          stringify_value(value)

        %Fragment{} = fragment ->
          stringify_fragment(fragment)
      end)
      |> Enum.join(", ")

    "#{distinct}#{fields_cql}"
  end

  defp stringify_return(_) do
    ""
  end

  @spec stringify_set(SetExpr.t()) :: String.t()
  defp stringify_set(%SetExpr{field: field, increment: increment}) when not is_nil(increment) do
    "#{stringify_field(field)} = #{stringify_field(field)} + $#{increment}"
  end

  defp stringify_set(%SetExpr{field: field, value: value}) do
    "#{stringify_field(field)} = $#{value}"
  end

  @spec stringify_label_ops(LabelOperationExpr.t()) :: String.t()
  defp stringify_label_ops(%LabelOperationExpr{variable: variable} = label_op) do
    stringify_label_ops_set(variable, Map.get(label_op, :set, [])) <>
      "\n" <>
      stringify_label_ops_remove(variable, Map.get(label_op, :remove, []))
  end

  @spec stringify_label_ops_set(String.t(), [String.t()]) :: String.t()
  defp stringify_label_ops_set(_, []) do
    ""
  end

  defp stringify_label_ops_set(variable, labels) do
    "SET " <> do_stringify_label_ops(variable, labels)
  end

  @spec stringify_label_ops_remove(String.t(), [String.t()]) :: String.t()

  defp stringify_label_ops_remove(_, []) do
    ""
  end

  defp stringify_label_ops_remove(variable, labels) do
    "REMOVE " <> do_stringify_label_ops(variable, labels)
  end

  defp do_stringify_label_ops(variable, labels) do
    Enum.map(labels, fn label -> "#{variable}:#{label}" end)
    |> Enum.join(", ")
  end

  @spec stringify_batch(Batch.t()) :: String.t()
  defp stringify_batch(%Batch{is_batch?: true, __expr: expression}) do
    skip = stringify_skip(expression.skip)

    cql_skip =
      if String.length(skip) > 0 do
        "SKIP #{skip}"
      end

    """
    WITH
      #{stringify_return(expression.with)}
    #{cql_skip}
    LIMIT #{stringify_limit(expression.limit)}
    """
  end

  defp stringify_batch(_) do
    ""
  end

  @spec stringify_order_by([]) :: String.t()
  defp stringify_order_by(order_bys) when is_list(order_bys) do
    Enum.map(order_bys, fn %OrderExpr{order: order, field: field} ->
      stringify_field(field) <> " " <> format_operator(order)
    end)
    |> Enum.join(", ")
  end

  @spec stringify_limit(nil | integer | atom) :: String.t()
  defp stringify_limit(limit) when is_integer(limit) do
    Integer.to_string(limit)
  end

  defp stringify_limit(nil) do
    ""
  end

  defp stringify_limit(limit) when is_atom(limit) do
    "{#{Atom.to_string(limit)}}"
  end

  @spec stringify_skip(nil | integer | atom()) :: String.t()
  defp stringify_skip(skip) when is_integer(skip) do
    Integer.to_string(skip)
  end

  defp stringify_skip(nil) do
    ""
  end

  defp stringify_skip(skip) when is_atom(skip) do
    "{#{Atom.to_string(skip)}}"
  end

  @spec stringify_field(FieldExpr.t()) :: String.t()
  defp stringify_field(%FieldExpr{variable: variable, name: field, alias: alias}) do
    field_name = Atom.to_string(field)

    case alias do
      nil -> "#{variable}.#{field_name}"
      field_alias -> "#{variable}.#{field_name} AS #{field_alias}"
    end
  end

  @spec stringify_node(NodeExpr.t()) :: String.t()
  defp stringify_node(%NodeExpr{alias: node_alias, variable: variable})
       when not is_nil(node_alias) do
    "#{variable} AS #{node_alias}"
  end

  defp stringify_node(%NodeExpr{variable: variable}) do
    variable
  end

  @spec stringify_relationship(RelationshipExpr.t()) :: String.t()

  defp stringify_relationship(%RelationshipExpr{alias: rel_alias, variable: variable})
       when not is_nil(rel_alias) do
    "#{variable} AS #{rel_alias}"
  end

  defp stringify_relationship(%RelationshipExpr{variable: variable}) do
    variable
  end

  @spec stringify_aggregate(AggregateExpr.t()) :: String.t()
  defp stringify_aggregate(%AggregateExpr{field: field} = aggregate) when not is_nil(field) do
    do_stringify_aggregate(aggregate, stringify_field(field))
  end

  defp stringify_aggregate(%AggregateExpr{entity: %{variable: variable}} = aggregate) do
    do_stringify_aggregate(aggregate, variable)
  end

  @spec do_stringify_aggregate(AggregateExpr.t(), String.t()) :: String.t()
  defp do_stringify_aggregate(
         %AggregateExpr{alias: agg_alias, operator: operator, distinct?: distinct?},
         target
       ) do
    cql_distinct =
      if distinct? do
        "DISTINCT "
      end

    cql_alias =
      unless is_nil(agg_alias) do
        " AS #{agg_alias}"
      end

    "#{format_operator(operator)}(#{cql_distinct}#{target})#{cql_alias}"
  end

  @spec stringify_collect(CollectExpr.t()) :: String.t()
  defp stringify_collect(%CollectExpr{alias: collect_alias, variable: variable}) do
    "COLLECT (#{variable}) AS #{collect_alias}"
  end

  @spec stringify_value(ValueExpr.t()) :: String.t()
  defp stringify_value(%ValueExpr{variable: variable, name: name, value: value}) do
    "#{inspect(value)} AS #{variable}_#{Atom.to_string(name)}"
  end

  @spec stringify_fragment(Fragment.t()) :: String.t()
  defp stringify_fragment(%Fragment{expr: expr, alias: nil}) do
    expr
  end

  defp stringify_fragment(%Fragment{expr: expr, alias: fragment_alias}) do
    "#{expr} AS #{fragment_alias}"
  end

  @spec format_operator(atom()) :: String.t()
  defp format_operator(operator) do
    operator
    |> Atom.to_string()
    |> String.upcase()
  end

  # defp parameterize_expr(%NodeExpr{properties: props} = node, acc) do
  #   data =
  #     Enum.reduce(props, %{properties: %{}, params: %{}}, fn {prop, value}, acc ->
  #       bound_name = node.variable <> "_" <> Atom.to_string(prop)

  #       %{
  #         acc
  #         | properties: Map.put(acc.properties, prop, bound_name),
  #           params: Map.put(acc.params, String.to_atom(bound_name), value)
  #       }
  #     end)

  #   node = Map.put(node, :properties, data.properties)

  #   %{
  #     acc
  #     | expr: [node | acc.expr],
  #       params: data.params
  #   }
  # end

  # defp parameterize_expr(expr, acc) do
  #   %{acc | expr: [expr | acc.expr]}
  # end
end
