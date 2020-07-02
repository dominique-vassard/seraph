defmodule Seraph.Query do
  defmodule Change do
    @moduledoc false
    alias Seraph.Query.Builder.Entity
    defstruct [:entity, :change_type]

    @type t :: %__MODULE__{
            entity: Entity.all(),
            change_type: :create | :merge
          }
  end

  alias Seraph.Query.Builder
  defstruct identifiers: %{}, params: [], operations: [], literal: []

  @type operation :: :match | :where | :return

  @type t :: %__MODULE__{
          identifiers: %{String.t() => Builder.Entity.t()},
          params: [{atom, any()}],
          operations: [{operation(), any()}],
          literal: [String.t()]
        }

  defmacro match(expr, match_or_operations_ast \\ :no_op)

  defmacro match(expr, :no_op) do
    do_match(expr, [], __CALLER__, true)
  end

  defmacro match(expr, match_or_operations_ast) do
    do_match(
      expr,
      match_or_operations_ast,
      __CALLER__,
      Keyword.keyword?(match_or_operations_ast)
    )
  end

  defp do_match(expr, operations, env, true) do
    operations = [{:match, expr} | operations]

    query =
      %Seraph.Query{}
      |> Macro.escape()

    query =
      Enum.reduce(operations, query, fn {op, expression}, query ->
        func = "build_" <> Atom.to_string(op)
        Kernel.apply(Seraph.Query, String.to_atom(func), [query, expression, env])
      end)

    quote do
      unquote(query)
    end
  end

  defp do_match(query, expr, env, false) do
    build_match(query, expr, env)
  end

  defmacro create(expr, create_or_operations_ast \\ :no_op)

  defmacro create(expr, :no_op) do
    do_create(expr, [], __CALLER__, true)
  end

  defmacro create(expr, create_or_operations_ast) do
    do_create(
      expr,
      create_or_operations_ast,
      __CALLER__,
      Keyword.keyword?(create_or_operations_ast) or create_or_operations_ast == :no_op
    )
  end

  defp do_create(expr, operations, env, true) do
    operations = [{:create, expr} | operations]

    query =
      %Seraph.Query{}
      |> Macro.escape()

    query =
      Enum.reduce(operations, query, fn {op, expression}, query ->
        func = "build_" <> Atom.to_string(op)
        Kernel.apply(Seraph.Query, String.to_atom(func), [query, expression, env])
      end)

    quote do
      unquote(query)
    end
  end

  defp do_create(query, expr, env, false) do
    build_create(query, expr, env)
  end

  defmacro merge(expr, merge_or_operations_ast \\ :no_op)

  defmacro merge(expr, :no_op) do
    do_merge(expr, [], __CALLER__, true)
  end

  defmacro merge(expr, merge_or_operations_ast) do
    do_merge(
      expr,
      merge_or_operations_ast,
      __CALLER__,
      Keyword.keyword?(merge_or_operations_ast) or merge_or_operations_ast == :no_op
    )
  end

  defp do_merge(expr, operations, env, true) do
    operations = [{:merge, expr} | operations]

    query =
      %Seraph.Query{}
      |> Macro.escape()

    query =
      Enum.reduce(operations, query, fn {op, expression}, query ->
        func = "build_" <> Atom.to_string(op)
        Kernel.apply(Seraph.Query, String.to_atom(func), [query, expression, env])
      end)

    quote do
      unquote(query)
    end
  end

  defp do_merge(query, expr, env, false) do
    build_merge(query, expr, env)
  end

  defmacro where(query, expr) do
    build_where(query, expr, __CALLER__)
  end

  defmacro return(query, expr) do
    build_return(query, expr, __CALLER__)
  end

  defmacro delete(query, expr) do
    build_delete(query, expr, __CALLER__)
  end

  defmacro set(query, expr) do
    build_set(query, expr, __CALLER__)
  end

  defmacro remove(query, expr) do
    build_remove(query, expr, __CALLER__)
  end

  defmacro on_create_set(query, expr) do
    build_on_create_set(query, expr, __CALLER__)
  end

  defmacro on_match_set(query, expr) do
    build_on_match_set(query, expr, __CALLER__)
  end

  defmacro order_by(query, expr) do
    build_order_by(query, expr, __CALLER__)
  end

  defmacro skip(query, expr) do
    build_skip(query, expr, __CALLER__)
  end

  defmacro limit(query, expr) do
    build_limit(query, expr, __CALLER__)
  end

  @doc false
  @spec build_match(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_match(query, expr, env) do
    %{match: match, identifiers: identifiers, params: params} = Builder.Match.build(expr, env)

    match = Macro.escape(match)
    identifiers = Macro.escape(identifiers)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(",\n\t")

    quote bind_quoted: [
            query: query,
            match: match,
            identifiers: identifiers,
            params: params,
            literal: literal
          ] do
      %{
        query
        | identifiers: Map.merge(query.identifiers, identifiers),
          operations: query.operations ++ [match: match],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["match:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_create(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_create(query, expr, env) do
    %{create: create, identifiers: identifiers, params: params} = Builder.Create.build(expr, env)

    create = Macro.escape(create)
    identifiers = Macro.escape(identifiers)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(",\n\t")

    quote bind_quoted: [
            query: query,
            create: create,
            identifiers: identifiers,
            params: params,
            literal: literal
          ] do
      %{
        query
        | # Order is crucial here
          identifiers: Map.merge(identifiers, query.identifiers),
          operations: query.operations ++ [create: create],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["create:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_merge(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_merge(query, expr, env) do
    %{merge: merge, identifiers: identifiers, params: params} = Builder.Merge.build(expr, env)

    merge = Macro.escape(merge)

    identifiers = Macro.escape(identifiers)

    literal = Macro.to_string(expr)

    quote bind_quoted: [
            query: query,
            merge: merge,
            identifiers: identifiers,
            params: params,
            literal: literal
          ] do
      %{
        query
        | # Order is crucial here
          identifiers: Map.merge(identifiers, query.identifiers),
          operations: query.operations ++ [merge: merge],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["merge:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_where(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_where(query, expr, env) do
    %{condition: condition, params: params} = Seraph.Query.Builder.Where.build(expr, env)

    condition = Macro.escape(condition)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            condition: condition,
            params: params,
            literal: literal
          ] do
      %{
        query
        | operations: query.operations ++ [where: condition],
          params: Keyword.merge(query.params, params),
          literal: query.literal ++ ["where:\n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_return(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_return(query, expr, env) when not is_list(expr) do
    build_return(query, [expr], env)
  end

  def build_return(query, expr, env) do
    %{return: return, params: params} = Seraph.Query.Builder.Return.build(expr, env)

    return = Macro.escape(return)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", ")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, literal: literal, return: return, params: params] do
      %{
        query
        | operations: query.operations ++ [return: return],
          literal: query.literal ++ ["return:\n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_delete(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_delete(query, expr, env) do
    delete =
      Seraph.Query.Builder.Delete.build(expr, env)
      |> Macro.escape()

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", ")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, literal: literal, delete: delete] do
      %{
        query
        | operations: query.operations ++ [delete: delete],
          literal: query.literal ++ ["delete:\n" <> literal]
      }
    end
  end

  @doc false
  @spec build_on_create_set(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_on_create_set(query, expr, env) do
    %{on_create_set: on_create_set, params: params} =
      Seraph.Query.Builder.OnCreateSet.build(expr, env)

    on_create_set = Macro.escape(on_create_set)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            on_create_set: on_create_set,
            params: params,
            literal: literal
          ] do
      %{
        query
        | operations: query.operations ++ [on_create_set: on_create_set],
          literal: query.literal ++ ["on_create_set: \n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_on_match_set(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_on_match_set(query, expr, env) do
    %{on_match_set: on_match_set, params: params} =
      Seraph.Query.Builder.OnMatchSet.build(expr, env)

    on_match_set = Macro.escape(on_match_set)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [
            query: query,
            on_match_set: on_match_set,
            params: params,
            literal: literal
          ] do
      %{
        query
        | operations: query.operations ++ [on_match_set: on_match_set],
          literal: query.literal ++ ["on_match_set: \n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_set(Macro.t(), Macro.t(), any) :: Macro.t()
  def build_set(query, expr, env) do
    %{set: set, params: params} = Seraph.Query.Builder.Set.build(expr, env)

    set = Macro.escape(set)

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, set: set, params: params, literal: literal] do
      %{
        query
        | operations: query.operations ++ [set: set],
          literal: query.literal ++ ["set: \n\t" <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_remove(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_remove(query, expr, env) do
    remove =
      Seraph.Query.Builder.Remove.build(expr, env)
      |> Macro.escape()

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, remove: remove, literal: literal] do
      %{
        query
        | operations: query.operations ++ [remove: remove],
          literal: query.literal ++ ["remove: \n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_order_by(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_order_by(query, expr, env) do
    order_by =
      Builder.OrderBy.build(expr, env)
      |> Macro.escape()

    literal =
      expr
      |> Enum.map(&Macro.to_string/1)
      |> Enum.join(", \n\t")
      |> String.replace("()", "")

    quote bind_quoted: [query: query, order_by: order_by, literal: literal] do
      %{
        query
        | operations: query.operations ++ [order_by: order_by],
          literal: query.literal ++ ["order_by: \n\t" <> literal]
      }
    end
  end

  @doc false
  @spec build_skip(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_skip(query, expr, env) do
    %{skip: skip, params: params} = Builder.Skip.build(expr, env)

    skip = Macro.escape(skip)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [query: query, skip: skip, params: params, literal: literal] do
      %{
        query
        | operations: query.operations ++ [skip: skip],
          literal: query.literal ++ ["skip: " <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec build_limit(Macro.t(), Macro.t(), Macro.Env.t()) :: Macro.t()
  def build_limit(query, expr, env) do
    %{limit: limit, params: params} = Builder.Limit.build(expr, env)

    limit = Macro.escape(limit)

    literal =
      expr
      |> Macro.to_string()
      |> String.replace("()", "")

    quote bind_quoted: [query: query, limit: limit, params: params, literal: literal] do
      %{
        query
        | operations: query.operations ++ [limit: limit],
          literal: query.literal ++ ["limit: " <> literal],
          params: Keyword.merge(query.params, params)
      }
    end
  end

  @doc false
  @spec prepare(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  def prepare(query, opts) do
    check(query, opts)

    do_prepare(query, opts)
    |> post_check(opts)
  end

  @spec check(Seraph.Query.t(), Keyword.t()) :: :ok
  defp check(query, _opts) do
    Enum.each(query.operations, fn {operation, operation_data} ->
      mod_name =
        operation
        |> Atom.to_string()
        |> Inflex.camelize()

      module = Module.concat(["Seraph.Query.Builder", mod_name])

      apply(module, :check, [operation_data, query])
      |> raise_if_fail!(query)
    end)
  end

  @spec do_prepare(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  defp do_prepare(query, opts) do
    Enum.reduce(query.operations, query, fn
      {:return, return}, old_query ->
        new_return = Builder.Return.prepare(return, old_query, opts)

        %{
          old_query
          | operations: Keyword.update!(old_query.operations, :return, fn _ -> new_return end)
        }

      {:create, create}, old_query ->
        %{create: new_create, new_identifiers: new_identifiers} =
          Builder.Create.prepare(create, old_query, opts)

        %{
          old_query
          | identifiers: Map.merge(query.identifiers, new_identifiers),
            operations: Keyword.update!(old_query.operations, :create, fn _ -> new_create end)
        }

      {:merge, merge}, old_query ->
        %{merge: new_merge, new_identifiers: new_identifiers} =
          Builder.Merge.prepare(merge, old_query, opts)

        %{
          old_query
          | identifiers: Map.merge(query.identifiers, new_identifiers),
            operations: Keyword.update!(old_query.operations, :merge, fn _ -> new_merge end)
        }

      {:delete, delete}, old_query ->
        new_delete = Builder.Delete.prepare(delete, query, opts)

        %{
          old_query
          | operations: Keyword.update!(old_query.operations, :delete, fn _ -> new_delete end)
        }

      {:order_by, order_by}, old_query ->
        new_order_by = Builder.OrderBy.prepare(order_by, query, opts)

        %{
          old_query
          | operations: Keyword.update!(old_query.operations, :order_by, fn _ -> new_order_by end)
        }

      _, old_query ->
        old_query
    end)
  end

  @spec post_check(Seraph.Query.t(), Keyword.t()) :: Seraph.Query.t()
  defp post_check(%Seraph.Query{} = query, _opts) do
    changes =
      Enum.reduce(query.operations, %{}, fn
        {:create, create_data}, changes ->
          Enum.map(create_data.raw_entities, &extract_changes(&1, :create))
          |> List.flatten()
          |> Enum.reduce(changes, fn data, changes ->
            Map.put(changes, data.identifier, data)
          end)

        {:merge, merge_data}, changes ->
          change = change = extract_changes(merge_data.raw_entities, :create_or_merge)

          if is_list(change) do
            Enum.reduce(change, changes, fn data, changes ->
              Map.put(changes, data.identifier, data)
            end)
          else
            Map.put(changes, change.identifier, change)
          end

        {:set, set_data}, changes ->
          extract_set_changes(set_data, query, changes)

        # {:on_create_set, on_create_set_data}, changes ->
        #   extract_set_changes(on_create_set_data, query, changes)

        {:on_match_set, on_match_set_data}, changes ->
          extract_set_changes(on_match_set_data, query, changes)

        _, changes ->
          changes
      end)

    do_check_changes(Map.values(changes))
    |> raise_if_fail!(query)
  end

  defp extract_changes(%Builder.Entity.Node{} = entity, change_type) do
    changed_props =
      case change_type do
        :create_or_merge ->
          []

        _ ->
          Enum.map(entity.properties, fn %Builder.Entity.Property{name: prop_name} ->
            prop_name
          end)
      end

    %{
      identifier: entity.identifier,
      queryable: entity.queryable,
      changed_properties: changed_props,
      change_type: change_type
    }
  end

  defp extract_changes(
         %Builder.Entity.Relationship{start: start_node, end: end_node},
         change_type
       ) do
    start_data = extract_changes(start_node, change_type)
    end_data = extract_changes(end_node, change_type)
    [start_data, end_data]
  end

  defp extract_set_changes(set_data, query, changes) do
    Enum.reduce(set_data.expressions, changes, fn
      %Builder.Entity.Property{} = property, changes ->
        case Map.fetch(changes, property.entity_identifier) do
          {:ok, change} ->
            entity = Map.fetch!(query.identifiers, property.entity_identifier)

            if entity.queryable.__schema__(:entity_type) == :node do
              new_props = [property.name | change.changed_properties]
              # new_change = Map.put(change, :changed_properties, new_props)
              new_change_type =
                case change.change_type do
                  :create_or_merge ->
                    # if Kernel.match?(%Builder.OnCreateSet{}, set_data) do
                    #   :create
                    # else
                    #   :merge
                    # end

                    if Kernel.match?(%Builder.OnMatchSet{}, set_data) do
                      :merge
                    else
                      :create_or_merge
                    end

                  c_type ->
                    c_type
                end

              new_change = %{change | changed_properties: new_props, change_type: new_change_type}

              Map.put(changes, property.entity_identifier, new_change)
            else
              changes
            end

          :error ->
            entity = Map.fetch!(query.identifiers, property.entity_identifier)

            if entity.queryable.__schema__(:entity_type) == :node do
              new_change = %{
                identifier: property.entity_identifier,
                queryable: entity.queryable,
                changed_properties: [property.name],
                change_type: :merge
              }

              Map.put(changes, property.entity_identifier, new_change)
            else
              changes
            end
        end

      _, changes ->
        changes
    end)
  end

  defp do_check_changes(changes, result \\ :ok)

  defp do_check_changes([], result) do
    result
  end

  defp do_check_changes(_, {:error, _} = error) do
    error
  end

  defp do_check_changes([%{queryable: Seraph.Node, changed_properties: []} | rest], :ok) do
    do_check_changes(rest, :ok)
  end

  defp do_check_changes([change | rest], :ok) do
    %{queryable: queryable, changed_properties: changed_properties} = change

    result =
      case change.change_type do
        :create ->
          do_check_id_field(change)

        # It is not possible to know if merge will be a create or a merge...
        :create_or_merge ->
          :ok

        # do_check_id_field(change)

        :merge ->
          id_field = Seraph.Repo.Helper.identifier_field!(queryable)

          case id_field in changed_properties do
            true ->
              message =
                "[MERGE/SET] Identifier field `#{id_field}` must NOT be changed on Node `#{
                  change.identifier
                }` for `#{queryable}`"

              {:error, message}

            false ->
              merge_keys = queryable.__schema__(:merge_keys)

              case changed_properties -- merge_keys do
                ^changed_properties ->
                  :ok

                _ ->
                  message =
                    "[MERGE/SET] Merge keys `#{inspect(merge_keys)} should not be changed on Node `#{
                      change.identifier
                    }` for `#{queryable}`"

                  {:error, message}
              end
          end
      end

    do_check_changes(rest, result)
  end

  defp do_check_id_field(change) do
    case change.queryable.__schema__(:identifier) do
      {id_field, _, _} ->
        case id_field in change.changed_properties do
          true ->
            :ok

          false ->
            message =
              "[CREATE / MERGE] Identifier field `#{id_field}` must be set on Node `#{
                change.identifier
              }` for `#{change.queryable}`"

            {:error, message}
        end

      false ->
        :ok
    end
  end

  defp raise_if_fail!(:ok, query) do
    query
  end

  defp raise_if_fail!({:error, message}, query) do
    raise Seraph.QueryError, message: message, query: query.literal
  end
end
