defmodule Seraph.Query.Builder.Return do
  @behaviour Seraph.Query.Operation
  alias Seraph.Query.Builder.Entity
  alias Seraph.Query.Builder.Return
  alias Seraph.Query.Builder.Helper

  defmodule EntityData do
    defstruct [:alias, :entity_identifier, :property]

    @type t :: %__MODULE__{
            alias: atom,
            entity_identifier: String.t(),
            property: nil | atom
          }
  end

  defmodule Data do
    defstruct [:alias, :bound_name, :value]

    @type t :: %__MODULE__{
            alias: atom,
            bound_name: String.t(),
            value: any
          }
  end

  defmodule Function do
    alias Seraph.Query.Builder.Return.Function
    defstruct [:alias, :name, :args]

    @type t :: %__MODULE__{
            alias: atom,
            name: atom,
            args: [EntityData.t() | Entity.t() | Data.t() | Function.t()]
          }

    defimpl Seraph.Query.Cypher, for: Function do
      def encode(%Function{alias: func_alias, name: name, args: args}, opts) do
        name_str =
          if name in [:st_dev, :start_node, :end_node] do
            Inflex.camelize(name, :lower)
          else
            name
            |> Atom.to_string()
            |> String.upcase()
          end

        args_str =
          args
          |> Enum.map(&Seraph.Query.Cypher.encode(&1, opts))
          |> Enum.join(", ")

        func_str = "#{name_str}(#{args_str})"

        case func_alias do
          nil ->
            func_str

          fn_alias ->
            func_str <> " AS #{fn_alias}"
        end
      end
    end
  end

  defmodule Raw do
    defstruct [:variables]

    @type t :: %__MODULE__{
            variables: [EntityData.t() | Data.t() | Function.t()]
          }
  end

  defstruct [:raw_data, :variables, distinct?: false]

  @unary_funcs [
    :min,
    :max,
    :count,
    :avg,
    :sum,
    :st_dev,
    :collect,
    :type,
    :id,
    :labels,
    :type,
    :start_node,
    :end_node
  ]
  @binary_funcs [:percentile_disc]
  @multi_args_func [:distinct]
  @valid_funcs @unary_funcs ++ @binary_funcs ++ @multi_args_func

  @type entities :: EntityData.t() | Data.t() | Function.t()

  @type t :: %__MODULE__{
          distinct?: boolean,
          variables: nil | %{String.t() => Entity.t() | Data.t() | Function.t()},
          raw_data: nil | [EntityData.t() | Data.t() | Function.t()]
        }

  @spec build(Macro.t(), Macro.Env.t()) :: %{return: Return.t(), params: Keyword.t()}
  @impl true
  def build(ast, env) when not is_list(ast) do
    build([ast], env)
  end

  def build(ast, _env) do
    %{variables: raw_variables, params: params} =
      Enum.map(ast, &do_build/1)
      |> List.flatten()
      |> Enum.reduce(%{variables: [], params: []}, &extract_params/2)

    %{return: %Return{variables: nil, raw_data: raw_variables}, params: params}
  end

  @spec do_build(Macro.t()) :: Return.entities()
  # function
  # collect(u)
  # percentile(u.viewCount, 90)
  defp do_build({func, _, raw_args}) when func in @valid_funcs do
    args = Enum.map(raw_args, &do_build/1)

    %Function{
      name: func,
      args: args
    }
  end

  # pinned var
  # ^uuid
  defp do_build({:^, _, [{:uuid, _, nil} = value]}) do
    %Data{
      value: value
    }
  end

  # property
  # u.uuid
  defp do_build({{:., _, [{entity_identifier, _, _}, property]}, _, _}) do
    %EntityData{
      entity_identifier: entity_identifier,
      property: property
    }
  end

  # entity identifier
  # u
  defp do_build({entity_identifier, _, nil}) do
    %EntityData{
      entity_identifier: entity_identifier
    }
  end

  defp do_build({unknown_func, _, args}) when is_list(args) do
    raise ArgumentError, "Unknown function `#{inspect(unknown_func)}`."
  end

  # aliased return
  # [person: u]
  defp do_build(aliases_list) when is_list(aliases_list) do
    Enum.map(aliases_list, fn {return_alias, raw_data} ->
      do_build(raw_data)
      |> Map.put(:alias, return_alias)
    end)
  end

  # aliased return without brackets (due to formatter....)
  # person: u, another: v
  defp do_build({return_alias, raw_data}) when is_atom(return_alias) do
    do_build(raw_data)
    |> Map.put(:alias, return_alias)
  end

  # Bare value
  # 1
  defp do_build(value) do
    %Data{
      value: value
    }
  end

  @spec extract_params(Return.entities(), %{variables: [Return.entities()], params: Keyword.t()}) ::
          %{variables: [Return.entities()], params: Keyword.t()}
  defp extract_params(%EntityData{} = entity_data, %{variables: variables, params: params}) do
    %{variables: [entity_data | variables], params: params}
  end

  defp extract_params(%Data{} = data, return_data) do
    bound_name =
      case data.value do
        {value_name, _, _} ->
          Atom.to_string(value_name)

        _ ->
          index =
            Enum.filter(return_data.params, fn {key, _} ->
              String.starts_with?(Atom.to_string(key), "return__")
            end)
            |> Enum.count()

          "return__" <> Integer.to_string(index)
      end

    new_data =
      data
      |> Map.put(:bound_name, bound_name)
      |> Map.put(:value, nil)

    %{
      return_data
      | variables: [new_data | return_data.variables],
        params: Keyword.put(return_data.params, String.to_atom(bound_name), data.value)
    }
  end

  defp extract_params(%Function{args: inner_data} = data, return_data) do
    %{variables: new_args, params: params} =
      Enum.reduce(inner_data, %{variables: [], params: return_data.params}, &extract_params/2)

    %{
      return_data
      | variables: [Map.put(data, :args, new_args) | return_data.variables],
        params: params
    }
  end

  @spec finalize_variables_build([Return.entities()], Keyword.t()) :: %{
          String.t() => Return.entities()
        }
  def finalize_variables_build(raw_variables, params) do
    Enum.reduce(raw_variables, %{}, fn
      %{alias: data_alias} = data, vars when not is_nil(data_alias) ->
        Map.put(vars, Atom.to_string(data_alias), data)

      %EntityData{entity_identifier: entity_identifier, property: property} = data, vars
      when not is_nil(property) ->
        key = Atom.to_string(entity_identifier) <> "." <> Atom.to_string(property)

        Map.put(vars, key, data)

      %EntityData{entity_identifier: entity_identifier} = data, vars ->
        Map.put(vars, Atom.to_string(entity_identifier), data)

      %Data{bound_name: bound_name}, _ ->
        value = Keyword.fetch!(params, String.to_atom(bound_name))
        raise ArgumentError, "Bare value `#{inspect(value)}` must be aliased."

      %Function{name: name}, _ ->
        raise ArgumentError, "Function `#{inspect(name)}` must be aliased."
    end)
  end

  @impl true
  @spec check(Return.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%Return{raw_data: raw_variables}, query) do
    Enum.reduce_while(raw_variables, :ok, fn
      %EntityData{entity_identifier: entity_identifier, property: property}, _
      when not is_nil(property) ->
        case Map.fetch(query.identifiers, Atom.to_string(entity_identifier)) do
          {:ok, entity_data} ->
            case Helper.check_property(entity_data.queryable, property, nil, false) do
              :ok -> {:cont, :ok}
              error -> {:halt, error}
            end

          :error ->
            message =
              "Return entity with identifier `#{inspect(entity_identifier)}` has not been matched"

            {:halt, {:error, message}}
        end

      %EntityData{entity_identifier: entity_identifier}, _ ->
        case Map.fetch(query.identifiers, Atom.to_string(entity_identifier)) do
          {:ok, _} ->
            {:cont, :ok}

          :error ->
            message =
              "Return entity with identifier `#{inspect(entity_identifier)}` has not been matched"

            {:halt, {:error, message}}
        end

      %Data{alias: nil, bound_name: bound_name}, _ ->
        value = Keyword.fetch!(query.params, String.to_atom(bound_name))
        error = {:error, "Bare value `#{inspect(value)}` must be aliased."}
        {:halt, error}

      %Function{alias: nil, name: name}, _ ->
        error = {:error, "Function `#{inspect(name)}` must be aliased."}
        {:halt, error}

      _, _ ->
        {:cont, :ok}
    end)
  end

  @impl true
  @spec prepare(Return.t(), Seraph.Query.t(), Keyword.t()) :: Return.t()
  def prepare(%Return{raw_data: raw_variables, variables: nil} = return, query, opts) do
    variables =
      raw_variables
      |> build_variables()
      |> Enum.reduce(%{}, fn {key, data}, vars ->
        new_data = replace_return_variable(data, query)
        Map.put(vars, key, new_data)
      end)
      |> manage_relationship_results(Keyword.get(opts, :relationship_result))

    return
    |> Map.put(:raw_data, nil)
    |> Map.put(:variables, variables)
  end

  def build_variables(raw_variables) do
    Enum.reduce(raw_variables, %{}, fn
      %{alias: data_alias} = data, vars when not is_nil(data_alias) ->
        Map.put(vars, Atom.to_string(data_alias), data)

      %EntityData{entity_identifier: entity_identifier, property: property} = data, vars
      when not is_nil(property) ->
        key = Atom.to_string(entity_identifier) <> "." <> Atom.to_string(property)
        Map.put(vars, key, data)

      %EntityData{entity_identifier: entity_identifier} = data, vars ->
        Map.put(vars, Atom.to_string(entity_identifier), data)
    end)
  end

  @spec replace_return_variable(Return.entities(), Seraph.Query.t()) ::
          Entity.Node.t()
          | Entity.Relationship.t()
          | Entity.Property.t()
          | Return.Data.t()
          | Return.Function.t()
  defp replace_return_variable(
         %Return.EntityData{entity_identifier: entity_identifier, property: property} = data,
         query
       )
       when not is_nil(property) do
    entity_data = Map.fetch!(query.identifiers, Atom.to_string(entity_identifier))

    %Entity.Property{
      alias: data.alias,
      entity_identifier: entity_data.identifier,
      entity_queryable: entity_data.queryable,
      name: property
    }
  end

  defp replace_return_variable(
         %Return.EntityData{entity_identifier: entity_identifier} = data,
         query
       ) do
    Map.fetch!(query.identifiers, Atom.to_string(entity_identifier))
    |> Map.put(:alias, data.alias)
  end

  defp replace_return_variable(%Return.Function{args: args} = data, query) do
    replaced_args = Enum.map(args, &replace_return_variable(&1, query))

    %{data | args: replaced_args}
  end

  defp replace_return_variable(%Return.Data{} = data, _) do
    data
  end

  @spec manage_relationship_results(
          %{
            String.t() => Entity.t() | Return.Data.t() | Return.Function.t()
          },
          :full | atom
        ) :: %{
          String.t() => Entity.t() | Return.Data.t() | Return.Function.t()
        }
  defp manage_relationship_results(variables, :full) do
    Enum.reduce(variables, %{}, fn
      {key, %Entity.Relationship{} = relationship}, final_vars ->
        {start_final_vars, start_new_rel} =
          return_data(relationship, :start, final_vars, variables)

        {end_final_vars, end_new_rel} =
          return_data(start_new_rel, :end, start_final_vars, variables)

        Map.put(end_final_vars, key, end_new_rel)

      {key, data}, final_vars ->
        Map.put(final_vars, key, data)
    end)
  end

  defp manage_relationship_results(variables, _) do
    variables
  end

  @spec return_data(
          Entity.Relationship.t(),
          :start | :end,
          %{String.t() => Entity.Relationship.t()},
          %{String.t() => Entity.Relationship.t()}
        ) :: {%{String.t() => Entity.Relationship.t()}, Entity.Relationship.t()}
  defp return_data(relationship, node_type, acc, variables) do
    node_data = Map.get(relationship, node_type)
    %Entity.Node{identifier: node_id, alias: node_alias} = node_data

    case Map.has_key?(variables, node_id) or Map.has_key?(variables, node_alias) do
      false ->
        new_node_alias =
          "__seraph_" <> Atom.to_string(node_type) <> "_" <> relationship.identifier

        func_name = Atom.to_string(node_type) <> "_node"

        new_return_data = %Return.Function{
          alias: new_node_alias,
          name: String.to_atom(func_name),
          args: [
            %Entity.Relationship{
              identifier: relationship.identifier
            }
          ]
        }

        new_node_data = Map.put(node_data, :identifier, new_node_alias)
        new_rel = Map.put(relationship, node_type, new_node_data)

        {Map.put(acc, new_node_alias, new_return_data), new_rel}

      true ->
        {acc, relationship}
    end
  end

  defimpl Seraph.Query.Cypher, for: Return do
    def encode(%Return{variables: variables}, _) do
      variables_str =
        variables
        |> Enum.map(fn {_, data} ->
          Seraph.Query.Cypher.encode(data, operation: :return)
        end)
        |> Enum.join(", ")

      if String.length(variables_str) > 0 do
        """
        RETURN
          #{variables_str}
        """
      end
    end
  end
end
