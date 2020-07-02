defmodule Seraph.Query.Builder.Set do
  @moduledoc false

  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Entity, Helper, Set}

  defstruct [:expressions]

  @type t :: %__MODULE__{
          expressions: [Entity.Property.t() | Entity.Label.t()]
        }

  @valid_funcs [
    :min,
    :max,
    :count,
    :avg,
    :sum,
    :st_dev,
    :collect,
    :id,
    :labels,
    :type,
    :size,
    :percentile_disc
  ]

  @infix_funcs [
    :+,
    :-,
    :*,
    :/
  ]

  @doc """
  Build Set from ast.
  """
  @impl true
  @spec build(Macro.t(), Macro.Env.t()) :: %{set: Set.t(), params: Keyword.t()}
  def build(ast, env) do
    %{entities: entities, params: params} =
      ast
      |> Enum.map(&build_entity(&1, env))
      |> Enum.reduce(%{entities: [], params: []}, fn entity, data ->
        %{entity: entity, params: new_params} =
          Entity.extract_params(entity, data.params, "set__")

        %{data | entities: [entity | data.entities], params: new_params}
      end)

    %{set: %Set{expressions: entities}, params: params}
  end

  @doc """
  Build Set from a map of properties to set on the given entity.
  """
  @spec build_from_map(map, String.t(), String.t()) :: %{set: Set.t(), params: Keyword.t()}
  def build_from_map(data_to_set, entity_identifier \\ "n", param_prefix \\ "") do
    %{entities: entities, params: params} =
      data_to_set
      |> Enum.map(fn {property_name, property_value} ->
        %Entity.Property{
          entity_identifier: entity_identifier,
          name: property_name,
          value: property_value
        }
      end)
      |> Enum.reduce(%{entities: [], params: []}, fn entity, data ->
        %{entity: entity, params: new_params} =
          Entity.extract_params(entity, data.params, param_prefix <> "set__")

        %{data | entities: [entity | data.entities], params: new_params}
      end)

    %{set: %Set{expressions: entities}, params: params}
  end

  @doc """
  Check Return validity.

  - Entity must have been matched / created before set
  - Property value must be of right type
  """
  @impl true
  @spec check(Set.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%Set{expressions: expressions}, %Seraph.Query{} = query) do
    do_check(expressions, query)
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

  defp do_check(_, _, {:error, _} = error) do
    error
  end

  defp do_check([%Entity.Property{} = property | rest], query, :ok) do
    case Map.fetch(query.identifiers, property.entity_identifier) do
      {:ok, entity_data} ->
        result =
          case Kernel.match?(%Entity.Function{}, property.value) do
            true ->
              do_check([property.value], query, :ok)

            false ->
              value = Keyword.fetch!(query.params, String.to_atom(property.bound_name))
              Helper.check_property(entity_data.queryable, property.name, value)
          end

        do_check(rest, query, result)

      :error ->
        message =
          "[Set] Entity with identifier `#{inspect(property.entity_identifier)}` has not been matched or created."

        {:error, message}
    end
  end

  defp do_check([%Entity.Label{} = label_data | rest], query, :ok) do
    case Map.fetch(query.identifiers, label_data.node_identifier) do
      {:ok, _} ->
        do_check(rest, query, :ok)

      :error ->
        message =
          "[Set] Node with identifier `#{inspect(label_data.node_identifier)}` has not been matched or created."

        {:error, message}
    end
  end

  defp do_check([%Entity.EntityData{} = entity_data | rest], query, :ok) do
    case Map.fetch(query.identifiers, entity_data.entity_identifier) do
      {:ok, entity} ->
        result = Helper.check_property(entity.queryable, entity_data.property, nil, false)
        do_check(rest, query, result)

      :error ->
        message =
          "[Set] Entity with identifier `#{inspect(entity_data.entity_identifier)}` has not been matched or created."

        {:error, message}
    end
  end

  defp do_check([%Entity.Function{args: args} | rest], query, :ok) do
    result = do_check(args, query, :ok)
    do_check(rest, query, result)
  end

  defp do_check([value | rest], query, :ok) when is_bitstring(value) or is_number(value) do
    do_check(rest, query, :ok)
  end

  @spec build_entity(Macro.t(), Macro.Env.t()) :: Entity.Property.t() | Entity.Label.t()
  # Set property value
  # u.uuid = 5
  # u.uuid = ^uuid
  # u.viewCount = u.viewCount + 5
  # u.viewCount = size(collect(p))
  defp build_entity(
         {:=, _, [{{:., _, [{entity_identifier, _, _}, property_name]}, _, _}, new_value]},
         _env
       ) do
    %Entity.Property{
      entity_identifier: Atom.to_string(entity_identifier),
      name: property_name,
      value: build_value(new_value)
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

  # All additional labels removing
  # {u, nil}
  defp build_entity({{_node_identifier, _, _}, nil}, _env) do
    raise "Removing all additional labels is not yet supported"
  end

  @spec build_value(Macro.t()) :: Entity.EntityData | Entity.Function | any
  # Pinned value
  # ^uuid
  defp build_value({:^, _, [{_, _, _} = value]}) do
    value
  end

  # function
  # collect(u)
  # percentile(u.viewCount, 90)
  defp build_value({func, _, raw_args}) when func in @valid_funcs do
    args = Enum.map(raw_args, &build_value/1)

    %Entity.Function{
      name: func,
      args: args
    }
  end

  defp build_value({{:., _, [{entity_identifier, _, _}, property_name]}, _, _}) do
    %Entity.EntityData{
      entity_identifier: Atom.to_string(entity_identifier),
      property: property_name
    }
  end

  defp build_value({infix_func, _, [arg1, arg2]}) when infix_func in @infix_funcs do
    %Entity.Function{
      name: infix_func,
      infix?: true,
      args: [build_value(arg1), build_value(arg2)]
    }
  end

  defp build_value({unknown_func, _, args}) when is_list(args) do
    raise ArgumentError, "Unknown function `#{inspect(unknown_func)}`."
  end

  # Bare value
  # 1
  defp build_value(value) do
    value
  end

  defimpl Seraph.Query.Cypher, for: Set do
    @spec encode(Set.t(), Keyword.t()) :: String.t()
    def encode(%Set{expressions: expressions}, _) do
      expressions_str =
        expressions
        |> Enum.map(&Seraph.Query.Cypher.encode(&1, operation: :set))
        |> Enum.join(", ")

      if String.length(expressions_str) > 0 do
        """
        SET
          #{expressions_str}
        """
      else
        ""
      end
    end
  end
end
