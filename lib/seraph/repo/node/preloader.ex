defmodule Seraph.Repo.Node.Preloader do
  @moduledoc false

  alias Seraph.Query.Builder
  alias Seraph.Query.Builder.Entity

  @default_load :all
  @default_limit :infinity

  @type result :: %{
          :preload => Bolt.Sips.Types.Node.t(),
          optional(:rel) => Bolt.Sips.Types.Relationship.t()
        }

  @type options :: Keyword.t()

  @doc """
  Preload relationship type data
  """
  @spec preload(Seraph.Repo.t(), Seraph.Schema.Node.t(), atom | [atom], options()) ::
          Seraph.Schema.Node.t()
  def preload(repo, struct, preload, opts) when is_atom(preload) do
    preload(repo, struct, [preload], opts)
  end

  def preload(repo, %{__struct__: queryable} = struct, preloads, opts) when is_list(preloads) do
    check_preload_opts(opts)
    bare_struct = bare_node_struct(struct)

    load = Keyword.get(opts, :load, @default_load)
    force = Keyword.get(opts, :force, false)

    rel_infos =
      Enum.map(preloads, &relation_info(queryable, &1))
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.reject(&already_preloaded?(struct, &1, load, force))

    reinit_struct =
      if force do
        Enum.reduce(rel_infos, struct, fn %{field: field, type: rel_type}, init_struct ->
          rel_field =
            rel_type
            |> String.downcase()
            |> String.to_atom()

          init_struct
          |> Map.put(field, %Seraph.Schema.Node.NotLoaded{})
          |> Map.put(rel_field, %Seraph.Schema.Relationship.NotLoaded{})
        end)
      else
        struct
      end

    rel_infos
    |> Enum.map(&preload_one(repo, &1, reinit_struct, bare_struct, opts))
    |> List.flatten()
    |> Enum.reduce(reinit_struct, fn {preload_key, preload_data}, result ->
      case Map.get(result, preload_key) do
        %{} ->
          Map.put(result, preload_key, preload_data)

        data when is_list(data) ->
          Map.put(result, preload_key, data ++ preload_data)
      end
    end)
  end

  @spec preload_one(
          Seraph.Repo.t(),
          Seraph.Schema.Relationship.Outgoing.t() | Seraph.Schema.Relationship.Incoming.t(),
          Seraph.Schema.Node.t(),
          Seraph.Schema.Node.t(),
          options()
        ) :: Keyword.t()
  defp preload_one(repo, rel_info, struct, bare_struct, opts) do
    %{__struct__: queryable} = struct
    id_field = Seraph.Repo.Helper.identifier_field!(queryable)
    properties = Map.put(%{}, id_field, Map.fetch!(struct, id_field))

    load = Keyword.get(opts, :load, @default_load)

    {start_node_data, end_node_data} =
      case rel_info.direction do
        :outgoing ->
          start_node = Entity.Node.from_queryable(queryable, properties, "preload__", "source")
          end_node = Entity.Node.from_queryable(rel_info.end_node, %{}, "preload__", "preload")
          {start_node, end_node}

        :incoming ->
          start_node =
            Entity.Node.from_queryable(rel_info.start_node, %{}, "preload__", "preload")

          end_node = Entity.Node.from_queryable(queryable, properties, "preload__", "source")
          {start_node, end_node}
      end

    relationship = %Entity.Relationship{
      start: start_node_data.entity,
      end: end_node_data.entity,
      identifier: "rel",
      queryable: rel_info.schema,
      type: rel_info.type
    }

    return_node = %Builder.Return{
      raw_variables: [
        %Builder.Entity.EntityData{
          entity_identifier: :preload
        }
      ]
    }

    return =
      case load do
        :nodes ->
          return_node

        _ ->
          return_rel = %Builder.Entity.EntityData{
            entity_identifier: :rel
          }

          %{return_node | raw_variables: [return_rel | return_node.raw_variables]}
      end

    identifiers =
      %{"rel" => relationship}
      |> Map.put(start_node_data.entity.identifier, start_node_data.entity)
      |> Map.put(end_node_data.entity.identifier, end_node_data.entity)

    order_data = %Entity.EntityData{
      entity_identifier: "preload",
      property: properties |> Map.keys() |> List.first()
    }

    unlimited_ops = [
      match: %Builder.Match{
        entities: [relationship]
      },
      return: return,
      order_by: %Builder.OrderBy{
        raw_orders: [%Builder.Entity.Order{entity: order_data}]
      }
    ]

    operations =
      case Keyword.get(opts, :limit, @default_limit) do
        :infinity ->
          unlimited_ops

        limit ->
          Keyword.merge(unlimited_ops, limit: %Builder.Limit{value: limit})
      end

    {nodes_data, rels_data} =
      %Seraph.Query{
        identifiers: identifiers,
        operations: operations,
        params: Keyword.merge(start_node_data.params, end_node_data.params)
      }
      |> repo.execute!()
      |> format_results(rel_info, bare_struct)

    preload_rel_field =
      rel_info.type
      |> String.downcase()
      |> String.to_atom()

    case load do
      :all ->
        [{preload_rel_field, rels_data}, {rel_info.field, nodes_data}]

      :nodes ->
        [{rel_info.field, nodes_data}]

      :relationships ->
        [{preload_rel_field, rels_data}]
    end
  end

  @spec already_preloaded?(
          Seraph.Schema.Node.t(),
          Seraph.Schema.Relationship.Outgoing.t() | Seraph.Schema.Relationship.Incoming.t(),
          :all | :nodes | :relationships,
          boolean
        ) :: boolean
  defp already_preloaded?(_, _, _, true) do
    false
  end

  defp already_preloaded?(struct, relationship_info, load, _force) do
    nodes_data = Map.fetch!(struct, relationship_info.field)

    rel_type =
      relationship_info.type
      |> String.downcase()
      |> String.to_atom()

    rels_data = Map.fetch!(struct, rel_type)

    nodes_preloaded? = not Kernel.match?(%Seraph.Schema.Node.NotLoaded{}, nodes_data)
    rels_preloaded? = not Kernel.match?(%Seraph.Schema.Relationship.NotLoaded{}, rels_data)

    case load do
      :all ->
        nodes_preloaded? && rels_preloaded?

      :nodes ->
        nodes_preloaded?

      :relationships ->
        rels_preloaded?
    end
  end

  @spec format_results(
          [result],
          Seraph.Schema.Relationship.Outgoing.t() | Seraph.Schema.Relationship.Incoming.t(),
          Seraph.Schema.Node.t()
        ) :: {nil | [Seraph.Schema.Node.t()], nil | [Seraph.Schema.Relationship.t()]}
  defp format_results([], %{cardinality: :one}, _) do
    {nil, nil}
  end

  defp format_results([], %{cardinality: :many}, _) do
    {[], []}
  end

  defp format_results([result], %{cardinality: :one} = relationship_info, bare_struct) do
    format_result(result, relationship_info, bare_struct)
  end

  defp format_results(_, %{cardinality: :one} = relationship_info, %{__struct__: node_struct}) do
    raise Seraph.Error,
          "Cannot preload #{relationship_info.type} relationship on #{inspect(node_struct)}.
    There is more than one relationship found but its cardinality is :one."
  end

  defp format_results(results, relationship_info, bare_struct) do
    Enum.reduce(results, {[], []}, fn result, {nodes, rels} ->
      {preload_node, preload_rel} = format_result(result, relationship_info, bare_struct)
      {[preload_node | nodes], [preload_rel | rels]}
    end)
  end

  @spec format_result(
          result,
          Seraph.Schema.Relationship.Outgoing.t() | Seraph.Schema.Relationship.Incoming.t(),
          Seraph.Schema.Node.t()
        ) :: {Seraph.Schema.Node.t(), Seraph.Schema.Relationship.t()}
  defp format_result(%{"preload" => preload_node} = results, %{direction: :outgoing}, bare_struct) do
    relationship =
      case Map.get(results, "rel") do
        nil ->
          []

        rel ->
          Map.put(rel, :start_node, bare_struct)
      end

    {preload_node, relationship}
  end

  defp format_result(%{"preload" => preload_node} = results, %{direction: :incoming}, bare_struct) do
    relationship =
      case Map.get(results, "rel") do
        nil ->
          []

        rel ->
          Map.put(rel, :end_node, bare_struct)
      end

    {preload_node, relationship}
  end

  @spec relation_info(Seraph.Repo.queryable(), atom) ::
          [Seraph.Schema.Relationship.Incoming.t() | Seraph.Schema.Relationship.Outgoing.t()]
  defp relation_info(queryable, preload) do
    queryable.__schema__(:relationships)
    |> Enum.reduce([], fn
      {k, inner_list}, rel_list when is_list(inner_list) ->
        l =
          Enum.map(inner_list, fn item ->
            {k, item}
          end)

        rel_list ++ l

      {k, v}, rel_list ->
        [{k, v} | rel_list]
    end)
    |> Enum.filter(fn {k, data} ->
      k == preload || data.field == preload
    end)
    |> Keyword.values()
    |> Enum.map(fn rel_info ->
      cardinality = rel_info.schema.__schema__(:cardinality)[rel_info.direction]
      Map.put(rel_info, :cardinality, cardinality)
    end)
  end

  @spec bare_node_struct(Seraph.Schema.Node.t()) :: Seraph.Schema.Node.t()
  defp bare_node_struct(%{__struct__: queryable} = node_data) do
    bare_props = queryable.__schema__(:properties) ++ [:__id__, :additionalLabels]

    {bare_data, _} = Map.split(node_data, bare_props)

    struct!(queryable, bare_data)
  end

  @spec check_preload_opts(options()) :: :ok
  defp check_preload_opts([]) do
    :ok
  end

  defp check_preload_opts([{:load, load} | rest])
       when load in [:all, :nodes, :relationships] do
    check_preload_opts(rest)
  end

  defp check_preload_opts([{:load, load} | _]) do
    raise ArgumentError,
          "#{inspect(load)} is not a valid value for :load. Valid values are: :all, :nodes, :relationships"
  end

  defp check_preload_opts([{:force, force} | rest]) when is_boolean(force) do
    check_preload_opts(rest)
  end

  defp check_preload_opts([{:force, force} | _]) do
    raise ArgumentError,
          ":force should be a boolean. Receid: #{inspect(force)}."
  end

  defp check_preload_opts([{:limit, limit} | rest])
       when (is_integer(limit) and limit > 0) or limit == :infinity do
    check_preload_opts(rest)
  end

  defp check_preload_opts([{:limit, limit} | _]) do
    raise ArgumentError,
          ":limit should be a non negative integer or :infinity. Receid: #{inspect(limit)}."
  end

  defp check_preload_opts([{invalid_opt, _} | _]) do
    raise ArgumentError, "#{inspect(invalid_opt)} is not a valid option."
  end
end
