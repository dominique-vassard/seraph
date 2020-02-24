defmodule Neo4jex.Repo do
  @type t :: module

  alias Neo4jex.Repo.{Queryable, Schema}

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

      # Planner
      def query(statement, params \\ %{}, opts \\ []) do
        Neo4jex.Query.Planner.query(__MODULE__, statement, params, opts)
      end

      def query!(statement, params \\ %{}, opts \\ []) do
        Neo4jex.Query.Planner.query!(__MODULE__, statement, params, opts)
      end

      def raw_query(statement, params \\ %{}, opts \\ []) do
        Neo4jex.Query.Planner.raw_query(__MODULE__, statement, params, opts)
      end

      def raw_query!(statement, params \\ %{}, opts \\ []) do
        Neo4jex.Query.Planner.raw_query!(__MODULE__, statement, params, opts)
      end

      # Schema
      def create(data) do
        Schema.create(__MODULE__, data)
      end

      def create!(data) do
        Schema.create!(__MODULE__, data)
      end

      # Queryable
      def get(queryable, identifier_value) do
        Queryable.get(__MODULE__, queryable, identifier_value)
      end

      def get!(queryable, identifier_value) do
        Queryable.get!(__MODULE__, queryable, identifier_value)
      end

      def set(queryable, changeset) do
        Queryable.set(__MODULE__, queryable, changeset)
      end

      def set!(queryable, changeset) do
        Queryable.set!(__MODULE__, queryable, changeset)
      end
    end
  end
end
