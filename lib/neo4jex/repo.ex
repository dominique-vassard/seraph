defmodule Neo4jex.Repo do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app opts[:otp_app]

      alias Neo4jex.Query

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
        case Bolt.Sips.query(get_conn(opts), statement, params) do
          {:ok, results} ->
            case Keyword.get(opts, :with_stats, false) do
              true ->
                {:ok,
                 %{
                   results: results.results,
                   stats: results.stats
                 }}

              false ->
                {:ok, results.results}
            end

          error ->
            error
        end
      end

      @spec query(String.t(), map, Keyword.t()) :: list | map
      def query!(statement, params \\ %{}, opts \\ []) do
        case query(statement, params, opts) do
          {:ok, results} -> results
          {:error, error} -> raise error
        end
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

        node_to_insert = %Query.NodeExpr{
          labels: [schema.__schema__(:primary_label)],
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
