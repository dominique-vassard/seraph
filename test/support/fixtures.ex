defmodule Seraph.Support.Fixtures do
  @moduledoc """
  Query fixtures
  """

  @doc """
  Builds a query fixtures with the given params
  """
  @spec build_query(map) :: Seraph.Query.t()
  def build_query(params) do
    %Seraph.Query{
      identifiers: %{
        "rel" => %Seraph.Query.Builder.Entity.Relationship{
          alias: nil,
          end: %Seraph.Query.Builder.Entity.Node{
            alias: nil,
            identifier: nil,
            labels: ["Post"],
            properties: [],
            queryable: Seraph.Test.Post
          },
          identifier: "rel",
          properties: [],
          queryable: Seraph.Relationship,
          start: %Seraph.Query.Builder.Entity.Node{
            alias: nil,
            identifier: "u",
            labels: ["User"],
            properties: [],
            queryable: Seraph.Test.User
          },
          type: nil
        },
        "u" => %Seraph.Query.Builder.Entity.Node{
          alias: nil,
          identifier: "u",
          labels: ["User"],
          properties: [],
          queryable: Seraph.Test.User
        }
      },
      params: params
    }
  end
end
