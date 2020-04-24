defmodule Seraph.Repo.Node.Repo do
  defmacro __using__(repo_module) do
    quote do
      repo_module = unquote(repo_module)

      defmodule Node do
        alias Seraph.Repo.Node

        @repo repo_module

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
        @spec get(Seraph.Repo.queryable(), any) ::
                nil | Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t()
        def get(queryable, identifier_value) do
          Node.Queryable.get(@repo, queryable, identifier_value)
        end

        @doc """
        Same as get/2 but raise if more than Node is found.
        """
        @spec get!(Seraph.Repo.queryable(), any) ::
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
        @spec merge(Seraph.Repo.queryable(), map, Keyword.t()) ::
                {:ok, Seraph.Schema.Node.t()} | {:error, Seraph.Changeset.t()}
        def merge(queryable, merge_keys_data, opts) do
          Node.Schema.merge(@repo, queryable, merge_keys_data, opts)
        end

        @doc """
        Same as merge/3 but raise in case of error
        """
        @spec merge!(Seraph.Repo.queryable(), map, Keyword.t()) :: Seraph.Schema.Node.t()
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

        @doc """
        Preload relationships / related nodes on the given Node or Nodes.
        Either a relationship type field or a node list field can be passed as preload.

        By default relationships and related nodes will be loaded.

        In case the association was already loaded, preload won't attempt to reload it.

        Options:
          * `:load` - Define the type of data for load:
            - `:all`: Loads relationships and related nodes data. (default)
            - `:nodes`: Loads only related nodes data
            - `:relationships`: Loads only relationships data
          * `:force` - Set to `true` force the reload of an already loaded relation.
          Default: false
          * `:limit` - To limit the number of preloaded data. Note that results
          are ordered by the Node identifier key.

        ## Example

          # Use a single atom to preload single relationship type data
          person = MyRepo.Node.preload(person, :acted_in)

          # Use a single atom to preload only the nodes
          person = MyRepo.Node.preload(person, :acted_in, load: :nodes)

          # Use a list of atoms to preload multiple relationship type data
          person = MyRepo.Node.preload(person, [:acted_in, :directed])

          # Limit number of preload
          person = MyRepo.Node.preload(person, :acted_in, limit: 50)

          # Forece preload on an alredy preloaded struct
          person = MyRepo.Node.preload(person, :acted_in, force: true)
        """
        @spec preload(Seraph.Schema.Node.t(), atom | [atom], Keyword.t()) ::
                Seraph.Schema.Node.t()
        def preload(struct, preloads, opts \\ []) do
          Node.Preloader.preload(@repo, struct, preloads, opts)
        end
      end
    end
  end
end
