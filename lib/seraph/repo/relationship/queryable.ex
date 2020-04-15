defmodule Seraph.Repo.Relationship.Queryable do
  @moduledoc false

  alias Seraph.Query.{Builder, Planner}

  @doc """
  Fetch a single struct from the Neo4j datababase with the given start and end node data/struct.

  Returns `nil` if no result was found
  """
  @spec get(
          Seraph.Repo.t(),
          Seraph.Repo.Queryable.t(),
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
          Queryable.t(),
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

  @spec node_data(String.t(), Seraph.Repo.Queryable.t(), Seraph.Schema.Node.t() | map) ::
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

  @spec format_result(Seraph.Repo.Queryable.t(), map) :: Seraph.Schema.Relationship.t()
  defp format_result(queryable, %{"rel" => rel_data, "start" => start_data, "end" => end_data}) do
    props =
      rel_data.properties
      |> atom_map()
      |> Map.put(:__id__, rel_data.id)
      |> Map.put(:start_node, build_node(queryable.__schema__(:start_node), start_data))
      |> Map.put(:end_node, build_node(queryable.__schema__(:end_node), end_data))

    struct(queryable, props)
  end

  @spec build_node(Seraph.Repo.Queryable.t(), map) :: Seraph.Schema.Node.t()
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
