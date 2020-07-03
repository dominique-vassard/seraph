defmodule Seraph.Query.Builder.Entity.PropertyTest do
  use ExUnit.Case, async: true

  alias Seraph.Query.Builder.Entity.{Node, Property, Relationship}

  describe "from_map/2" do
    test "ok with node" do
      entity = %Node{
        identifier: "n",
        queryable: Seraph.Node
      }

      properties = %{firstName: "John", lastName: "Doe"}

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "n",
                 entity_queryable: Seraph.Node,
                 name: :firstName,
                 type: nil,
                 value: "John"
               },
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "n",
                 entity_queryable: Seraph.Node,
                 name: :lastName,
                 type: nil,
                 value: "Doe"
               }
             ] == Property.from_map(properties, entity)
    end

    test "ok with relationship" do
      entity = %Relationship{
        identifier: "rel",
        queryable: Seraph.Relationship
      }

      properties = %{weight: 5, valid: true}

      assert [
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "rel",
                 entity_queryable: Seraph.Relationship,
                 name: :valid,
                 type: nil,
                 value: true
               },
               %Seraph.Query.Builder.Entity.Property{
                 alias: nil,
                 bound_name: nil,
                 entity_identifier: "rel",
                 entity_queryable: Seraph.Relationship,
                 name: :weight,
                 type: nil,
                 value: 5
               }
             ] == Property.from_map(properties, entity)
    end
  end
end
