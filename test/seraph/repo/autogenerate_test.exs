defmodule Seraph.Test.Repo.AutogenerateTest do
  use ExUnit.Case
  alias Seraph.TestRepo
  alias Seraph.Support.Storage

  setup do
    Storage.clear(TestRepo)
  end

  defmodule Company do
    use Seraph.Schema.Node
    import Seraph.Changeset

    node "Default" do
      property :value, :integer

      timestamps()
    end

    def changeset(company, params \\ %{}) do
      company
      |> cast(params, [:value])
    end
  end

  defmodule Manager do
    use Seraph.Schema.Node

    @timestamps_opts [createdAt: :importedOn]
    node "Manager" do
      property :value, :integer

      timestamps updatedAt: :updatedOn, type: :utc_datetime
    end
  end

  defmodule NaiveMod do
    use Seraph.Schema.Node

    node "NaiveMod" do
      timestamps(type: :naive_datetime)
    end
  end

  defmodule NaiveUsecMod do
    use Seraph.Schema.Node

    node "NaiveUsecMod" do
      timestamps(type: :naive_datetime_usec)
    end
  end

  defmodule UtcMod do
    use Seraph.Schema.Node

    node "UtcMod" do
      timestamps(type: :utc_datetime)
    end
  end

  defmodule UtcUsecMod do
    use Seraph.Schema.Node

    node "UtcUsecMod" do
      timestamps(type: :utc_datetime_usec)
    end
  end

  test "sets inserted_at and updated_at values" do
    default = TestRepo.Node.create!(%Company{value: 5})
    assert %{calendar: Calendar.ISO, microsecond: {_, 6}} = default.createdAt
    assert %{calendar: Calendar.ISO, microsecond: {_, 6}} = default.updatedAt
    assert default.createdAt == default.updatedAt

    # Change on set
    updated_default =
      default
      |> Seraph.Changeset.change(%{value: 7})
      |> TestRepo.Node.set!()

    assert updated_default.createdAt == default.createdAt
    refute updated_default.updatedAt == default.updatedAt
    assert :gt == NaiveDateTime.compare(updated_default.updatedAt, default.updatedAt)

    # Change on merge (on create)
    node_data = %{uuid: "efc2b415-3a41-4b5f-aa8c-ad161a8baf43"}
    on_create = {%{value: 11}, &Company.changeset/2}
    on_match = {%{value: 15}, &Company.changeset/2}

    on_created =
      TestRepo.Node.merge!(Company, node_data, on_create: on_create, on_match: on_match)

    assert %{calendar: Calendar.ISO, microsecond: {_, 6}} = on_created.createdAt
    assert %{calendar: Calendar.ISO, microsecond: {_, 6}} = on_created.updatedAt
    assert on_created.createdAt == on_created.updatedAt

    # Change on merge (on match)
    on_matched =
      TestRepo.Node.merge!(Company, node_data, on_create: on_create, on_match: on_match)

    assert on_matched.createdAt == on_created.createdAt
    refute on_matched.updatedAt == on_created.updatedAt
    assert :gt == NaiveDateTime.compare(on_matched.updatedAt, on_created.updatedAt)
  end

  test "sets custom inserted_at and updated_at values" do
    manager =
      TestRepo.Node.create!(%Manager{value: 2})
      |> IO.inspect()

    IO.inspect(Map.from_struct(manager.importedOn))
    assert %{calendar: Calendar.ISO, microsecond: {_, 6}} = manager.importedOn
    assert %{calendar: Calendar.ISO, microsecond: {_, 6}} = manager.updatedOn
    assert manager.importedOn == manager.updatedOn

    Process.sleep(5)

    IO.inspect(Seraph.Test.Repo.AutogenerateTest.Manager.__schema__(:autogenerate))
    IO.inspect(Seraph.Test.Repo.AutogenerateTest.Manager.__schema__(:autoupdate))

    # Change on update
    updated_manager =
      manager
      |> Seraph.Changeset.change(%{value: 7})
      |> TestRepo.Node.set!()
      |> IO.inspect()

    assert updated_manager.importedOn == manager.importedOn
    refute updated_manager.updatedOn == manager.updatedOn
    assert :gt == NaiveDateTime.compare(updated_manager.updatedOn, manager.updatedOn)
  end
end
