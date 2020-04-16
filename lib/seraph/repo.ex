defmodule Seraph.Repo do
  @moduledoc """
  See `Seraph.Example.Repo` for common functions.

  See `Seraph.Example.Repo.Node` for node-specific functions.

  See `Seraph.Example.Repo.Relationship` for relationship-specific functions.
  """
  @type t :: module
  @type queryable :: module

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

      defmodule Node do
        alias Seraph.Repo.Node

        Module.put_attribute(
          __MODULE__,
          :repo,
          __MODULE__ |> Module.split() |> Enum.reject(&(&1 == "Node")) |> Module.concat()
        )

        @doc """
        Create a Node defined via `Seraph.Schema.Node` or a changeset.

        It returns `{:ok, struct}` if the struct has been successfully
        created or `{:error, changeset}` if there was a validation error.

        ## Example

            case MyRepo.Node.create(%Person{name: "Collin Chou", role: "Seraph"}) do
              {:ok, struct} -> # succesful creation
              {:ok, changeset} -> # invalid changeset
            end
        """
        def create(struct_or_changeset, opts \\ []) do
          Node.Schema.create(@repo, struct_or_changeset, opts)
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
          Node.Schema.create!(@repo, struct_or_changeset, opts)
        end

        @doc """
        Fetches a single Node struct from the data store where the identifier key matches the given
        identifier value.

        Returns `nil` if no result was found.

        ## Example

            MyRepo.Node.get(Person, 42)
        """
        @spec get(Seraph.Repo.Queryable.t(), any) ::
                nil | Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
        def get(queryable, identifier_value) do
          Node.Queryable.get(@repo, queryable, identifier_value)
        end

        @doc """
        Same as get/2 but raise if more than Node is found.
        """
        @spec get!(Seraph.Repo.Queryable.t(), any) ::
                Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
        def get!(queryable, identifier_value) do
          Node.Queryable.get!(@repo, queryable, identifier_value)
        end

        @doc """
        Create new Node or set new data to it.

        If merge keys are present and not nil in given struct or changeset -> set new data
        otherwise -> create a new Node

        ## Example

            result =
              case MyRepo.Node.get(Person, id) do
                nil  -> %Person{id: id}   # Person not found, we build one
                person -> person          # Person exists, let's use it
              end
              |> Person.changeset(changes)
              |> MyRepo.Node.merge

            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end
        """
        @spec create_or_set(Seraph.Schema.Node.t() | Seraph.Changeset.t(), Keyword.t()) ::
                {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}
        def create_or_set(struct_or_changeset, opts \\ []) do
          Node.Schema.create_or_set(@repo, struct_or_changeset, opts)
        end

        @doc """
        Same as create_or_set/2 but raise in case of error
        """
        @spec create_or_set!(
                Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | Seraph.Changeset.t(),
                Keyword.t()
              ) ::
                Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
        def create_or_set!(struct_or_changeset, opts \\ []) do
          Node.Schema.create_or_set!(@repo, struct_or_changeset, opts)
        end

        @doc """
        This function is the equivalent to `MERGE ... ON CREATE SET... ON MATCH SET...`.

        It requires:
          * `queryable` - The queryable to merge
          * `merge_keys_data`: a map with the merge keys data to used to match the node
          * `opts` - at least one of these three options must be present:
            - `:on_create`: a tuple `{data, changeset_fn}` with the data to set on node if it's created.
            Given data will be validated through given `changeset_fn`.
            - `:on_match`: a tuple `{data, changeset_fn}` with the data to set on node if it already exists
            and is matched. Given data will be validated through given `changeset_fn`
            - `:no_data` a boolean. Set to true allow to not provide `:on_match` nor `:on_create` and add
            no properties if node is created / updated. Useful for Node  without properties.

        It returns `{:ok, struct}` if the struct has been successfully
        merged or `{:error, changeset}` if there was a validation error.

        ## Examples

            # Node creation
            result = MyRepo.Node.merge(Person, %{},
                                  on_create: {%{name: "Collin Chou", role: "Seraph"}, &Person.changeset/2})
            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end

            # Node update
            person = MyRepo.get!(Person)
            result = MyRepo.Node.merge(Person, %{},
                                  on_match: {%{role: "anoter roleSeraph}, &Person.changeset/2})
            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end

            # Both depending on wether the node is found or not
            result = MyRepo.Node.merge(Person, %{},
                                  on_create: {%{name: "Collin Chou", role: "Seraph"}, &Person.changeset/2}
                                  on_match: {%{role: "Another role}, &Person.role_changeset/2})
            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end
        """
        @spec merge(Seraph.Repo.Queryable.t(), map, Keyword.t()) ::
                {:ok, Seraph.Schema.Node.t()} | {:error, Seraph.Changeset.t()}
        def merge(queryable, merge_keys_data, opts) do
          Node.Schema.merge(@repo, queryable, merge_keys_data, opts)
        end

        @doc """
        Same as merge/3 but raise in case of error
        """
        @spec merge(Seraph.Repo.Queryable.t(), map, Keyword.t()) :: Seraph.Schema.Node.t()
        def merge!(queryable, merge_keys_data, opts) do
          Node.Schema.merge!(@repo, queryable, merge_keys_data, opts)
        end

        @doc """
        Update a changeset using its merge keys.

        It returns `{:ok, struct}` if the struct has been successfully
        updated or `{:error, changeset}` if there was a validation error.

        ## Example

            person = MyRepo.Node.get!(Person, 42)
            person = Seraph.Changeset.change(person, %{role: "Not Seraph"})
            case MyRepo.Node.set(person) do
              {:ok, struct}       -> # Updated with success
              {:error, changeset} -> # Something went wrong
            end
        """
        @spec set(Seraph.Changeset.t(), Keyword.t()) ::
                {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
                | {:error, Seraph.Changeset.t()}
        def set(changeset, opts \\ []) do
          Node.Schema.set(@repo, changeset, opts)
        end

        @doc """
        Same as set/2 but raise in case of error
        """
        @spec set!(Seraph.Changeset.t(), Keyword.t()) ::
                Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
        def set!(changeset, opts \\ []) do
          Node.Schema.set!(@repo, changeset, opts)
        end

        @doc """
        Deletes a Node struct using its merge keys.

        It returns `{:ok, struct}` if the struct has been successfully
        deleted or `{:error, changeset}` if there was a validation error.

        ## Example

            person = MyRepo.Node.get!(Person, 42)
            case MyRepo.Node.delete(person) do
              {:ok, struct}       -> # Deleted with success
              {:error, changeset} -> # Something went wrong
            end
        """
        @spec delete(Seraph.Schema.Node.t() | Seraph.Changeset.t()) ::
                {:ok, Seraph.Schema.Node.t()} | {:error, Seraph.Changeset.t()}
        def delete(struct_or_changeset) do
          Node.Schema.delete(@repo, struct_or_changeset)
        end

        @doc """
        Same as `delete/1` but raise in case of error.
        """
        @spec delete!(Seraph.Schema.Node.t() | Seraph.Changeset.t()) :: Seraph.Schema.Node.t()
        def delete!(struct_or_changeset) do
          Node.Schema.delete!(@repo, struct_or_changeset)
        end
      end

      defmodule Relationship do
        alias Seraph.Repo.Relationship

        Module.put_attribute(
          __MODULE__,
          :repo,
          __MODULE__ |> Module.split() |> Enum.reject(&(&1 == "Relationship")) |> Module.concat()
        )

        # Schema
        @doc """
        Create a Relationship defined via `Seraph.Schema.Relationship` or a changeset.

        Note that a relationship will be created even if a similar one still exists, i.e. It translates
        to `CREATE (start_node)-[relationship_type]->(end_node)`.

        It returns `{:ok, struct}` if the struct has been successfully
        created or `{:error, changeset}` if there was a validation error.

        Options:
          * `node_creation`: if set to `true`, :start_node and :end_node will be
          created before relationship is.

        ## Example

            # with existing nodes
            person = MyRepo.Node.get!(Person, 42)
            movie = MyRepo.Node.get!(Movie, 1)
            new_rel = %ActedIn{
              start_node: person,
              end_node: movie,
              year: 2003
            }
            case MyRepo.Relationship.create(new_rel) do
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
            case MyRepo.Relationship.create(new_rel, node_creation: true) do
              {:ok, struct} -> # succesful creation
              {:ok, changeset} -> # invalid changeset
            end
        """
        @spec create(Seraph.Schema.Relationship.t() | Seraph.Changeset.t(), Keyword.t()) ::
                {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}
        def create(struct_or_changeset, opts \\ []) do
          Relationship.Schema.create(@repo, struct_or_changeset, opts)
        end

        @doc """
        Same as `create/2` but raise if changeset is invalid.
        """
        @spec create!(Seraph.Schema.Relationship.t() | Seraph.Changeset.t(), Keyword.t()) ::
                Seraph.Schema.Relationship.t()
        def create!(struct_or_changeset, opts \\ []) do
          Relationship.Schema.create!(@repo, struct_or_changeset, opts)
        end

        @doc """
        Create new Relationship if it doesn't exist.

        It translates to `MERGE (start_node)-[relationship_type]->(end_node)`.

        If `:start_node` and `:end_node` can be found (based on their merge keys) -> set new data
        otherwise ->  crete a new Relationship

        Options:
          * `node_creation`: if set to `true`, :start_node and :end_node will be created before
          relationship is.

        ## Example

            result =
              case MyRepo.Relationship.get(ActedIn, person, movie) do
                nil  -> %ActedIn{start_node: person, end_node: movie}   # ActedIn not found, we build one
                acted_in -> acted_in          # Person exists, let's use it
              end
              |> ActedIn.changeset(changes)
              |> MyRepo.Relationship.merge

            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end
        """
        @spec merge(Seraph.Schema.Relationship.t() | Seraph.Changeset.t(), Keyword.t()) ::
                {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}
        def merge(struct_or_changeset, opts \\ []) do
          Relationship.Schema.merge(@repo, struct_or_changeset, opts)
        end

        @doc """
        Same as merge/2 but raise in case of error
        """
        @spec merge!(Seraph.Schema.Relationship.t() | Seraph.Changeset.t(), Keyword.t()) ::
                Seraph.Schema.Relationship.t()
        def merge!(struct_or_changeset, opts \\ []) do
          Relationship.Schema.merge!(@repo, struct_or_changeset, opts)
        end

        @doc """
        This function is the equivalent to `MERGE ... ON CREATE SET... ON MATCH SET...`.

        It requires:
          * `queryable` - The queryable to merge
          * `start_node_data`: a valid Node schema data
          * `end_node_data`: a valid Node schema data
          * `opts` - at least one of these three options must be present:
            - `:on_create`: a tuple `{data, changeset_fn}` with the data to set on relationship if it's created.
            Given data will be validated through given `changeset_fn`.
            - `:on_match`: a tuple `{data, changeset_fn}` with the data to set on relationship if it already exists
            and is matched. Given data will be validated through given `changeset_fn`
            - `:no_data` a boolean. Set to true allow to not provide `:on_match` nor `:on_create` and add
            no properties if relationship is created / updated. Useful for Relationsship without properties.

        It returns `{:ok, struct}` if the struct has been successfully
        merged or `{:error, changeset}` if there was a validation error.

        ## Examples

            # Creation
            result = MyRepo.Relationship.merge(ActedIn, person, movie,
                                  on_create: {%{year: 2003}, &Person.changeset/2})
            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end

            # Update
            result = MyRepo.Relationship.merge(ActedIn, person, movie,
                                  on_match: {%{views: 2}, &Person.views_changeset/2})
            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end

            # Both depending on wether the node is found or not
            result = MyRepo.Relationship.merge(AActedIn, person, movie,
                                  on_create: {%{year: 2003}, &Person.changeset/2},
                                  on_match: {%{views: 2}, &Person.views_changeset/2})
            case result do
              {:ok, struct}       -> # Merged with success
              {:error, changeset} -> # Something went wrong
            end
        """
        @spec merge(
                Seraph.Repo.Queryable.t(),
                Seraph.Schema.Node.t(),
                Seraph.Schema.Node.t(),
                Keyword.t()
              ) ::
                {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}
        def merge(queryable, start_node_data, end_node_data, opts) do
          Relationship.Schema.merge(@repo, queryable, start_node_data, end_node_data, opts)
        end

        @doc """
        Same as merge/3 but raise in case of error
        """
        @spec merge(
                Seraph.Repo.Queryable.t(),
                Seraph.Schema.Node.t(),
                Seraph.Schema.Node.t(),
                Keyword.t()
              ) :: Seraph.Schema.Relationship.t()
        def merge!(queryable, start_node_data, end_node_data, opts) do
          Relationship.Schema.merge!(@repo, queryable, start_node_data, end_node_data, opts)
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
            MyRepo.Relationship.get!(ActedIn, %Person{name: "Collin Chou}, %Movie{title: "Matrix"})

            # With struct and data mixed
            MyRepo.Relationship.get!(ActedIn, %Person{name: "Collin Chou}, %{title: "Matrix"})

            # Only with data
            MyRepo.Relationship.get!(ActedIn, %{name: "Collin Chou}, %{title: "Matrix"})
        """
        def get(queryable, start_struct_or_data, end_struct_or_data) do
          Relationship.Queryable.get(@repo, queryable, start_struct_or_data, end_struct_or_data)
        end

        @doc """
        Same ass get/3 but raise an error if more than one relationship is found
        """
        def get!(queryable, start_struct_or_data, end_struct_or_data) do
          Relationship.Queryable.get!(@repo, queryable, start_struct_or_data, end_struct_or_data)
        end

        @doc """
        Updates a changeset using  its :end_node and :start_node

        This function allows to set new relationship data, but also to set new :start_node
        and :end_node

        It returns `{:ok, struct}` if the struct has been successfully
        updated or `{:error, changeset}` if there was a validation error.

        ## Example

            # Relationship
            rel_acted_in = MyRepo.Relationship.get!(ActedIn, %Person{name: "Collin Chou}, %Movie{title: "Matrix"})

            # Set new data
            Seraph.Changeset.change(rel_acted_in, %{year: 2003})
            |> MyRepo.Relationship.set()

            #Set new :end_node
            new_movie = Repo.Relationship.get!(Movie, 55)
            Seraph.Changeset.change(rel_acted_in, %{end_node: new_movie})
            |> MyRepo.Relationship.set()

        """
        @spec set(Seraph.Changeset.t(), Keyword.t()) ::
                {:ok, Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()}
                | {:error, Seraph.Changeset.t()}
        def set(changeset, opts \\ []) do
          Relationship.Schema.set(@repo, changeset, opts)
        end

        @doc """
        Same as set/2 but raise in case of error
        """
        @spec set!(Seraph.Changeset.t(), Keyword.t()) ::
                Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
        def set!(changeset, opts \\ []) do
          Relationship.Schema.set!(@repo, changeset, opts)
        end

        @doc """
        Deletes a Relationship struct using its `:start_node` and `:end_node`.

        It returns `{:ok, struct}` if the struct has been successfully
        deleted or `{:error, changeset}` if there was a validation error.

        ## Example

            acted_in = MyRepo.Relationship.get!(ActedIn, person, movie)
            case MyRepo.Relationship.delete(acted_in) do
              {:ok, struct}       -> # Deleted with success
              {:error, changeset} -> # Something went wrong
            end
        """
        @spec delete(Seraph.Schema.Relationship.t() | Seraph.Changeset.t()) ::
                {:ok, Seraph.Schema.Relationship.t()} | {:error, Seraph.Changeset.t()}
        def delete(struct_or_changeset) do
          Relationship.Schema.delete(@repo, struct_or_changeset)
        end

        @doc """
        Same as `delete/1` but raise in case of error.
        """
        @spec delete!(Seraph.Schema.Relationship.t() | Seraph.Changeset.t()) ::
                Seraph.Schema.Relationship.t()
        def delete!(struct_or_changeset) do
          Relationship.Schema.delete!(@repo, struct_or_changeset)
        end
      end
    end
  end
end
