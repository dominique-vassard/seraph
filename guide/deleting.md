# Deleting

Deleting is very simple, just use `delete/1`.  
Note that, as expected, deleting a node will delete all relationships coming to and from it.  

## Examples

    # Node deletion
    GraphApp.Repo.Node.get(User, "87f6c568-0454-4688-b5e8-d7036b30b78b") 
    |> GraphApp.Repo.Node.delete()

    # Result
    {:ok,
        %GraphApp.Blog.User{
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
        }}


    # Relationship deletion
    GraphApp.Repo.Relationship.get(IsAbout, comment, post) |> GraphApp.Repo.Relationship.delete()

    # Result
    {:ok,
        %GraphApp.Blog.Relationship.NoProperties.CommentToPost.IsAbout{
        __id__: 10,
        __meta__: %Seraph.Schema.Relationship.Metadata{
            schema: GraphApp.Blog.Relationship.NoProperties.CommentToPost.IsAbout,
            type: "IS_ABOUT"
        },
        end_node: %GraphApp.Blog.Post{
            __id__: 40,
            __meta__: %Seraph.Schema.Node.Metadata{
            primary_label: "Post",
            schema: GraphApp.Blog.Post
            },
            additionalLabels: [],
            author: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :WROTE are not loaded>,
            comments: #Seraph.Schema.Node.NotLoaded<nodes (Comment) through relationship :IS_ABOUT are not loaded>,
            is_about: #Seraph.Schema.Relationship.NotLoaded<relationships :IS_ABOUT are not loaded>,
            rate: 0,
            read: #Seraph.Schema.Relationship.NotLoaded<relationships :READ are not loaded>,
            readers: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :READ are not loaded>,
            text: "Blabla",
            title: "A wonderful first post",
            uuid: "d52ce3fc-f67a-44be-bc9d-95d2c23d884f",
            wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
        },
        start_node: %GraphApp.Blog.Comment{
            __id__: 39,
            __meta__: %Seraph.Schema.Node.Metadata{
            primary_label: "Comment",
            schema: GraphApp.Blog.Comment
            },
            additionalLabels: [],
            author: #Seraph.Schema.Node.NotLoaded<nodes (User) through relationship :WROTE are not loaded>,
            is_about: #Seraph.Schema.Relationship.NotLoaded<relationships :IS_ABOUT are not loaded>,
            post: #Seraph.Schema.Node.NotLoaded<nodes (Post) through relationship :IS_ABOUT are not loaded>,
            text: "Interesting",
            uuid: "909663ce-7840-4194-95d8-602e27c65f5c",
            wrote: #Seraph.Schema.Relationship.NotLoaded<relationships :WROTE are not loaded>
        },
        type: "IS_ABOUT"
        }}
