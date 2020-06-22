defmodule Seraph.Repo.Node.Queryable do
  @moduledoc false
  alias Seraph.Query.Builder

  @spec to_query(Seraph.Repo.queryable(), map | Keyword.t(), atom) :: Seraph.Query.t()
  def to_query(queryable, properties, :match) do
    properties = Enum.into(properties, %{})

    %{entity: node, params: query_params} =
      Builder.Entity.Node.from_queryable(queryable, properties, "match__")

    {_, func_atom, _, _} =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.at(2)

    literal = "#{func_atom}(#{inspect(properties)})"

    %Seraph.Query{
      identifiers: Map.put(%{}, "n", node),
      operations: [
        match: %Builder.Match{
          entities: [node]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :n
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  def to_query(queryable, properties, :create) do
    properties = Enum.into(properties, %{})

    %{entity: node, params: query_params} =
      Builder.Entity.Node.from_queryable(queryable, properties, "create__")

    {_, func_atom, _, _} =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.at(2)

    literal = "#{func_atom}(#{inspect(properties)})"

    %Seraph.Query{
      identifiers: Map.put(%{}, "n", node),
      operations: [
        create: %Builder.Create{
          raw_entities: [node]
        },
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :n
            }
          ]
        }
      ],
      literal: [literal],
      params: query_params
    }
  end

  def to_query(queryable, %Seraph.Changeset{} = changeset, :match_set) do
    entity_variable = "n"

    properties =
      queryable.__schema__(:merge_keys)
      |> Enum.map(fn prop_name ->
        {prop_name, Map.fetch!(changeset.data, prop_name)}
      end)

    %{entity: node, params: match_params} =
      Builder.Entity.Node.from_queryable(queryable, properties, "match_set__")

    {additional_labels, other_changes} = Map.pop(changeset.changes, :additionalLabels, [])

    {to_remove, to_set} = Enum.split_with(other_changes, fn {_, value} -> is_nil(value) end)

    %{set: set, params: set_params} = Builder.Set.build_from_map(to_set)

    labels_to_set = additional_labels -- changeset.data.additionalLabels
    labels_to_remove = changeset.data.additionalLabels -- additional_labels

    final_set =
      if length(labels_to_set) > 0 do
        label_set = %Builder.Entity.Label{
          node_identifier: "n",
          values: labels_to_set
        }

        %{set | expressions: [label_set | set.expressions]}
      else
        set
      end

    remove = Builder.Remove.build_from_map(to_remove)

    final_remove =
      if length(labels_to_remove) > 0 do
        label_remove = %Builder.Entity.Label{
          node_identifier: "n",
          values: labels_to_remove
        }

        %{remove | expressions: [label_remove | remove.expressions]}
      else
        remove
      end

    {_, func_atom, _, _} =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.at(2)

    literal = "#{func_atom}(#{inspect(changeset.changes)})"

    %Seraph.Query{
      identifiers: Map.put(%{}, entity_variable, node),
      operations: [
        match: %Builder.Match{
          entities: [node]
        },
        set: final_set,
        remove: final_remove,
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :n
            }
          ]
        }
      ],
      literal: [literal],
      params: Keyword.merge(match_params, set_params)
    }
  end

  def to_query(
        queryable,
        [merge: merge_data, on_create: on_create_data, on_match: on_match_data],
        :merge
      ) do
    entity_variable = "n"

    %{entity: node, params: merge_params} =
      Builder.Entity.Node.from_queryable(queryable, merge_data, "merge__")

    %{set: on_create_set, params: on_create_params} =
      build_merge_set(on_create_data, entity_variable, "on_create__")

    on_create_set = %Builder.OnCreateSet{expressions: on_create_set.expressions}

    %{set: on_match_set, params: on_match_params} =
      build_merge_set(on_match_data, entity_variable, "on_match__")

    on_match_set = %Builder.OnMatchSet{expressions: on_match_set.expressions}

    params =
      merge_params
      |> Keyword.merge(on_create_params)
      |> Keyword.merge(on_match_params)

    literal_ops =
      [
        on_create: Map.get(on_create_data, :changes),
        on_match: Map.get(on_match_data, :changes)
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
      |> Enum.join("\n")

    literal_merge = "merge(#{queryable},#{inspect(merge_data)}"

    literal =
      if String.length(literal_ops) > 0 do
        "#{literal_merge}, #{literal_ops})"
      else
        "#{literal_merge})"
      end

    %Seraph.Query{
      identifiers: Map.put(%{}, entity_variable, node),
      operations: [
        merge: %Builder.Merge{
          raw_entities: node
        },
        on_create_set: on_create_set,
        on_match_set: on_match_set,
        return: %Builder.Return{
          raw_variables: [
            %Builder.Entity.EntityData{
              entity_identifier: :n
            }
          ]
        }
      ],
      literal: [literal],
      params: params
    }
  end

  def to_query(queryable, data, :delete) do
    entity_variable = "n"

    properties =
      queryable.__schema__(:merge_keys)
      |> Enum.map(fn prop_name ->
        {prop_name, Map.fetch!(data, prop_name)}
      end)

    %{entity: node, params: match_params} =
      Builder.Entity.Node.from_queryable(queryable, properties, "delete__")

    literal = "delete(#{inspect(data)})"

    %Seraph.Query{
      identifiers: Map.put(%{}, entity_variable, node),
      operations: [
        match: %Builder.Match{entities: [node]},
        delete: %Builder.Delete{
          raw_entities: [%Builder.Entity.EntityData{entity_identifier: entity_variable}]
        }
      ],
      literal: [literal],
      params: match_params
    }
  end

  defp build_merge_set(%Seraph.Changeset{} = changeset, entity_variable, param_prefix) do
    {additional_labels, other_changes} = Map.pop(changeset.changes, :additionalLabels, [])

    %{set: set, params: params} =
      Builder.Set.build_from_map(other_changes, entity_variable, param_prefix)

    final_set =
      if length(additional_labels) > 0 do
        label_set = %Builder.Entity.Label{
          node_identifier: "n",
          values: additional_labels
        }

        %{set | expressions: [label_set | set.expressions]}
      else
        set
      end

    %{set: final_set, params: params}
  end

  defp build_merge_set(%{}, _, _) do
    %{set: %{expressions: []}, params: []}
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given identifier value.

  Returns `nil` if no result was found
  """
  @spec get(Seraph.Repo.t(), Seraph.Repo.queryable(), any) :: nil | Seraph.Schema.Node.t()
  def get(repo, queryable, id_value) do
    id_field = Seraph.Repo.Helper.identifier_field!(queryable)

    results =
      queryable
      |> to_query(Map.put(%{}, id_field, id_value), :match)
      |> repo.all()

    case List.first(results) do
      nil ->
        nil

      res ->
        res["n"]
    end
  end

  @doc """
  Same as `get/3` but raises when no result is found.
  """
  @spec get!(Seraph.Repo.t(), Seraph.Repo.queryable(), any) :: Seraph.Schema.Node.t()
  def get!(repo, queryable, id_value) do
    case get(repo, queryable, id_value) do
      nil -> raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: id_value
      result -> result
    end
  end

  @doc """
  Fetch a single struct from the Neo4j datababase with the given data.

  Returns `nil` if no result was found
  """
  @spec get_by(Seraph.Repo.t(), Seraph.Repo.queryable(), Keyword.t() | map) ::
          nil | Seraph.Schema.Node.t()
  def get_by(repo, queryable, clauses) do
    results =
      queryable
      |> to_query(clauses, :match)
      |> repo.all()

    case length(results) do
      0 ->
        nil

      1 ->
        List.first(results)["n"]

      count ->
        raise Seraph.MultipleNodesError, queryable: queryable, count: count, params: clauses
    end
  end

  @doc """
  Same as `get/3` but raises when no result is found.
  """
  @spec get_by!(Seraph.Repo.t(), Seraph.Repo.queryable(), Keyword.t() | map) ::
          Seraph.Schema.Node.t()
  def get_by!(repo, queryable, clauses) do
    case get_by(repo, queryable, clauses) do
      nil -> raise Seraph.NoResultsError, queryable: queryable, function: :get!, params: clauses
      result -> result
    end
  end
end
