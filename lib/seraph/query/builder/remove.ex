defmodule Seraph.Query.Builder.Remove do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.Remove
  alias Seraph.Query.Builder.{Entity, Helper}

  defstruct [:expressions]

  @type t :: %__MODULE__{
          expressions: [Entity.Property.t() | Entity.Label.t()]
        }

  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: Remove.t()
  def build(ast, env) do
    %Remove{expressions: Enum.map(ast, &build_entity(&1, env))}
  end

  def build_from_map(data_to_remove, entity_identifier \\ "n") do
    expressions =
      data_to_remove
      |> Enum.map(fn {property_name, _} ->
        %Entity.Property{
          entity_identifier: entity_identifier,
          name: property_name
        }
      end)

    %Remove{expressions: expressions}
  end

  @impl true
  @spec check(Remove.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%Remove{expressions: expressions}, %Seraph.Query{} = query) do
    do_check(expressions, query)
  end

  @spec build_entity(Macro.t(), Macro.Env.t()) :: Entity.Property.t() | Entity.Label.t()
  # Property
  # u.firstName
  defp build_entity({{:., _, [{entity_identifier, _, _}, property_name]}, _, _}, _env) do
    %Entity.Property{
      entity_identifier: Atom.to_string(entity_identifier),
      name: property_name
    }
  end

  # Unique label
  # {u, New}
  defp build_entity({{node_identifier, _, _}, {:__aliases__, _, [new_label]}}, _env) do
    %Entity.Label{
      node_identifier: Atom.to_string(node_identifier),
      values: [Atom.to_string(new_label)]
    }
  end

  # Multiple labels
  # {u, [New, Recurrent]}
  defp build_entity({{node_identifier, _, _}, new_labels}, _env) when is_list(new_labels) do
    labels =
      new_labels
      |> Enum.map(fn {:__aliases__, _, [new_label]} ->
        Atom.to_string(new_label)
      end)

    %Entity.Label{
      node_identifier: Atom.to_string(node_identifier),
      values: labels
    }
  end

  @spec do_check(
          [Entity.Property.t() | Entity.Label.t()],
          Seraph.Query.t(),
          :ok | {:error, String.t()}
        ) :: :ok | {:error, String.t()}
  defp do_check(expressions, query, result \\ :ok)

  defp do_check([], _, result) do
    result
  end

  defp do_check([%Entity.Property{} = property | rest], query, :ok) do
    with {:ok, entity_data} <- Map.fetch(query.identifiers, property.entity_identifier),
         :ok <- Helper.check_property(entity_data.queryable, property.name, nil, false),
         :ok <- do_check_identifier_key(entity_data.queryable, property.name),
         :ok <- do_check_merge_keys(entity_data.queryable, property.name) do
      do_check(rest, query, :ok)
    else
      :error ->
        message =
          "[Remove] Entity with identifier `#{inspect(property.entity_identifier)}` has not been matched or created."

        {:error, message}

      {:error, _} = error ->
        error
    end
  end

  defp do_check([%Entity.Label{} = label_data | rest], query, :ok) do
    with {:ok, entity_data} <- Map.fetch(query.identifiers, label_data.node_identifier),
         :ok <- do_check_primary_label(entity_data.queryable, label_data.values) do
      do_check(rest, query, :ok)
    else
      :error ->
        message =
          "[Remove] Entity with identifier `#{inspect(label_data.node_identifier)}` has not been matched or created."

        {:error, message}

      {:error, _} = error ->
        error
    end
  end

  @spec do_check_primary_label(Seraph.Repo.queryable(), [String.t()]) ::
          :ok | {:error, String.t()}
  defp do_check_primary_label(Seraph.Relationship, _) do
    message =
      "[Remove] Removing relationship type is not allowed. Delete it and create a new one instead."

    {:error, message}
  end

  defp do_check_primary_label(queryable, labels) do
    case queryable.__schema__(:entity_type) do
      :node ->
        primary_label = queryable.__schema__(:primary_label)

        if primary_label in labels do
          message =
            "[Remove] Removing primary label `:#{primary_label}` from Node `#{queryable}` is not allowed."

          {:error, message}
        else
          :ok
        end

      :relationship ->
        message =
          "[Remove] Removing relationship type is not allowed. Delete it and create a new one instead."

        {:error, message}
    end
  end

  @spec do_check_identifier_key(Seraph.Repo.queryable(), atom) ::
          :ok | {:error, String.t()}
  defp do_check_identifier_key(queryable, property_name) do
    case queryable.__schema__(:identifier) do
      {id_field, _, _} ->
        if id_field == property_name do
          message =
            "[Remove] Identifier key `#{property_name}` cannot be removed from `#{queryable}`"

          {:error, message}
        else
          :ok
        end

      false ->
        :ok
    end
  end

  @spec do_check_merge_keys(Seraph.Repo.queryable(), atom) ::
          :ok | {:error, String.t()}
  defp do_check_merge_keys(queryable, property_name) do
    merge_keys = queryable.__schema__(:merge_keys)

    if property_name in merge_keys do
      message = "[Remove] Merge key `#{property_name}` cannot be removed from `#{queryable}`"

      {:error, message}
    else
      :ok
    end
  end

  defimpl Seraph.Query.Cypher, for: Remove do
    @spec encode(Remove.t(), Keyword.t()) :: String.t()
    def encode(%Remove{expressions: expressions}, _) do
      expressions_str =
        expressions
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :remove))
        |> Enum.join(", ")

      if String.length(expressions_str) > 0 do
        """
        REMOVE
          #{expressions_str}
        """
      end
    end
  end
end
