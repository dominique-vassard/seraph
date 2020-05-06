defmodule Seraph.Repo do
  @moduledoc """
  See `Seraph.Example.Repo` for common functions.

  See `Seraph.Example.Repo.Node` for node-specific functions.

  See `Seraph.Example.Repo.Relationship` for relationship-specific functions.
  """
  @type t :: module
  @type queryable :: module

  alias Seraph.Query.Builder

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app opts[:otp_app]

      alias Seraph.{Condition, Query}

      @module __MODULE__

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

      def all(query) do
        statement =
          query.operations
          |> Enum.reverse()
          |> Enum.map(&Seraph.Query.Stringifier.stringify/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.join("\n")

        Seraph.Query.Planner.query!(__MODULE__, statement, Enum.into(query.params, %{}))
        |> IO.inspect(label: "RESULTS")
        |> Enum.map(fn results ->
          results
          |> Enum.sort(fn {_, v1}, {_, v2} -> v1 <= v2 end)
          # |> Enum.into(%{})
          |> IO.inspect(label: "SORTED")
          |> Enum.reduce(%{}, fn {key, result}, res ->
            formated_res =
              case Keyword.fetch(query.aliases, String.to_atom(key)) do
                {:ok, {nil, %Seraph.Query.Builder.NodeExpr{} = node_data}} ->
                  IO.inspect(key, label: "KEY")

                  Keyword.fetch(query.aliases, String.to_atom(key))
                  |> IO.inspect(label: "SEARCHED")

                  Seraph.Node.map(result)

                {:ok, {queryable, %Seraph.Query.Builder.NodeExpr{}}} ->
                  Seraph.Repo.Helper.build_node(queryable, result)

                {:ok, {queryable, %Seraph.Query.Builder.RelationshipExpr{} = rel_data}} ->
                  %Builder.NodeExpr{variable: start_var} = rel_data.start
                  %Builder.NodeExpr{variable: end_var} = rel_data.end

                  start_node = res[start_var]
                  end_node = res[end_var]

                  Seraph.Repo.Helper.build_relationship(queryable, result, start_node, end_node)

                :error ->
                  result
              end

            Map.put(res, key, formated_res)
          end)

          # Enum.into(results, %{}, fn {key, result} ->
          #   formated_res =
          #     case Keyword.fetch(query.aliases, String.to_atom(key)) do
          #       {:ok, {nil, %Seraph.Query.Builder.NodeExpr{} = node_data}} ->
          #         Seraph.Node.map(result)

          #       {:ok, {queryable, %Seraph.Query.Builder.NodeExpr{}}} ->
          #         Seraph.Repo.Helper.build_node(queryable, result)

          #       {:ok, {queryable, %Seraph.Query.Builder.RelationshipExpr{} = rel_data}} ->
          #         %Builder.NodeExpr{variable: start_var} = rel_data.start
          #         %Builder.NodeExpr{variable: end_var} = rel_data.end

          #         start_node = results[start_var]
          #         end_node = results[end_var]

          #         Seraph.Repo.Helper.build_relationship(queryable, result, start_node, end_node)

          #       # result_id = result.id

          #       # Enum.find(results, fn
          #       #   {_, %Bolt.Sips.Types.Node{id: id}} when id == result_id ->
          #       #     true

          #       #   {_, %Seraph.Node{__id__: id}} when id == result_id ->
          #       #     true

          #       #   {_, %{__metadata__: %Seraph.Schema.Node.Metadata{}, __id__: id}}
          #       #   when id == result_id ->
          #       #     true

          #       #   d ->
          #       #     IO.inspect(result_id, label: "RESULT ID")
          #       #     IO.inspect(d, label: "DATA")
          #       #     false
          #       # end)
          #       # |> IO.inspect(label: "FOUND")

          #       :error ->
          #         result
          #     end

          #   {key, formated_res}
          # end)
        end)
      end

      use Seraph.Repo.Node.Repo, __MODULE__
      use Seraph.Repo.Relationship.Repo, __MODULE__
    end
  end
end
