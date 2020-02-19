defmodule Neo4jex.Repo do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app opts[:otp_app]

      alias Neo4jex.{Condition, Query}

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        Neo4jex.Repo.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      def stop(timeout \\ 5000) do
        Supervisor.stop(__MODULE__, :normal, timeout)
      end

      @spec query(String.t(), map, Keyword.t()) :: {:ok, list | map} | {:error, any}
      def query(statement, params \\ %{}, opts \\ []) do
        case raw_query(statement, params, opts) do
          {:ok, results} ->
            {:ok, format_results(results, opts)}

          error ->
            error
        end
      end

      @spec query(String.t(), map, Keyword.t()) :: list | map
      def query!(statement, params \\ %{}, opts \\ []) do
        raw_query!(statement, params, opts)
        |> format_results(opts)
      end

      @doc false
      def raw_query(statement, params \\ %{}, opts \\ []) do
        Bolt.Sips.query(get_conn(opts), statement, params, opts)
      end

      @doc false
      def raw_query!(statement, params \\ %{}, opts \\ []) do
        Bolt.Sips.query!(get_conn(opts), statement, params, opts)
      end

      ## Schema
      @spec create(struct | Neo4jex.Schema.Node.t() | Ecto.Changeset.t()) ::
              {:ok, Neo4jex.Schema.t()} | {:error, Ecto.Changeset.t()}
      def create(%{__struct__: schema, __meta__: %Neo4jex.Schema.Node.Metadata{}} = data) do
        persisted_properties = schema.__schema__(:persisted_properties)

        data =
          case schema.__schema__(:identifier) do
            {:uuid, :string, _} ->
              Map.put(data, :uuid, UUID.uuid4())

            _ ->
              data
          end

        node_to_insert = %Query.NodeExpr{
          labels: [schema.__schema__(:primary_label)] ++ data.additional_labels,
          variable: "n"
        }

        sets =
          data
          |> Map.from_struct()
          |> Enum.filter(fn {k, _} ->
            k in persisted_properties
          end)
          |> Enum.reduce(%{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
            bound_name = node_to_insert.variable <> "_" <> Atom.to_string(prop_name)

            set = %Query.SetExpr{
              field: %Query.FieldExpr{
                variable: node_to_insert.variable,
                name: prop_name
              },
              value: bound_name
            }

            %{
              sets_data
              | sets: [set | sets_data.sets],
                params: Map.put(sets_data.params, String.to_atom(bound_name), prop_value)
            }
          end)

        {cql, params} =
          Query.new()
          |> Query.create([node_to_insert])
          |> Query.set(sets.sets)
          |> Query.return(%Query.ReturnExpr{
            fields: [node_to_insert]
          })
          |> Query.to_string()

        {:ok, %{results: [%{"n" => created_node}], stats: stats}} =
          query(cql, sets.params, with_stats: true)

        {:ok, Map.put(data, :__id__, created_node.id)}
      end

      def create(%Ecto.Changeset{valid?: true} = changeset) do
        changeset
        |> Ecto.Changeset.apply_changes()
        |> create()
      end

      def create(%Ecto.Changeset{valid?: false} = changeset) do
        {:error, changeset}
      end

      def merge(opts) do
        opts
        |> merge_opts([])
        |> do_merge()
      end

      defp do_merge({:error, error}) do
        {:error, error}
      end

      defp do_merge(merge_opts) do
        on_create_changeset = Keyword.get(merge_opts, :on_create)
        on_match_changeset = Keyword.get(merge_opts, :on_match)
        default_changeset = on_create_changeset || on_match_changeset
        schema = extract_schema(on_create_changeset, on_match_changeset)

        identifier =
          if schema.__schema__(:identifier) == false do
            []
          else
            {id, _, _} = schema.__schema__(:identifier)
            [id]
          end

        merge_keys = schema.__schema__(:merge_keys)
        merge_keys_data = merge_keys_data(schema, on_create_changeset, on_match_changeset)

        node_to_merge = %Query.NodeExpr{
          labels: [schema.__schema__(:primary_label)] ++ default_changeset.data.additional_labels,
          variable: "n",
          properties: merge_keys_data
        }

        on_create_label_ops = build_label_ops(node_to_merge, on_create_changeset)
        on_match_label_ops = build_label_ops(node_to_merge, on_match_changeset)

        %{sets: on_create_sets, params: on_create_params} =
          Keyword.get(merge_opts, :on_create, %{})
          |> Map.get(:changes, %{})
          |> Map.drop(identifier ++ merge_keys ++ [:additional_labels])
          |> build_set(node_to_merge)

        %{sets: on_match_sets, params: on_match_params} =
          Keyword.get(merge_opts, :on_match, %{})
          |> Map.get(:changes, %{})
          |> Map.drop(identifier ++ merge_keys ++ [:additional_labels])
          |> build_set(node_to_merge)

        merge = %Query.MergeExpr{
          expr: node_to_merge,
          on_create: on_create_sets,
          on_match: on_match_sets
        }

        no_label_op_query =
          Query.new()
          |> Query.merge([merge])
          # |> Query.label_ops(label_ops)
          |> Query.params(Map.merge(on_create_params, on_match_params))
          |> Query.return(%Query.ReturnExpr{fields: [node_to_merge]})

        query =
          cond do
            is_nil(on_create_changeset) ->
              Query.label_ops(no_label_op_query, on_match_label_ops)

            is_nil(on_match_changeset) ->
              Query.label_ops(no_label_op_query, on_create_label_ops)
          end

        {cql, params} = Query.to_string(query)

        {:ok, %{results: [%{"n" => merged_node}], stats: stats}} =
          query(cql, params, with_stats: true)

        operation = merge_operation(stats)

        result = format_merge_results(merged_node, operation, merge_opts)

        if not is_nil(on_create_changeset) and not is_nil(on_match_changeset) do
          case operation do
            :create ->
              update_labels(on_create_changeset)

            :update ->
              update_labels(on_match_changeset)
          end
        else
          {:ok, result}
        end
      end

      defp merge_opts(
             [
               {:on_create,
                %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
                  changeset}
               | t
             ],
             opts
           ) do
        merge_opts(t, Keyword.put(opts, :on_create, changeset))
      end

      defp merge_opts([{:on_create, changeset} | t], _) do
        {:error, [on_create: changeset]}
      end

      defp merge_opts(
             [
               {:on_match,
                %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
                  changeset}
               | t
             ],
             opts
           ) do
        merge_opts(t, Keyword.put(opts, :on_match, changeset))
      end

      defp merge_opts([{:on_match, changeset} | t], _) do
        {:error, [on_match: changeset]}
      end

      defp merge_opts([], opts), do: opts

      defp extract_schema(%{data: %{__struct__: schema}}, nil) do
        schema
      end

      defp extract_schema(nil, %{data: %{__struct__: schema}}) do
        schema
      end

      defp extract_schema(%{data: %{__struct__: on_create_schema}}, %{
             data: %{__struct__: on_match_schema}
           })
           when on_create_schema == on_match_schema do
        on_create_schema
      end

      defp extract_schema(
             {%{data: %{__struct__: on_create_schema}}, %{data: %{__struct__: on_match_schema}}}
           ) do
        raise ArgumentError,
              ":on_create and :on_match schema should be equivalent. Got create: #{
                inspect(on_create_schema)
              }, on_match: #{inspect(on_create_schema)}"
      end

      defp build_label_ops(node_to_merge, %{changes: %{additional_labels: _}} = changeset) do
        %{__struct__: schema} = changeset.data

        additional_labels =
          changeset.changes[:additional_labels] -- [schema.__schema__(:primary_label)]

        [
          %Query.LabelOperationExpr{
            variable: node_to_merge.variable,
            set: additional_labels -- changeset.data.additional_labels,
            remove: changeset.data.additional_labels -- additional_labels
          }
        ]
      end

      defp build_label_ops(_, _) do
        []
      end

      defp merge_operation(%{"labels-added" => _, "nodes-created" => 1}) do
        :create
      end

      defp merge_operation(%{"properties-set" => _}) do
        :update
      end

      defp merge_operation(%{"labels-added" => _}) do
        :update
      end

      defp merge_operation(_) do
        :none
      end

      defp format_merge_results(merged_node, :create, [{:on_create, changeset} | _]) do
        %{__struct__: schema} = changeset.data

        schema
        |> filled_result_data(merged_node, Ecto.Changeset.apply_changes(changeset))
        |> Map.put(:__id__, merged_node.id)
      end

      defp format_merge_results(merged_node, :update, [{:on_match, changeset} | _]) do
        %{__struct__: schema} = changeset.data
        filled_result_data(schema, merged_node, Ecto.Changeset.apply_changes(changeset))
      end

      defp format_merge_results(_, _, merge_opts) do
        on_create_changeset = Keyword.get(merge_opts, :on_create)
        on_match_changeset = Keyword.get(merge_opts, :on_match)
        changeset = on_create_changeset || on_match_changeset
        changeset.data
      end

      defp filled_result_data(schema, merged_node, applied_changes) do
        schema.__schema__(:properties)
        |> Enum.reduce(applied_changes, fn prop, final_data ->
          if is_nil(Map.get(final_data, prop)) do
            value = Map.get(merged_node.properties, Atom.to_string(prop))
            Map.put(final_data, prop, value)
          else
            final_data
          end
        end)
      end

      defp update_labels(
             %Ecto.Changeset{
               valid?: true,
               changes: %{additional_labels: additional_labels},
               data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}
             } = changeset
           )
           when length(additional_labels) > 0 do
        %{__struct__: schema} = changeset.data

        identifier =
          if schema.__schema__(:identifier) == false do
            []
          else
            {id, _, _} = schema.__schema__(:identifier)
            [id]
          end

        merge_keys = schema.__schema__(:merge_keys)
        merge_keys_data = merge_keys_data(:match, changeset, merge_keys, identifier)

        node_to_merge = %Query.NodeExpr{
          labels: [schema.__schema__(:primary_label)] ++ changeset.data.additional_labels,
          variable: "n",
          properties: merge_keys_data
        }

        merge = %Query.MergeExpr{
          expr: node_to_merge
        }

        additional_labels =
          changeset.changes[:additional_labels] -- [schema.__schema__(:primary_label)]

        label_op = %Query.LabelOperationExpr{
          variable: node_to_merge.variable,
          set: additional_labels -- changeset.data.additional_labels,
          remove: changeset.data.additional_labels -- additional_labels
        }

        {cql, params} =
          Query.new(:update)
          |> Query.merge([merge])
          |> Query.label_ops([label_op])
          |> Query.return(%Query.ReturnExpr{fields: [node_to_merge]})
          |> Query.to_string()

        IO.puts(cql)

        {:ok, %{results: [%{"n" => updated_node}], stats: stats}} =
          query(cql, params, with_stats: true)

        {:ok, Ecto.Changeset.apply_changes(changeset)}
      end

      defp update_labels(
             %Ecto.Changeset{
               valid?: true,
               data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}
             } = changeset
           ) do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      end

      defp update_labels(
             %Ecto.Changeset{
               valid?: false,
               data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}
             } = changeset
           ) do
        {:error, changeset}
      end

      # def merge_create(
      #       %Ecto.Changeset{valid?: true, data: %{__meta__: %Neo4jex.Schema.Node.Metadata{}}} =
      #         changeset
      #     ) do
      #   merge(:create, changeset)
      # end

      # def merge_create(%Ecto.Changeset{valid?: false} = changeset) do
      #   {:error, changeset}
      # end

      def merge_on_create(changeset) do
        merge(on_create: changeset)
      end

      def merge_on_match(changeset) do
        merge(on_match: changeset)
      end

      defp merge_keys_data(:create, changeset, merge_keys, identifier) do
        Enum.map(merge_keys, fn key ->
          if key == :uuid and :uuid in identifier do
            value =
              if is_nil(changeset.data.uuid) do
                UUID.uuid4()
              else
                changeset.data.uuid
              end

            {:uuid, value}
          else
            {key, Map.get(changeset.data, key, Map.fetch!(changeset.changes, key))}
          end
        end)
        |> Enum.into(%{})
      end

      defp merge_keys_data(:match, changeset, merge_keys, _identifier) do
        Enum.map(merge_keys, fn key ->
          {key, Map.fetch!(changeset.data, key)}
        end)
        |> Enum.into(%{})
      end

      defp merge_keys_data(schema, on_create_changeset, nil) do
        identifier =
          if schema.__schema__(:identifier) == false do
            []
          else
            {id, _, _} = schema.__schema__(:identifier)
            [id]
          end

        merge_keys = schema.__schema__(:merge_keys)

        Enum.map(merge_keys, fn key ->
          if key == :uuid and :uuid in identifier do
            value =
              if is_nil(on_create_changeset.data.uuid) do
                UUID.uuid4()
              else
                on_create_changeset.data.uuid
              end

            {:uuid, value}
          else
            {key,
             Map.get(on_create_changeset.data, key, Map.fetch!(on_create_changeset.changes, key))}
          end
        end)
        |> Enum.into(%{})
      end

      defp merge_keys_data(schema, _, on_match_changeset) do
        schema.__schema__(:merge_keys)
        |> Enum.map(fn key ->
          {key, Map.fetch!(on_match_changeset.data, key)}
        end)
        |> Enum.into(%{})
      end

      defp persisted_changes?([]) do
        false
      end

      defp persisted_changes?(stats) do
        stats
        |> Map.values()
        |> Enum.sum()
        |> Kernel.>(0)
      end

      defp build_where_from_merge_keys(node, schema, data) do
        merge_keys = schema.__schema__(:merge_keys)

        Enum.reduce(merge_keys, %{where: nil, params: %{}}, fn property, clauses ->
          value = Map.fetch!(data, property)

          bound_name = node.variable <> "_" <> Atom.to_string(property)

          condition = %Condition{
            source: node.variable,
            field: property,
            operator: :==,
            value: bound_name
          }

          %{
            clauses
            | where: Condition.join_conditions(clauses.where, condition),
              params: Map.put(clauses.params, String.to_atom(bound_name), value)
          }
        end)
      end

      defp build_set(data, entity) do
        Enum.reduce(data, %{sets: [], params: %{}}, fn {prop_name, prop_value}, sets_data ->
          bound_name = entity.variable <> "_" <> Atom.to_string(prop_name)

          set = %Query.SetExpr{
            field: %Query.FieldExpr{
              variable: entity.variable,
              name: prop_name
            },
            value: bound_name
          }

          %{
            sets_data
            | sets: [set | sets_data.sets],
              params: Map.put(sets_data.params, String.to_atom(bound_name), prop_value)
          }
        end)
      end

      defp format_results(results, with_stats: true) do
        %{
          results: results.results,
          stats: results.stats
        }
      end

      defp format_results(results, _opts) do
        results.results
      end

      defp get_conn(opts \\ [])

      defp get_conn(conn: conn) do
        conn
      end

      defp get_conn(role: role) do
        Bolt.Sips.conn(role, prefix: __MODULE__)
      end

      defp get_conn(_) do
        Bolt.Sips.conn(:direct, prefix: __MODULE__)
      end
    end
  end
end
