defmodule Seraph.Test.UserToPost.Wrote do
  @moduledoc false
  use Seraph.Schema.Relationship
  import Seraph.Changeset

  @cardinality [incoming: :one]

  relationship "WROTE" do
    start_node Seraph.Test.User
    end_node Seraph.Test.Post

    property :at, :utc_datetime
  end

  def changeset(wrote, params \\ %{}) do
    wrote
    |> cast(params, [:start_node, :end_node, :at])
  end
end

defmodule Seraph.Test.NoPropsRels do
  @moduledoc false
  import Seraph.Schema.Relationship

  defrelationship("READ", Seraph.Test.User, Seraph.Test.Post)
  defrelationship("EDITED_BY", Seraph.Test.Post, Seraph.Test.User)
  defrelationship("FOLLOWS", Seraph.Test.User, Seraph.Test.User)
  defrelationship("WROTE", Seraph.Test.User, Seraph.Test.Comment)
  defrelationship("IS_A", Seraph.Test.User, Seraph.Test.Admin, cardinality: [outgoing: :one])
end

defmodule Seraph.Test.User do
  @moduledoc false
  use Seraph.Schema.Node
  import Seraph.Changeset

  alias Seraph.Test.NoPropsRels

  node "User" do
    property :firstName, :string
    property :lastName, :string
    property :viewCount, :integer, default: 1

    outgoing_relationship "WROTE", Seraph.Test.Post, :posts, Seraph.Test.UserToPost.Wrote
    outgoing_relationship "READ", Seraph.Test.Post, :read_posts, NoPropsRels.UserToPost.Read
    outgoing_relationship "WROTE", Seraph.Test.Comment, :comments, NoPropsRels.UserToComment.Wrote
    outgoing_relationship "FOLLOWS", Seraph.Test.User, :followeds, NoPropsRels.UserToUser.Follows

    outgoing_relationship("IS_A", Seraph.Test.Admin, :admin_badge, NoPropsRels.UserToAdmin.IsA,
      cardinality: :one
    )

    incoming_relationship "EDITED_BY",
                          Seraph.Test.Post,
                          :edited_posts,
                          NoPropsRels.PostToUser.EditedBy

    incoming_relationship "FOLLOWS",
                          Seraph.Test.User,
                          :followers,
                          NoPropsRels.UserToUser.Follows

    @spec changeset(Seraph.Schema.Node.t(), map) :: Seraph.Changeset.t()
    def changeset(user, params \\ %{}) do
      user
      |> cast(params, [:firstName, :lastName, :viewCount, :additionalLabels])
    end

    def update_viewcount_changeset(user, params \\ %{}) do
      user
      |> cast(params, [:viewCount])
    end
  end
end

defmodule Seraph.Test.Comment do
  @moduledoc false
  use Seraph.Schema.Node

  node "Comment" do
    property :title, :string
    property :text, :string
    property :rate, :integer
  end
end

defmodule Seraph.Test.Admin do
  @moduledoc false
  use Seraph.Schema.Node
  alias Seraph.Test.NoPropsRels

  node "Admin" do
    incoming_relationship "IS_A", Seraph.Test.User, :users, NoPropsRels.UserToAdmin.IsA
  end
end

defmodule Seraph.Test.Post do
  @moduledoc false
  use Seraph.Schema.Node
  import Seraph.Changeset

  alias Seraph.Test.NoPropsRels

  node "Post" do
    property :title, :string
    property :text, :string

    incoming_relationship("WROTE", Seraph.Test.User, :author, Seraph.Test.UserToPost.Wrote,
      cardinality: :one
    )

    incoming_relationship "READ", Seraph.Test.User, :readers, NoPropsRels.UserToPost.Read
  end

  def changeset(post, params \\ %{}) do
    post
    |> cast(params, [:title, :text])
  end
end

defmodule Seraph.Test.MergeKeys do
  @moduledoc false
  use Seraph.Schema.Node

  @merge_keys [:mkField1, :mkField2]

  node "MergeKeys" do
    property :mkField1, :string
    property :mkField2, :string
  end
end
