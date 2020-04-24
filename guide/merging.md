# Merging with `merge/x`
`merge/x` is just a `MERGE... ON CREATE SET ... ON MATCH SET...` which can perform a creation or a set.
First 2 (or 3 for relationship) arguments are similar to those used for `get/2,3`.  
The last one (`opts`) is used to defined the actions to perform in `ON CREATE SET` and `ON MATCH SET`.
It can be used as described in doc:
    - `:on_create`: a tuple `{data, changeset_fn}` with the data to set on relationship if it's created.
    Given data will be validated through given `changeset_fn`.
    - `:on_match`: a tuple `{data, changeset_fn}` with the data to set on relationship if it already exists
    and is matched. 
    Given data will be validated through given `changeset_fn`

You can provide `:on_create`, `:on_match`, or both.

### Examples

    # First let's add a new changeset function to User
    # lib/graph_app/blog/user.ex
    ...
    def update_first_name_changeset(%User{} = user, params) do
      user
      |> cast(params, [:firstName])
      |> validate_required([:firstName])
    end
    ...

    # Node merge
    node_data = %{uuid: "efc2b415-3a41-4b5f-aa8c-ad161a8baf43"}
    on_create = {%{firstName: "New", lastName: "Node", email: "no_email@mail.com"}, &User.changeset/2}
    on_match = {%{firstName: "Collin Seraph"}, &User.update_first_name_changeset/2}

    GraphApp.Repo.Node.merge(User, node_data, on_create: on_create, on_match: on_match){:ok,
    %GraphApp.Blog.User{
    __id__: 59,
    __meta__: %Seraph.Schema.Node.Metadata{
        primary_label: "User",
        schema: GraphApp.Blog.User
    },
    additionalLabels: [],
    comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :WROTE are not loaded>,
    email: "collin.chou@mail.com",
    firstName: "Collin Seraph",
    followed: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :FOLLOWS are not loaded>,
    follows: #Seraph.Schema.Relationship.NotLoaded<relationships :FOLLOWS are not loaded>,
    has_profile: #Seraph.Schema.Relationship.NotLoaded<relationships :HAS_PROFILE are not loaded>,
    lastName: "Chou",
    posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :WROTE are not loaded>,
    profile: #Seraph.Schema.Node.NotLoaded<nodes (UserProfile) through relationship :HAS_PROFILE are not loaded>,
    read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
    read_posts: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :READ are not loaded>,
    uuid: "efc2b415-3a41-4b5f-aa8c-ad161a8baf43",
    wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
    }}

    # Relationship merge
    GraphApp.Repo.Relationship.merge(Follows, john, james, on_create: {%{}, &Follows.changeset/2})

    # Result
    {:ok,
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
        email: "john.new_email@mail.com",
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
    }}
