# Schema

## General
### Entities
A graph is composed of two entities: node and relationship, each with its own specifities.  
Node has:
- one or more labels 
- 0 or more properties

Relationship has:
- one type
- 0 or more properties
- a direction

### About Neo4j internal ids
Neo4j uses `id` to manage its own internal ids, therefore the field `:id` is forbidden
for node node or relationship properties.  
This particular information can be found in the Node and Realtionship struct at the key `:__id__`.


### About naming conventions
`Seraph` enforces naming best practices recommended by Neo4j:
- Node labels should be CamelCased, starting with a uppercased character (ex: UserProfile)
- Relationship should be UPPERCASED (ex: WROTE)
- properties should be camelCased, starting with a lowercased character (ex: firstName)

Non respect of these rules will raise errors.

## GraphApp schemas

In our project, we need 4 nodes schema: User, UserProfile, Post and Comment.
Let's start with the User.

### A simple node: User
Its properties are:
    - firstName 
    - lastName
    - email

To define them is as simple as this:
```
# lib/graph_app/blog/user.ex
defmodule GraphApp.Blog.User do
  use Seraph.Schema.Node

  node "User" do
    property :firstName, :string
    property :lastName, :string
    property :email, :string
  end
end
```

User identifier is defined by default to `:uuid` and is an Ecto.UUID.  
We also have merge keys, which will be used to get the desired node in set 
and merge operations.   
We can also add a `changeset/2` function to validate our data:
```
# lib lib/graph_app/blog/user.ex

...
import Seraph.Changeset
...

def changeset(%User{} = user, params \\ %{}) do
  user
  |> cast(params, [:firstName, :lastName, :email])
  |> validate_required([:firstName, :lastName, :email])
end
```
`Seraph.Changeset` is a subset of `Ecto.Changeset` and most of the usual functions
are available.

Now, our node has outgoing and incoming relationships and we would like to define 
them.  

### Our first relationship
Let's work on the first one: `(User)-[:WROTE]->(Post)` which is a 1-x relationship.  
It has one property: `when` which is a datetime.  
Relationships have their own schema  and the one for `:WROTE` is as this:
```
# lib/graph_app/blog/relationship/wrote.ex

defmodule GraphApp.Blog.Relationship.Wrote do
  use Seraph.Schema.Relationship

  @cardinality [outgoing: :one, incoming: :many]

  relationship "WROTE" do
    start_node GraphApp.Blog.User
    end_node GraphApp.Blog.Post

    property :when, :utc_datetime
  end
end
```

A `changeset/2` would be nice too:
```
# lib/graph_app/blog/relationship/wrote.ex
...
import Seraph.Changeset

...
def changeset(%Wrote{} = wrote, params \\ %{}) do
  wrote
  |> cast(params, [:start_node, :end_node, :when])
  |> validate_required([:when])
end
```
Note that `:start_node` and `:end_node` have to to be set in casted params.  
This allows to have changeset when only one of them or neither can be changed. 
Useful if you want to have a reelationship with a fixed start/end.

### Back to User schema
Now adding the relationship to User node schema:
```
# lib/graph_app/blog/user.ex
  ...
  alias GraphApp.Blog.Relationship
  ...
  node "User" do
    outgoing_relationship "WROTE", GraphApp.Blog.Post, :posts, Wrote, cardinality: :many
  ...
```
`WROTE` is the relationship type
`GraphApp.Blog.Post` is the end node linked by the relationship
`:posts` is the struct field where preloaded (Post) nodes would be found
`Wrote` is the realtoinship module
`cardinality: :many` defines the cardinality of the relationship
Not that type, end node module and cardinality must match the ones defined in the relationship module. In fact, they are listed here to understand what the node is quickly.

A field `:wrote` will be available in the struct to hold the preloaded relationships

### Relationships without properties: define them quickly
In a Neo4j database model, there could be a significant amount of relationship without properties. Having to add a module for each of them could be very tedious. To avoid this, `Seraph` offers a quic k way to define them via `defrelationship`.  

Let's do it for our four remaining relationships:
    - (User)-[:WROTE]->(Comment)            (1 - x)
    - (User)-[:READ]->(Post)                (x - x)
    - (User)-[:FOLLOWS]->(User)             (1 - x)
    - (User)-[:HAS_PROFILE]->(UserProfile)  (1 - 1)

```
#lib/graph_app/blog/relationship/no_properties.ex
defmodule GraphApp.Blog.Relationship.NoProperties do
  import Seraph.Schema.Relationship

  alias GraphApp.Blog.{User, Post, Comment, UserProfile}

  defrelationship "WROTE", User, Comment, cardinality: [incoming: :one]
  defrelationship "READ", User, Post
  defrelationship "FOLLOWS", User, User, cardinality: [incoming: :one]
  defrelationship "HAS_PROFILE", User, UserProfile, cardinality: [outgoing: :one, incoming: :one]
  defrelationship("IS_ABOUT", Comment, Post, cardinality: [outgoing: :one, incoming: :many])
end
```

will expand to:
``` 
defmodule GraphApp.Blog.Relationship.NoProperties do
  defmodule UserToComment.Wrote do
    use Seraph.Schema.Relationship

    @cardinality [incoming: :one]

    relationship "WROTE" do
      start_node User
      end_node Comment
    end
  end
  
  defmodule UserToPost.Read do
    use Seraph.Schema.Relationship

    relationship "READ" do
      start_node User
      end_node Post
    end
  end
  
  defmodule UserToUser.Follows do
    use Seraph.Schema.Relationship

    @cardinality [incoming: :one]

    relationship "FOLLOWS" do
      start_node User
      end_node User
    end
  end
  
  defmodule UserToUserProfile.HasProfile do
    use Seraph.Schema.Relationship

    @cardinality [outgoing: :one, incoming: :one]

    relationship "HAS_PROFILE" do
      start_node User
      end_node UserProfile
    end
  end

  defmodule CommentToPost.IsAbout do
    use Seraph.Schema.Relationship

    @cardinality [outgoing: :one, incoming: :many]

    relationship "IS_ABOUT" do
      start_node Comment
      end_node Post
    end
  end
end
``` 

### Complete User node schema
Here is our final User schema with all its relationships:
```
# lib/graph_app/blog/user.ex
defmodule GraphApp.Blog.User do
  use Seraph.Schema.Node
  import Seraph.Changeset

  alias GraphApp.Blog.User
  alias GraphApp.Blog.Relationship
  alias GraphApp.Blog.Relationship.NoProperties

  node "User" do
    property :firstName, :string
    property :lastName, :string
    property :email, :string

    outgoing_relationship("WROTE", GraphApp.Blog.Post, :posts, Relationship.Wrote,
      cardinality: :many
    )

    outgoing_relationship(
      "WROTE",
      GraphApp.Blog.Comment,
      :comments,
      NoProperties.UserToComment.Wrote,
      cardinality: :many
    )

    outgoing_relationship("READ", GraphApp.Blog.Post, :read_posts, NoProperties.UserToPost.Read,
      cardinality: :many
    )

    outgoing_relationship(
      "HAS_PROFILE",
      GraphApp.Blog.UserProfile,
      :profile,
      NoProperties.UserToUserProfile.HasProfile,
      cardinality: :one
    )

    outgoing_relationship(
      "FOLLOWS",
      GraphApp.Blog.User,
      :followed,
      NoProperties.UserToUser.Follows,
      cardinality: :many
    )
  end

  def changeset(%User{} = user, params \\ %{}) do
    user
    |> cast(params, [:firstName, :lastName, :email])
    |> validate_required([:firstName, :lastName, :email])
  end
end
```
We have 2 `:WROTE` relationships here... But it is not a problem, every `:WROTE` relationships will be preloaded in the `:wrote` field.  

### Your usage / need for documentation defines your schema
It is not mandatory to define all the relationships of a particular node.  
For example, this is valid:
```
defmodule GraphApp.Blog.UserProfile do
  use Seraph.Schema.Node
  import Seraph.Changeset

  alias GraphApp.Blog.UserProfile

  node "UserProfile" do
    property :isPremium, :boolean
    property :age, :integer
  end

  def changeset(%UserProfile{} = user_profile, params \\ %{}) do
    user_profile
    |> cast(params, [:isPremium, :age])
    |> validate_required([:isPremium, :age])
  end
end
```   
We haven't define the `(User)-[:HAS_PROFILE]->(UserProfile)` as we've done in User.  
This is your choice:
 - not having it -> Make it impossible to go from UserProfile to User
 - having it -> Complete documentation of database schema


### The other node schemas
Post
```
defmodule GraphApp.Blog.Post do
  use Seraph.Schema.Node

  alias GraphApp.Blog.{Comment, User}
  alias GraphApp.Blog.Relationship.{NoProperties, Wrote}

  node "Post" do
    property :title, :string
    property :text, :string
    property :rate, :integer, default: 0

    incoming_relationship("WROTE", User, :author, Wrote, cardinality: :one)

    incoming_relationship("READ", User, :readers, NoProperties.UserToPost.Read, cardinality: :many)

    incoming_relationship("IS_ABOUT", Comment, :comments, NoProperties.CommentToPost.IsAbout,
      cardinality: :many
    )
  end
end
```

Comment
```
defmodule GraphApp.Blog.Comment do
  use Seraph.Schema.Node

  alias GraphApp.Blog.{Post, User}
  alias GraphApp.Blog.Relationship.NoProperties

  node "Comment" do
    property :text, :string

    outgoing_relationship("IS_ABOUT", Post, :post, NoProperties.CommentToPost.IsAbout,
      cardinality: :one
    )

    incoming_relationship("WROTE", User, :author, NoProperties.UserToComment.Wrote,
      cardinality: :one
    )
  end
end
```