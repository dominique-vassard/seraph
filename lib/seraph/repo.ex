defmodule Seraph.Repo do
  @moduledoc """
  See `Seraph.Example.Repo` for common functions.

  See `Seraph.Example.Repo.Node` for node-specific functions.

  See `Seraph.Example.Repo.Relationship` for relationship-specific functions.
  """
  @type t :: module
  @type queryable :: module
  # other values :no_nodes, :full

  alias Seraph.Query.Builder

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app opts[:otp_app]

      alias Seraph.{Condition, Query}

      @module __MODULE__
      @relationship_result :contextual
      @default_opts [relationship_result: @relationship_result]

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc false
      def start_link(opts \\ []) do
        Seraph.Repo.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      @doc false
      def stop(timeout \\ 5000) do
        Supervisor.stop(__MODULE__, :normal, timeout)
      end

      # Planner
      @doc """
      Execute the given statement with the given params.
      Return the query result or an error.

      Options:
        * `with_stats` - If set to `true`, also returns the query stats
        (number of created nodes, created properties, etc.)

      ## Example

          # Without params
          iex> MyRepo.query("CREATE (p:Person {name: 'Collin Chou', role: 'Seraph'}) RETURN p")
          {:ok,
          [
            %{
              "p" => %Bolt.Sips.Types.Node{
                id: 1813,
                labels: ["Person"],
                properties: %{"name" => "Collin Chou", "role" => "Seraph"}
              }
            }
          ]}

          # With params
          iex(15)> MyRepo.query("MATCH (p:Person {name: $name}) RETURN p.role", %{name: "Collin Chou"})
          {:ok, [%{"p.role" => "Seraph"}]}

          # With :with_stats option
          iex(16)> MyRepo.query("MATCH (p:Person {name: $name}) DETACH DELETE p", %{name: "Collin Chou"}, with_stats: true)
          {:ok, %{results: [], stats: %{"nodes-deleted" => 1}}}
      """
      @spec query(String.t(), map, Keyword.t()) ::
              {:ok, [map] | %{results: [map], stats: map}} | {:error, any}
      def query(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.query(__MODULE__, statement, params, opts)
      end

      @doc """
      Same as `query/3` but raise i ncase of error.
      """
      @spec query!(String.t(), map, Keyword.t()) :: [map] | %{results: [map], stats: map}
      def query!(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.query!(__MODULE__, statement, params, opts)
      end

      @doc false
      def raw_query(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.raw_query(__MODULE__, statement, params, opts)
      end

      @doc false
      def raw_query!(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.raw_query!(__MODULE__, statement, params, opts)
      end

      def all(query, opts \\ []) do
        do_all(query, manage_opts(opts))
      end

      defp do_all(query, {:error, error}) do
        raise ArgumentError, error
      end

      defp do_all(query, opts) do
        query = Seraph.Query.prepare(query, opts)

        statement =
          query.operations
          |> Enum.map(fn {_op, operation_data} ->
            Seraph.Query.Cypher.encode(operation_data)
          end)
          |> Enum.join("\n")

        Seraph.Query.Planner.query!(__MODULE__, statement, Enum.into(query.params, %{}))
        |> format_results(query, opts)
      end

      defp format_results(results, query, opts, formated \\ [])

      defp format_results([], _, _, formated) do
        formated
      end

      defp format_results([result | t], query, opts, formated) do
        formated_res =
          Enum.map(result, &format_result(&1, query, result, opts))
          |> Enum.reduce(%{}, &Map.merge/2)

        format_results(t, query, opts, formated ++ [formated_res])
      end

      defp format_result({result_alias, result}, query, results, opts) do
        formated =
          case Map.fetch(query.operations[:return].variables, result_alias) do
            {:ok, %Builder.Entity.Node{queryable: queryable}} ->
              Seraph.Repo.Helper.build_node(queryable, result)

            {:ok, %Builder.Entity.Relationship{queryable: queryable} = rel_data} ->
              %Builder.Entity.Node{identifier: start_id, alias: start_alias} = rel_data.start
              %Builder.Entity.Node{identifier: end_id, alias: end_alias} = rel_data.end

              relationship_result = Keyword.get(opts, :relationship_result, @relationship_result)

              {start_node, end_node} =
                case relationship_result do
                  :no_nodes ->
                    {nil, nil}

                  _ ->
                    {results[start_alias] || results[start_id],
                     results[end_alias] || results[end_id]}
                end

              Seraph.Repo.Helper.build_relationship(
                queryable,
                result,
                rel_data.start.queryable,
                start_node,
                rel_data.end.queryable,
                end_node
              )

            {:ok, %Builder.Return.Function{}} ->
              result

            :error ->
              result
          end

        if String.starts_with?(result_alias, "__seraph_") do
          %{}
        else
          Map.put(%{}, result_alias, formated)
        end
      end

      defp manage_opts(opts, final_opts \\ @default_opts)

      defp manage_opts([], final_opts) do
        final_opts
      end

      defp manage_opts([{:relationship_result, relationship_result} | t], final_opts) do
        valid_values = [:full, :no_nodes, :contextual]

        if relationship_result in valid_values do
          Keyword.put(final_opts, :relationship_result, relationship_result)
        else
          {:error,
           "Invalid value for options :relationshp_result. Valid values: #{inspect(valid_values)}."}
        end
      end

      defp manage_opts([{invalid_opt, _} | _], _opts) do
        {:error, "#{inspect(invalid_opt)} is not a valid option."}
      end

      use Seraph.Repo.Node.Repo, __MODULE__
      use Seraph.Repo.Relationship.Repo, __MODULE__
    end
  end
end
