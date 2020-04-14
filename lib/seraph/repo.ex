defmodule Seraph.Repo do
  @moduledoc """
  See `Seraph.Example.Repo` for available functions.
  """
  @type t :: module

  alias Seraph.Repo.{Queryable, Schema}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app opts[:otp_app]

      alias Seraph.{Condition, Query}

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
      @spec query(String.t(), map, Keyword.t()) :: [map] | %{results: [map], stats: map}
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

      # Schema
      @doc """
      Create a Node or a Relationship defined via `Seraph.Schema.Node`,
      `Seraph.Schema.Relationship` or a changeset.

      It returns `{:ok, struct}` if the struct has been successfully
      created or `{:error, changeset}` if there was a validation error.

      Options (relationship only):
        * `node_creation`: if set to `true`, :start_node and :end_node will be created before
        relationship is.

      ## Example

          # Node
          case MyRepo.create(%Person{name: "Collin Chou", role: "Seraph"}) do
            {:ok, struct} -> # succesful creation
            {:ok, changeset} -> # invalid changeset
          end

          # Relationship
          # with existing nodes
          person = MyRepo.get!(Person, 42)
          movie = MyRepo.get!(Movie, 1)
          new_rel = %ActedIn{
            start_node: person,
            end_node: movie,
            year: 2003
          }
          case MyRepo.create(new_rel) do
            {:ok, struct} -> # succesful creation
            {:ok, changeset} -> # invalid changeset
          end

          # with new nodes
          person = %Person{name: "Collin Chou", role: "Seraph"}
          movie = %Movie{title: "Matrix Reloaded"}
          new_rel = %ActedIn{
            start_node: person,
            end_node: movie,
            year: 2003
          }
          case MyRepo.create(new_rel, node_creation: true) do
            {:ok, struct} -> # succesful creation
            {:ok, changeset} -> # invalid changeset
          end
      """
      @spec create(
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | Seraph.Changeset.t(),
              Keyword.t()
            ) ::
              {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
              | {:error, Seraph.Changeset.t()}
      def create(struct_or_changeset, opts \\ []) do
        Schema.create(__MODULE__, struct_or_changeset, opts)
      end

      @doc """
      Same as `create/2` but raise if changeset is invalid.
      """
      @spec create!(
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | Seraph.Changeset.t(),
              Keyword.t()
            ) ::
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
      def create!(struct_or_changeset, opts \\ []) do
        Schema.create!(__MODULE__, struct_or_changeset, opts)
      end

      @doc """
      Create new Node/Relationship or set new data to it.

      # Node
      if merge keys are present and not nil in given struct or changeset -> set new data
      otherwise -> create a new Node

      # Relationship
      if :start_node and :end_node can be found (based on their merge keys) -> set new data
      otherwise ->  crete a new Relationship

      Options (relationship only):
        * `node_creation`: if set to `true`, :start_node and :end_node will be created before
        relationship is.

      ## Example

      result =
        case MyRepo.get(Person, id) do
          nil  -> %Person{id: id}   # Person not found, we build one
          person -> person          # Person exists, let's use it
        end
        |> Person.changeset(changes)
        |> MyRepo.merge

      case result do
        {:ok, struct}       -> # Merged with success
        {:error, changeset} -> # Something went wrong
      end
      """
      @spec merge(
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | Seraph.Changeset.t(),
              Keyword.t()
            ) ::
              {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
              | {:error, Seraph.Changeset.t()}
      def merge(struct_or_changeset, opts \\ []) do
        Schema.merge(__MODULE__, struct_or_changeset, opts)
      end

      @doc """
      Same as merge/2 but raise in case of error
      """
      @spec merge!(
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | Seraph.Changeset.t(),
              Keyword.t()
            ) ::
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
      def merge!(struct_or_changeset, opts \\ []) do
        Schema.merge!(__MODULE__, struct_or_changeset, opts)
      end

      @doc """
      This function is the equivalent to `MERGE ... ON CREATE SET... ON MATCH SET...`.

      It requires:
        * `queryable` - The queryable to merge
        * `merge_keys_data_or_start_end_data`:
          - for Node: a map with the merge keys data to used to match the node
          - for Realtionship: a map with the `:start_node` and `:end_node` data
        * `opts` - at least one of these three options must be present:
          - `:on_create`: a tuple `{data, changeset_fn}` with the data to set on entity if it's created.
          Given data will be validated through given `changeset_fn`.
          - `:on_match`: a tuple `{data, changeset_fn}` with the data to set on entity if it already exists
          and is matched. Given data will be validated through given `changeset_fn`
          - `:no_data` a boolean. Set to true allow to not provide `:on_match` nor `:on_create` and add
          no properties if entity is created / updated. Useful for Node / Relationsship without properties.

      It returns `{:ok, struct}` if the struct has been successfully
      merged or `{:error, changeset}` if there was a validation error.

      ## Examples

          # Node creation
          result = MyRepo.merge(Person, %{},
                                on_create: {%{name: "Collin Chou", role: "Seraph"}, &Person.changeset/2})
          case result do
            {:ok, struct}       -> # Merged with success
            {:error, changeset} -> # Something went wrong
          end

          # Node update
          person = MyRepo.get!(Person)
          result = MyRepo.merge(Person, %{},
                                on_match: {%{role: "anoter roleSeraph}, &Person.changeset/2})
          case result do
            {:ok, struct}       -> # Merged with success
            {:error, changeset} -> # Something went wrong
          end

          # Both depending on wether the node is found or not
          result = MyRepo.merge(Person, %{},
                                on_create: {%{name: "Collin Chou", role: "Seraph"}, &Person.changeset/2}
                                on_match: {%{role: "Another role}, &Person.role_changeset/2})
          case result do
            {:ok, struct}       -> # Merged with success
            {:error, changeset} -> # Something went wrong
          end

          # Relationship creation
          result = MyRepo.merge(Acted, %{start_node: person, end_node: movie},
                                on_create: {%{year: 2003}, &Person.changeset/2})
          case result do
            {:ok, struct}       -> # Merged with success
            {:error, changeset} -> # Something went wrong
          end

          # Relationship update
          result = MyRepo.merge(Acted, %{start_node: person, end_node: movie},
                                on_match: {%{views: 2}, &Person.views_changeset/2})
          case result do
            {:ok, struct}       -> # Merged with success
            {:error, changeset} -> # Something went wrong
          end

          # Both depending on wether the node is found or not
          result = MyRepo.merge(Acted, %{start_node: person, end_node: movie},
                                on_create: {%{year: 2003}, &Person.changeset/2},
                                on_match: {%{views: 2}, &Person.views_changeset/2})
          case result do
            {:ok, struct}       -> # Merged with success
            {:error, changeset} -> # Something went wrong
          end
      """
      @spec merge(Seraph.Repo.Queryable.t(), map, Keyword.t()) ::
              {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
              | {:error, Seraph.Changeset.t()}
      def merge(queryable, merge_keys_data_or_start_end_data, opts) do
        Schema.merge(__MODULE__, queryable, merge_keys_data_or_start_end_data, opts)
      end

      @doc """
      Same as merge/3 but raise in case of error
      """
      @spec merge(Seraph.Repo.Queryable.t(), map, Keyword.t()) ::
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
      def merge!(queryable, merge_keys_data_or_start_end_data, opts) do
        Schema.merge!(__MODULE__, queryable, merge_keys_data_or_start_end_data, opts)
      end

      @doc """
      Updates a changeset using its merge keys (Node) or its :end_node and :start_node
      (relationship).

      # Relationship
      This functino allows to set new relationship data, but also to set new :start_node
      and :end_node

      It returns `{:ok, struct}` if the struct has been successfully
      updated or `{:error, changeset}` if there was a validation error.

      ## Example

          # Node
          person = MyRepo.get!(Person, 42)
          person = Seraph.Changeset.change(person, %{role: "Not Seraph"})
          case MyRepo.update(person) do
            {:ok, struct}       -> # Updated with success
            {:error, changeset} -> # Something went wrong
          end

          # Relationship
          rel_acted_in = MyRepo.get!(ActedIn, %Person{name: "Collin Chou}, %Movie{title: "Matrix"})

          # Set new data
          rel_acted_in = Seraph.Changeset.change(rel_acted_in, %{year: 2003})

          #Set new :end_node
          new_movie = Repo.get!(Movie, 55)
          rel_acted_in = Seraph.Changeset.change(rel_acted_in, %{end_node: new_movie})

      """
      @spec set(Seraph.Changeset.t(), Keyword.t()) ::
              {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
              | {:error, Seraph.Changeset.t()}
      def set(changeset, opts \\ []) do
        Schema.set(__MODULE__, changeset, opts)
      end

      @doc """
      Same as set/2 but raise in case of error
      """
      @spec set!(Seraph.Changeset.t(), Keyword.t()) ::
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
      def set!(changeset, opts \\ []) do
        Schema.set!(__MODULE__, changeset, opts)
      end

      @doc """
      Deletes a Node struct using its merge keys / a Relationship struct using its `:start_node` and `:end_node`.

      It returns `{:ok, struct}` if the struct has been successfully
      deleted or `{:error, changeset}` if there was a validation error.

      ## Example

      person = MyRepo.get!(Person, 42)
      case MyRepo.delete(person) do
        {:ok, struct}       -> # Deleted with success
        {:error, changeset} -> # Something went wrong
      end
      """
      @spec delete(Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | Seraph.Changeset.t()) ::
              {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
              | {:error, Seraph.Changeset.t()}
      def delete(struct_or_changeset) do
        Schema.delete(__MODULE__, struct_or_changeset)
      end

      @doc """
      Same as `delete/1` but raise in case of error.
      """
      @spec delete!(
              Seraph.Schema.Node.t()
              | Seraph.Schema.Relationship.t()
              | Seraph.Changeset.t()
            ) ::
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
      def delete!(struct_or_changeset) do
        Schema.delete!(__MODULE__, struct_or_changeset)
      end

      # Queryable
      @doc """
      Fetches a single Node struct from the data store where the identifier key matches the given
      identifier value.

      Returns `nil` if no result was found.

      ## Example

          MyRepo.get(Person, 42)
      """
      @spec get(Seraph.Repo.Queryable.t(), any) ::
              nil | Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
      def get(queryable, identifier_value) do
        Queryable.get(__MODULE__, queryable, identifier_value)
      end

      @doc """
      Same as get/2 but raise if more than Node is found.
      """
      @spec get!(Seraph.Repo.Queryable.t(), any) ::
              Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
      def get!(queryable, identifier_value) do
        Queryable.get!(__MODULE__, queryable, identifier_value)
      end

      @doc """
      Fetches a single Relationship struct from the data store where the :start_node and :end_node
      matches the given struct or data.
      The identifier of the Nodes will be used to match them, then this data must be present in
      the given data.

      If only data is given, a struct will be built based on the :start_node / :end_node defined
      in relationship schema.

      Returns `nil` if no result was found.

      ## Example

          # Only with structs
          MyRepo.get!(ActedIn, %Person{name: "Collin Chou}, %Movie{title: "Matrix"})

          # With struct and data mixed
          MyRepo.get!(ActedIn, %Person{name: "Collin Chou}, %{title: "Matrix"})

          # Only with data
          MyRepo.get!(ActedIn, %{name: "Collin Chou}, %{title: "Matrix"})
      """
      def get(queryable, start_struct_or_data, end_struct_or_data) do
        Queryable.get(__MODULE__, queryable, start_struct_or_data, end_struct_or_data)
      end

      @doc """
      Same ass get/3 but raise an error if more than one relationship is found
      """
      def get!(queryable, start_struct_or_data, end_struct_or_data) do
        Queryable.get!(__MODULE__, queryable, start_struct_or_data, end_struct_or_data)
      end
    end
  end
end
