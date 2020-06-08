defmodule Seraph.Query.Builder.Return do
  @behaviour Seraph.Query.Operation

  alias Seraph.Query.Builder.{Entity, Helper, Return}

  defstruct [:raw_variables, :variables, distinct?: false]

  @unary_funcs [
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
    :start_node,
    :end_node,
    :size
  ]
  @binary_funcs [:percentile_disc]
  @multi_args_func [:distinct]
  @valid_funcs @unary_funcs ++ @binary_funcs ++ @multi_args_func

  @type entities :: EntityData.t() | Entity.Value.t() | Function.t()

  @type t :: %__MODULE__{
          distinct?: boolean,
          variables: nil | %{String.t() => Entity.t() | Entity.Value.t() | Function.t()},
          raw_variables: nil | [EntityData.t() | Entity.Value.t() | Function.t()]
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
      |> Enum.reduce(%{variables: [], params: []}, fn entity, data ->
        %{entity: new_entity, params: params} =
          Entity.extract_params(entity, data.params, "return__")

        %{data | variables: [new_entity | data.variables], params: params}
      end)

    %{return: %Return{variables: nil, raw_variables: raw_variables}, params: params}
  end

  @spec do_build(Macro.t()) :: Return.entities()
  # function
  # collect(u)
  # percentile(u.viewCount, 90)
  defp do_build({func, _, raw_args}) when func in @valid_funcs do
    args =
      Enum.map(raw_args, fn raw_arg ->
        if Keyword.keyword?(raw_arg) do
          raise ArgumentError, "Aliases are not allowed in function arguments."
        end

        do_build(raw_arg)
      end)

    %Entity.Function{
      name: func,
      args: args
    }
  end

  # pinned var
  # ^uuid
  defp do_build({:^, _, [{_, _, nil} = value]}) do
    %Entity.Value{
      value: value
    }
  end

  # property
  # u.uuid
  defp do_build({{:., _, [{entity_identifier, _, _}, property]}, _, _}) do
    %Entity.EntityData{
      entity_identifier: entity_identifier,
      property: property
    }
  end

  # entity identifier
  # u
  defp do_build({entity_identifier, _, nil}) do
    %Entity.EntityData{
      entity_identifier: entity_identifier
    }
  end

  defp do_build({unknown_func, _, args}) when is_list(args) do
    raise ArgumentError, "Unknown function `#{inspect(unknown_func)}`."
  end

  # aliased return
  # [person: u]
  defp do_build(aliases_list) when is_list(aliases_list) do
    Enum.map(aliases_list, fn {return_alias, raw_variables} ->
      do_build(raw_variables)
      |> Map.put(:alias, return_alias)
    end)
  end

  # aliased return without brackets (due to formatter....)
  # person: u, another: v
  defp do_build({return_alias, raw_variables}) when is_atom(return_alias) do
    do_build(raw_variables)
    |> Map.put(:alias, return_alias)
  end

  # Bare value
  # 1
  defp do_build(value) do
    %Entity.Value{
      value: value
    }
  end

  @spec finalize_variables_build([Return.entities()], Keyword.t()) :: %{
          String.t() => Return.entities()
        }
  def finalize_variables_build(raw_variables, params) do
    Enum.reduce(raw_variables, %{}, fn
      %{alias: data_alias} = data, vars when not is_nil(data_alias) ->
        Map.put(vars, Atom.to_string(data_alias), data)

      %Entity.EntityData{entity_identifier: entity_identifier, property: property} = data, vars
      when not is_nil(property) ->
        key = Atom.to_string(entity_identifier) <> "." <> Atom.to_string(property)

        Map.put(vars, key, data)

      %Entity.EntityData{entity_identifier: entity_identifier} = data, vars ->
        Map.put(vars, Atom.to_string(entity_identifier), data)

      %Entity.Value{bound_name: bound_name}, _ ->
        value = Keyword.fetch!(params, String.to_atom(bound_name))
        raise ArgumentError, "Bare value `#{inspect(value)}` must be aliased."

      %Entity.Function{name: name}, _ ->
        raise ArgumentError, "Function `#{inspect(name)}` must be aliased."
    end)
  end

  @impl true
  @spec check(Return.t(), Seraph.Query.t()) :: :ok | {:error, String.t()}
  def check(%Return{raw_variables: raw_variables}, query) do
    do_check(raw_variables, query)
  end

  @spec do_check([], Seraph.Query.t(), :ok | {:error, String.t()}) :: :ok | {:error, String.t()}
  defp do_check(raw_variables, query, result \\ :ok)

  defp do_check([], _, result) do
    result
  end

  defp do_check(_, _, {:error, _} = error) do
    error
  end

  defp do_check([%Entity.EntityData{property: nil} = entity_data | rest], query, _) do
    case Map.fetch(query.identifiers, Atom.to_string(entity_data.entity_identifier)) do
      {:ok, _} ->
        do_check(rest, query, :ok)

      :error ->
        message =
          "Return entity with identifier `#{inspect(entity_data.entity_identifier)}` has not been matched"

        {:error, message}
    end
  end

  defp do_check([%Entity.EntityData{} = entity_data | rest], query, _) do
    case Map.fetch(query.identifiers, Atom.to_string(entity_data.entity_identifier)) do
      {:ok, entity} ->
        result = Helper.check_property(entity.queryable, entity_data.property, nil, false)
        do_check(rest, query, result)

      :error ->
        message =
          "Return entity with identifier `#{inspect(entity_data.entity_identifier)}` has not been matched"

        {:error, message}
    end
  end

  defp do_check([%Entity.Function{alias: nil, name: name} | _], _, _) do
    {:error, "Function `#{inspect(name)}` must be aliased."}
  end

  defp do_check([%Entity.Value{alias: nil, bound_name: bound_name} | _], query, _) do
    value = Keyword.fetch!(query.params, String.to_atom(bound_name))
    {:error, "Bare value `#{inspect(value)}` must be aliased."}
  end

  defp do_check([_ | rest], query, result) do
    do_check(rest, query, result)
  end

  @impl true
  @spec prepare(Return.t(), Seraph.Query.t(), Keyword.t()) :: Return.t()
  def prepare(%Return{raw_variables: raw_variables, variables: nil} = return, query, opts) do
    variables =
      raw_variables
      |> build_variables()
      |> Enum.reduce(%{}, fn {key, data}, vars ->
        new_data = replace_return_variable(data, query)
        Map.put(vars, key, new_data)
      end)
      |> manage_relationship_results(Keyword.get(opts, :relationship_result))

    new_return =
      return
      |> Map.put(:raw_variables, nil)
      |> Map.put(:variables, variables)

    %{return: new_return}
  end

  def build_variables(raw_variables) do
    Enum.reduce(raw_variables, %{}, fn
      %{alias: data_alias} = data, vars when not is_nil(data_alias) ->
        Map.put(vars, Atom.to_string(data_alias), data)

      %Entity.EntityData{entity_identifier: entity_identifier, property: property} = data, vars
      when not is_nil(property) ->
        key = Atom.to_string(entity_identifier) <> "." <> Atom.to_string(property)
        Map.put(vars, key, data)

      %Entity.EntityData{entity_identifier: entity_identifier} = data, vars ->
        Map.put(vars, Atom.to_string(entity_identifier), data)
    end)
  end

  @spec replace_return_variable(Return.entities(), Seraph.Query.t()) ::
          Entity.Node.t()
          | Entity.Relationship.t()
          | Entity.Property.t()
          | Entity.Value.t()
          | Entity.Function.t()
  defp replace_return_variable(
         %Entity.EntityData{entity_identifier: entity_identifier, property: property} = data,
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
         %Entity.EntityData{entity_identifier: entity_identifier} = data,
         query
       ) do
    Map.fetch!(query.identifiers, Atom.to_string(entity_identifier))
    |> Map.put(:alias, data.alias)
  end

  defp replace_return_variable(%Entity.Function{args: args} = data, query) do
    replaced_args = Enum.map(args, &replace_return_variable(&1, query))

    %{data | args: replaced_args}
  end

  defp replace_return_variable(%Entity.Value{} = data, _) do
    data
  end

  @spec manage_relationship_results(
          %{
            String.t() => Entity.t() | Entity.Value.t() | Entity.Function.t()
          },
          :full | atom
        ) :: %{
          String.t() => Entity.t() | Entity.Value.t() | Entity.Function.t()
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

        new_return_data = %Entity.Function{
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
