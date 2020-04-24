# Getting 
To get nodes or relationships from database, you can use the `get/x` functions.

## Node: `get/2`
To retrieve a node, you have to provide the identifier value depending on the identifier key defined in the schema (by default: :uuid, Ecto.UUID).  

### Example
```
    GraphApp.Repo.Node.get(User, "87f6c568-0454-4688-b5e8-d7036b30b78b")

    # Result
    %GraphApp.Blog.User{
      __id__: 1,
      __meta__: %Seraph.Schema.Node.Metadata{
          primary_label: "User",
          schema: GraphApp.Blog.User
      },
      additionalLabels: [],
      comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :WROTE   are not loaded>,
      email: "john.doe@mail.com",
      firstName: "John",
      followed: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :FOLLOWS   are not loaded>,
      follows: #Seraph.Schema.Relationship.NotLoaded<relationships :FOLLOWS are not   loaded>,
      has_profile: #Seraph.Schema.Relationship.NotLoaded<relationships :HAS_PROFILE are   not loaded>,
      lastName: "Doe",
      posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :WROTE are   not loaded>,
      profile: #Seraph.Schema.Node.NotLoaded<nodes (UserProfile) through relationship   :HAS_PROFILE are not loaded>,
      read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
      read_posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :READ   are not loaded>,
      uuid: "87f6c568-0454-4688-b5e8-d7036b30b78b",
      wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
      }

```

## Relationship: `get/3`
Retrieving a relationship is different from retrieving a node because it doesn't have an identifier in itself. In fact, it is identified by the start and end nodes they linked: `get(relationship_module, start_node, end_node)`.  
Then to retrieve the relationship between `john` and `james`, you have to provides them as params:  
```
# Either as struct
GraphApp.Repo.Relationship.get(Follows, john, james)

# or as map (but identifier have to present as it will be used for querying)
john_params = %{uuid: "87f6c568-0454-4688-b5e8-d7036b30b78b", firstName: "John"}
james_params = %{uuid: "5d3e509b-eb0e-4ebf-bbaa-87e0b55c295e", firstName: "James"}
GraphApp.Repo.Relationship.get(Follows, john_params, james_params)

# Result
%GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows{
  __id__: 0,
  __meta__: %Seraph.Schema.Relationship.Metadata{
    schema: GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows,
    type: "FOLLOWS"
  },
  end_node: %GraphApp.Blog.User{
    __id__: 20,
    __meta__: %Seraph.Schema.Node.Metadata{
      primary_label: "User",
      schema: GraphApp.Blog.User
    },
    additionalLabels: [],
    comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :WROTE are not loaded>,
    email: "james.who@mail.com",
    firstName: "James",
    followed: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :FOLLOWS are not loaded>,
    follows: #Seraph.Schema.Relationship.NotLoaded<relationships :FOLLOWS are not loaded>,
    has_profile: #Seraph.Schema.Relationship.NotLoaded<relationships :HAS_PROFILE are not loaded>,
    lastName: "Who",
    posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :WROTE are not loaded>,
    profile: #Seraph.Schema.Node.NotLoaded<nodes (UserProfile) through relationship :HAS_PROFILE are not loaded>,
    read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
    read_posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :READ are not loaded>,
    uuid: "5d3e509b-eb0e-4ebf-bbaa-87e0b55c295e",
    wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
  },
  start_node: %GraphApp.Blog.User{
    __id__: 1,
    __meta__: %Seraph.Schema.Node.Metadata{
      primary_label: "User",
      schema: GraphApp.Blog.User
    },
    additionalLabels: [],
    comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :WROTE are not loaded>,
    email: "john.doe@mail.com",
    firstName: "John",
    followed: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :FOLLOWS are not loaded>,
    follows: #Seraph.Schema.Relationship.NotLoaded<relationships :FOLLOWS are not loaded>,
    has_profile: #Seraph.Schema.Relationship.NotLoaded<relationships :HAS_PROFILE are not loaded>,
    lastName: "Doe",
    posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :WROTE are not loaded>,
    profile: #Seraph.Schema.Node.NotLoaded<nodes (UserProfile) through relationship :HAS_PROFILE are not loaded>,
    read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
    read_posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :READ are not loaded>,
    uuid: "87f6c568-0454-4688-b5e8-d7036b30b78b",
    wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
  },
  type: "FOLLOWS"
}
```
