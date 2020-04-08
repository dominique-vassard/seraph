defmodule Seraph.Repo do
  @moduledoc """
  Available functions:
    - query/1, query/2, query/3
    - query!/1, query!/2, query!/3
    - raw_query/1, raw_query/2, raw_query/3
    - raw_query!/1, raw_query!/2, raw_query!/3
    - create/1
    - create!/1
    - delete/1
    - delete!/1
    - get/2
    - get!/2
    - set/1
    - set!/1
  """
  @type t :: module

  alias Seraph.Repo.{Queryable, Schema}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app opts[:otp_app]

      alias Seraph.{Condition, Query}

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        Seraph.Repo.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      def stop(timeout \\ 5000) do
        Supervisor.stop(__MODULE__, :normal, timeout)
      end

      # Planner
      def query(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.query(__MODULE__, statement, params, opts)
      end

      def query!(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.query!(__MODULE__, statement, params, opts)
      end

      def raw_query(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.raw_query(__MODULE__, statement, params, opts)
      end

      def raw_query!(statement, params \\ %{}, opts \\ []) do
        Seraph.Query.Planner.raw_query!(__MODULE__, statement, params, opts)
      end

      # Schema
      def create(data, opts \\ []) do
        Schema.create(__MODULE__, data, opts)
      end

      def create!(data, opts \\ []) do
        Schema.create!(__MODULE__, data, opts)
      end

      def merge(struct_or_changeset, opts \\ []) do
        Schema.merge(__MODULE__, struct_or_changeset, opts)
      end

      def merge(queryable, merge_keys_data, opts) do
        Schema.merge(__MODULE__, queryable, merge_keys_data, opts)
      end

      def merge!(struct_or_changeset, opts \\ []) do
        Schema.merge!(__MODULE__, struct_or_changeset, opts)
      end

      def merge!(queryable, merge_keys_data, opts) do
        Schema.merge!(__MODULE__, queryable, merge_keys_data, opts)
      end

      def set(changeset, opts \\ []) do
        Schema.set(__MODULE__, changeset, opts)
      end

      def set!(changeset, opts \\ []) do
        Schema.set!(__MODULE__, changeset, opts)
      end

      def delete(struct_or_changeset) do
        Schema.delete(__MODULE__, struct_or_changeset)
      end

      def delete!(struct_or_changeset) do
        Schema.delete!(__MODULE__, struct_or_changeset)
      end

      # Queryable
      def get(queryable, identifier_value) do
        Queryable.get(__MODULE__, queryable, identifier_value)
      end

      def get(queryable, start_struct_or_data, end_struct_or_data) do
        Queryable.get(__MODULE__, queryable, start_struct_or_data, end_struct_or_data)
      end

      def get!(queryable, identifier_value) do
        Queryable.get!(__MODULE__, queryable, identifier_value)
      end

      def get!(queryable, start_struct_or_data, end_struct_or_data) do
        Queryable.get!(__MODULE__, queryable, start_struct_or_data, end_struct_or_data)
      end
    end
  end
end
