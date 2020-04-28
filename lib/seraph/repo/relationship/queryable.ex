defmodule Seraph.Repo.Relationship.Queryable do
  @moduledoc false

  alias Seraph.Query.{Builder, Condition, Planner}

  @doc """
  Fetch a single struct from the Neo4j datababase with the given start and end node data/struct.

  Returns `nil` if no result was found
  """
  @spec get(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map
        ) :: nil | Seraph.Schema.Relationship.t()
  def get(repo, queryable, start_struct_or_data, end_struct_or_data) do
    queryable.__schema__(:start_node)

    {start_node, start_params} =
      node_data("start", queryable.__schema__(:start_node), start_struct_or_data)

    {end_node, end_params} = node_data("end", queryable.__schema__(:end_node), end_struct_or_data)

    relationship = %Builder.RelationshipExpr{
      variable: "rel",
      start: start_node,
      end: end_node,
      type: queryable.__schema__(:type)
    }

    {statement, params} =
      Builder.new()
      |> Builder.match([relationship])
      |> Builder.return(%Builder.ReturnExpr{
        fields: [relationship, start_node, end_node]
      })
      |> Builder.params(Map.merge(start_params, end_params))
      |> Builder.to_string()

    {:ok, result} = Planner.query(repo, statement, params)

    case length(result) do
      0 ->
        nil

      1 ->
        format_result(queryable, List.first(result))

      count ->
        raise Seraph.MultipleRelationshipsError,
          queryable: queryable,
          count: count,
          start_node: queryable.__schema__(:start_node),
          end_node: queryable.__schema__(:end_node),
          params: %{
            start: start_struct_or_data,
            end: end_struct_or_data
          }
    end
  end

  @doc """
  Same as `get/4` but raises when no result is found.
  """
  @spec get!(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Seraph.Schema.Node.t() | map,
          Seraph.Schema.Node.t() | map
        ) :: Seraph.Schema.Relationship.t()
  def get!(repo, queryable, start_struct_or_data, end_struct_or_data) do
    case get(repo, queryable, start_struct_or_data, end_struct_or_data) do
      nil ->
        params = %{
          start: start_struct_or_data,
          end: end_struct_or_data
        }

        raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: params

      result ->
        result
    end
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given data.

  Returns `nil` if no result was found
  """
  @spec get_by(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Keyword.t() | map,
          Keyword.t() | map,
          Keyword.t() | map
        ) :: nil | Seraph.Schema.Relationship.t()
  def get_by(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
    {start_node, start_condition, start_params} =
      build_get_by_node(queryable.__schema__(:start_node), start_node_clauses, :start_node)

    {end_node, end_condition, end_params} =
      build_get_by_node(queryable.__schema__(:end_node), end_node_clauses, :end_node)

    nodes_condition = Condition.join_conditions(start_condition, end_condition)

    %{properties: rel_props, condition: rel_condition, params: rel_params} =
      Seraph.Repo.Helper.to_props_and_conditions(relationship_clauses, "rel")

    rel_to_get = %Builder.RelationshipExpr{
      start: start_node,
      end: end_node,
      variable: "rel",
      type: queryable.__schema__(:type),
      properties: rel_props
    }

    condition = Condition.join_conditions(nodes_condition, rel_condition)

    params =
      start_params
      |> Map.merge(end_params)
      |> Map.merge(rel_params)

    {statement, params} =
      Builder.new()
      |> Builder.match([rel_to_get])
      |> Builder.where(condition)
      |> Builder.return(%Builder.ReturnExpr{
        fields: [start_node, end_node, rel_to_get]
      })
      |> Builder.params(params)
      |> Builder.to_string()

    {:ok, result} = Planner.query(repo, statement, params)

    case length(result) do
      0 ->
        nil

      1 ->
        format_result(queryable, List.first(result))

      count ->
        raise Seraph.MultipleRelationshipsError,
          queryable: queryable,
          count: count,
          start_node: queryable.__schema__(:start_node),
          end_node: queryable.__schema__(:end_node),
          params: %{
            start: start_node_clauses,
            end: end_node_clauses
          }
    end
  end

  @doc """
  Same as `get/5` but raise when no result is found.
  """
  @spec get_by!(
          Seraph.Repo.t(),
          Seraph.Repo.queryable(),
          Keyword.t() | map,
          Keyword.t() | map,
          Keyword.t() | map
        ) ::
          Seraph.Schema.Relationship.t()
  def get_by!(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
    case get_by(repo, queryable, start_node_clauses, end_node_clauses, relationship_clauses) do
      nil ->
        raise Seraph.NoResultsError,
          queryable: queryable,
          function: :get!,
          params: %{
            start_node: start_node_clauses,
            end_node: end_node_clauses,
            relationship: relationship_clauses
          }

      result ->
        result
    end
  end

  defp build_get_by_node(queryable, clauses, node_type) do
    {additional_labels, cond_clauses} =
      clauses
      |> Enum.to_list()
      |> Keyword.pop(:additionalLabels, [])

    variable =
      case node_type do
        :start_node -> "start"
        :end_node -> "end"
      end

    %{properties: properties, condition: condition, params: params} =
      Seraph.Repo.Helper.to_props_and_conditions(cond_clauses, variable)

    node = %Builder.NodeExpr{
      variable: variable,
      labels: [queryable.__schema__(:primary_label) | additional_labels],
      properties: properties
    }

    {node, condition, params}
  end

  @spec node_data(String.t(), Seraph.Repo.queryable(), Seraph.Schema.Node.t() | map) ::
          {Builder.NodeExpr.t(), map}
  defp node_data(node_var, queryable, %{__struct__: _} = data) do
    id_field = Seraph.Repo.Helper.identifier_field(queryable)

    bound_name = node_var <> "_" <> Atom.to_string(id_field)
    props = Map.put(%{}, id_field, bound_name)
    params = Map.put(%{}, String.to_atom(bound_name), Map.fetch!(data, id_field))

    node = %Builder.NodeExpr{
      variable: node_var,
      labels: [queryable.__schema__(:primary_label) | data.additionalLabels],
      properties: props
    }

    {node, params}
  end

  defp node_data(node_var, queryable, data) do
    query_node_data =
      Enum.reduce(data, %{properties: %{}, params: %{}}, fn {prop_name, prop_value}, node_data ->
        bound_name = node_var <> "_" <> Atom.to_string(prop_name)

        %{
          node_data
          | properties: Map.put(node_data.properties, prop_name, bound_name),
            params: Map.put(node_data.params, String.to_atom(bound_name), prop_value)
        }
      end)

    node = %Builder.NodeExpr{
      variable: node_var,
      labels: [queryable.__schema__(:primary_label)],
      properties: query_node_data.properties
    }

    {node, query_node_data.params}
  end

  @spec format_result(Seraph.Repo.queryable(), map) :: Seraph.Schema.Relationship.t()
  defp format_result(queryable, %{"rel" => rel_data, "start" => start_data, "end" => end_data}) do
    props =
      rel_data.properties
      |> atom_map()
      |> Map.put(:__id__, rel_data.id)
      |> Map.put(:start_node, build_node(queryable.__schema__(:start_node), start_data))
      |> Map.put(:end_node, build_node(queryable.__schema__(:end_node), end_data))

    struct(queryable, props)
  end

  @spec build_node(Seraph.Repo.queryable(), map) :: Seraph.Schema.Node.t()
  defp build_node(queryable, node_data) do
    props =
      node_data.properties
      |> atom_map()
      |> Map.put(:__id__, node_data.id)
      |> Map.put(:additionalLabels, node_data.labels -- [queryable.__schema__(:primary_label)])

    struct(queryable, props)
  end

  @spec atom_map(map) :: map
  defp atom_map(string_map) do
    string_map
    |> Enum.map(fn {k, v} ->
      {String.to_atom(k), v}
    end)
    |> Enum.into(%{})
  end
end
