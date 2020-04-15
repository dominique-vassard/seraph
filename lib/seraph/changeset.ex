defmodule Seraph.Changeset do
  @moduledoc """
  Changesets allow filtering, casting, validation and definition of constraints when manipulating structs.

  See `Ecto.Changeset`
  """

  @type error :: Ecto.Changeset.error()

  @type data :: Ecto.Changeset.data()
  @type types :: Ecto.Changeset.types()

  @empty_values [""]

  defstruct valid?: false,
            data: nil,
            params: nil,
            changes: %{},
            repo_changes: %{},
            errors: [],
            validations: [],
            required: [],
            prepare: [],
            constraints: [],
            filters: %{},
            action: nil,
            types: nil,
            empty_values: @empty_values,
            repo: nil,
            repo_opts: []

  @type t(data_type) :: %Seraph.Changeset{
          valid?: boolean(),
          repo: atom | nil,
          repo_opts: Keyword.t(),
          data: data_type,
          params: %{String.t() => term} | nil,
          changes: %{atom => term},
          required: [atom],
          prepare: [(t -> t)],
          errors: [{atom, error}],
          constraints: [],
          validations: [{atom, term}],
          filters: %{atom => term},
          action: action,
          types: nil | %{atom => Ecto.Type.t()}
        }

  @type action :: nil | :create | :merge | :set | :delete | :ignore

  @type t :: t(Seraph.Schema.Node.t() | Seraph.Schema.Relationship.t() | map | nil)

  @spec cast(
          Seraph.Schema.t() | Seraph.Changeset.t() | {data(), types()},
          %{required(binary()) => term} | %{required(atom) => term} | :invalid,
          [atom],
          Keyword.t()
        ) :: Seraph.Changeset.t()
  @doc """
  See `Ecto.Changeset.cast/4`
  """
  def cast(%{__struct__: entity} = data, params, permitted, opts \\ []) do
    types = changeset_properties_types(entity)

    changeset = Ecto.Changeset.cast({data, types}, params, permitted, opts)

    case entity.__schema__(:entity_type) do
      :node ->
        changeset

      :relationship ->
        changeset
        |> cast_linked_node(entity, :start_node, Map.get(params, :start_node), permitted)
        |> cast_linked_node(entity, :end_node, Map.get(params, :end_node), permitted)
    end
    |> map_from_ecto()
  end

  @spec change(
          Seraph.Schema.t() | Seraph.Changeset.t() | {data(), types()},
          %{required(atom) => term} | Keyword.t()
        ) :: Seraph.Changeset.t()
  @doc """
  See `Ecto.Changeset.change/2`
  """
  def change(%{__struct__: entity} = data, changes \\ %{}) do
    types = entity.__schema__(:changeset_properties) |> Keyword.to_list() |> Enum.into(%{})

    Ecto.Changeset.change({data, types}, changes)
    |> map_from_ecto()
  end

  @doc """
  See `Ecto.Changeset.add_error/4`
  """
  @spec add_error(Seraph.Changeset.t(), atom, String.t(), Keyword.t()) :: Seraph.Changeset.t()
  def add_error(changeset, key, message, keys \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.add_error(key, message, keys)
    |> map_from_ecto()
  end

  @doc """
  See `Ecto.Changeset.apply_changes/1`
  """
  @spec apply_changes(Seraph.Changeset.t()) :: Seraph.Schema.t() | data
  def apply_changes(changeset) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.apply_changes()
  end

  @doc """
  See `Ecto.Changeset.delete_change/2`
  """
  @spec delete_change(Seraph.Changeset.t(), atom) :: Seraph.Changeset.t()
  def delete_change(changeset, key) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.delete_change(key)
    |> map_from_ecto()
  end

  @doc """
  See `Ecto.Changeset.fetch_change/2`
  """
  @spec fetch_change(Seraph.Changeset.t(), atom) :: {:ok, term} | :error
  def fetch_change(changeset, key) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.fetch_change(key)
  end

  @doc """
  See `Ecto.Changeset.fetch_change!/2`
  """
  @spec fetch_change!(Seraph.Changeset.t(), atom) :: term
  def fetch_change!(changeset, key) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.fetch_change!(key)
  end

  @doc """
   See `Ecto.Changeset.fetch_field/`2
  """
  @spec fetch_field(Seraph.Changeset.t(), atom) :: {:changes, term} | {:data, term} | :error
  def fetch_field(changeset, key) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.fetch_field(key)
  end

  @doc """
   See `Ecto.Changeset.fetch_field!/2`
  """
  @spec fetch_field!(Seraph.Changeset.t(), atom) :: term
  def fetch_field!(changeset, key) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.fetch_field!(key)
  end

  @doc """
   See `Ecto.Changeset.force_change/3`
  """
  @spec force_change(Seraph.Changeset.t(), atom, term) :: Seraph.Changeset.t()
  def force_change(changeset, key, value) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.force_change(key, value)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.get_change/3`
  """
  @spec get_change(Seraph.Changeset.t(), atom, term) :: term
  def get_change(changeset, key, default \\ nil) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.get_change(key, default)
  end

  @doc """
   See `Ecto.Changeset.get_field/3`
  """
  @spec get_field(Seraph.Changeset.t(), atom, term) :: term
  def get_field(changeset, key, default \\ nil) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.get_field(key, default)
  end

  @doc """
   See `Ecto.Changeset.merge/2`
  """
  @spec merge(Seraph.Changeset.t(), Seraph.Changeset.t()) :: Seraph.Changeset.t()
  def merge(changeset1, changeset2) do
    cs1 = map_to_ecto(changeset1)

    cs2 = map_to_ecto(changeset2)

    Ecto.Changeset.merge(cs1, cs2)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.put_change/3`
  """
  @spec put_change(Seraph.Changeset.t(), atom, term) :: Seraph.Changeset.t()
  def put_change(changeset, key, value) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.put_change(key, value)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.traverse_errors/2`
  """
  @spec traverse_errors(
          Seraph.Changeset.t(),
          (error() -> String.t()) | (Seraph.Changeset.t(), atom, error() -> String.t())
        ) :: %{required(atom) => [String.t()]}
  def traverse_errors(changeset, msg_func) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.traverse_errors(msg_func)
  end

  # @doc """
  #  See `Ecto.Changeset.unique_constraint/3`
  # """
  #  @spec unique_constraint(Seraph.Changeset.t(), atom, Keyword.t()) :: Seraph.Changeset.t()
  # def unique_constraint(changeset, field, opts \\ []) do
  #   changeset
  # |> map_to_ecto()
  # |> Ecto.Changeset.unique_constraint(field, opts)
  #   |> map_from_ecto()
  # end

  @doc """
   See `Ecto.Changeset.update_change/3`
  """
  @spec update_change(Seraph.Changeset.t(), atom, (term -> term)) :: Seraph.Changeset.t()
  def update_change(changeset, key, function) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.update_change(key, function)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_acceptance/3`
  """
  @spec validate_acceptance(Seraph.Changeset.t(), atom, Keyword.t()) :: Seraph.Changeset.t()
  def validate_acceptance(changeset, field, opts \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_acceptance(field, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_change/3`
  """
  @spec validate_change(
          Seraph.Changeset.t(),
          atom,
          (atom, term ->
             [{atom, String.t()} | {atom, {String.t(), Keyword.t()}}])
        ) :: Seraph.Changeset.t()
  def validate_change(changeset, field, validator) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_change(field, validator)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_change/4`
  """
  @spec validate_change(
          Seraph.Changeset.t(),
          atom,
          term,
          (atom, term ->
             [{atom, String.t()} | {atom, {String.t(), Keyword.t()}}])
        ) :: Seraph.Changeset.t()
  def validate_change(changeset, field, metadata, validator) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_change(field, metadata, validator)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_confirmation/3`
  """
  @spec validate_confirmation(Seraph.Changeset.t(), atom, Keyword.t()) :: Seraph.Changeset.t()
  def validate_confirmation(changeset, field, opts \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_confirmation(field, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_exclusion/4`
  """
  @spec validate_exclusion(Seraph.Changeset.t(), atom, Enum.t(), Keyword.t()) ::
          Seraph.Changeset.t()
  def validate_exclusion(changeset, field, data, opts \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_exclusion(field, data, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_format/4`
  """
  @spec validate_format(Seraph.Changeset.t(), atom, Regex.t(), Keyword.t()) ::
          Seraph.Changeset.t()
  def validate_format(changeset, field, format, opts \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_format(field, format, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_inclusion/4`
  """
  @spec validate_inclusion(Seraph.Changeset.t(), atom, Enum.t(), Keyword.t()) ::
          Seraph.Changeset.t()
  def validate_inclusion(changeset, field, data, opts \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_inclusion(field, data, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_length/3`
  """
  @spec validate_length(Seraph.Changeset.t(), atom, Keyword.t()) :: Seraph.Changeset.t()
  def validate_length(changeset, field, opts) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_length(field, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_number/`
  """
  @spec validate_number(Seraph.Changeset.t(), atom, Keyword.t()) :: Seraph.Changeset.t()
  def validate_number(changeset, field, opts) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_number(field, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_required/3`
  """
  @spec validate_required(Seraph.Changeset.t(), list | atom, Keyword.t()) ::
          Seraph.Changeset.t()
  def validate_required(changeset, fields, opts \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_required(fields, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validate_subset/`
  """
  @spec validate_subset(Seraph.Changeset.t(), atom, Enum.t(), Keyword.t()) ::
          Seraph.Changeset.t()
  def validate_subset(changeset, field, data, opts \\ []) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validate_subset(field, data, opts)
    |> map_from_ecto()
  end

  @doc """
   See `Ecto.Changeset.validations/1`
  """
  @spec validations(Seraph.Changeset.t()) :: [{atom, term}]
  def validations(changeset) do
    changeset
    |> map_to_ecto()
    |> Ecto.Changeset.validations()
  end

  defp changeset_properties_types(entity) do
    entity.__schema__(:changeset_properties)
    |> Keyword.to_list()
    |> Enum.into(%{})
  end

  # Check that the given node is part of the relationship
  defp cast_linked_node(changeset, _, _, nil, _) do
    changeset
  end

  defp cast_linked_node(changeset, relationship, linked_node, node_data, permitted) do
    case linked_node in permitted do
      true ->
        case extract_queryable(node_data) do
          {:ok, queryable} ->
            case queryable == relationship.__schema__(linked_node) do
              true ->
                changeset
                |> put_change(linked_node, node_data)

              false ->
                changeset
                |> add_error(
                  linked_node,
                  "#{inspect(linked_node)} must be a #{
                    Atom.to_string(relationship.__schema__(linked_node))
                  }."
                )
            end

          {:error, _} ->
            changeset
            |> add_error(
              linked_node,
              "#{inspect(linked_node)} must be a #{
                Atom.to_string(relationship.__schema__(linked_node))
              }."
            )
        end

      false ->
        changeset
    end
  end

  defp extract_queryable(%Seraph.Changeset{data: data}) do
    do_extract_queryable(data)
  end

  defp extract_queryable(data) do
    do_extract_queryable(data)
  end

  defp do_extract_queryable(%{__struct__: queryable}) do
    {:ok, queryable}
  end

  defp do_extract_queryable(_) do
    {:error, :invalid_type}
  end

  defp map_from_ecto(changeset) do
    struct!(Seraph.Changeset, Map.from_struct(changeset))
  end

  defp map_to_ecto(changeset) do
    struct!(Ecto.Changeset, Map.from_struct(changeset))
  end
end
