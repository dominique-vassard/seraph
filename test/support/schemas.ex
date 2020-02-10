defmodule Neo4jex.Test.UserToPost.Wrote do
  use Neo4jex.Schema.Relationship

  relationship "WROTE" do
    start_node Neo4jex.Test.User
    end_node Neo4jex.Test.Post

    property :at, :utc_datetime
  end
end

defmodule Neo4jex.Test.User do
  use Neo4jex.Schema.Node
  import Neo4jex.Changeset

  node "Test" do
    property :first_name, :string
    property :last_name, :integer
    property :view_count, :integer, default: 1

    outgoing_relationship "WROTE", Neo4jex.Test.Post, :posts,
      through: Neo4jex.Test.UserToPost.Wrote

    outgoing_relationship "READ", Neo4jex.Test.Post, :read_posts
    outgoing_relationship "FOLLOWS", Neo4jex.Test.User, :followeds

    incoming_relationship "EDITED_BY", Neo4jex.Test.Post, :edited_posts
    incoming_relationship "FOLLOWED", Neo4jex.Test.User, :followers

    @spec changeset(Neo4jex.Schema.Node.t(), map) :: Ecto.Changeset.t()
    def changeset(user, params \\ %{}) do
      user
      |> cast(params, [:first_name, :last_name])
    end
  end
end

defmodule Neo4jex.Test.Post do
  use Neo4jex.Schema.Node

  node "Post" do
    property :title, :string
    property :text, :string
  end
end
