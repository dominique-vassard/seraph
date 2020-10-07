# Creating

## Node
A node can be created via a struct:
```
user = %GraphApp.Blog.User{
    firstName: "John",
    lastName: "Doe",
    email: "john.doe@mail.com"
}

{:ok, john} = GraphApp.Repo.Node.create(user)

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
 }}
```

Notice that because we use the default :uuid identifier, Seraph generates it automatically.

A node can also be created with a changeset:
```
alias GraphApp.Blog.User
alias GraphApp.Repo

data = %{
    firstName: "James",
    lastName: "Who",
    email: "james.who@mail.com"
}

{:ok, james} = %User{}
|> User.changeset(data)
|> Repo.Node.create()

# Result
{:ok,
 %GraphApp.Blog.User{
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
 }}
```


## Relationship with possible duplication using `create/2`
`create/2` is also available on `Repo.Relationship` but notice that it will perform a 
`CREATE` which means that you could create the same relationship multiple times. To avoid duplication, you'll have to use `merge/2`.

If the start and end nodes exist, a relationship can be created with a struct like this:
```
# Considering the previously created nodes `john` and `james`
alias GraphApp.Repo
alias GraphApp.Blog.Relationship.NoProperties.UserToUser.Follows

data = %Follows{
    start_node: john,
    end_node: james,
}

{:ok, follows} = Repo.Relationship.create(data)

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
 }}
```

A relationship can also be created with a changeset:
```
data = %{
    start_node: john,
    end_node: james,
}

{:ok, follows} = %Follows{}
|> Follows.changeset(data)
|> Repo.Relationship.create(data)
``` 
This is perfectly valid but it will create another `:FOLLOWS` relationship between these two nodes and we don't want that.

If both start and end nodes don't exist, it is possible to have them created while creating the relationship by using the `:node_creation` option:
```
alias GraphApp.Blog.{Comment, Post}
alias GraphApp.Blog.Relationship.NoProperties.CommentToPost.IsAbout

post_data = %Post{
    title: "A wonderful first post",
    text: "Blabla"
}

comment_data = %Comment{
    text: "Interesting"
}

rel_data = %{
    start_node: comment_data,
    end_node: post_data
}

{:ok, is_about} = %IsAbout{} 
|> IsAbout.changeset(rel_data) 
|> Repo.Relationship.create(node_creation: true)

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
```

## Relationship without duplication using `merge/2`
One of the two use cases for `merge/2` is to create relationship without duplication, meaning that the attempt to create a relationship exactly similar to one already existing won't do anything.  
On the other, if the relationship doesn't exists, it will be created.  

```
# Getting back our created comment and post to complete our graph
%IsAbout{start_node: comment, end_node: post} = is_about

# And create our missing relationships
alias GraphApp.Blog.Relationship.Wrote
alias GraphApp.Blog.Relationship.NoProperties.UserToComment

wrote_post_data = %{
    start_node: john,
    end_node: post,
    when: DateTime.utc_now() |> DateTime.truncate(:second)
}

%Wrote{} 
|> Wrote.changeset(wrote_post_data) 
|> Repo.Relationship.merge()


wrote_comment_data = %{
    start_node: james,
    end_node: comment
}

{:ok, wrote_comment} = %UserToComment.Wrote{} 
|> UserToComment.Wrote.changeset(wrote_comment_data) 
|> Repo.Relationship.merge()
```

Now, if you replay:
```
{:ok, ^wrote_comment} = %UserToComment.Wrote{} 
|> UserToComment.Wrote.changeset(wrote_comment_data) 
|> Repo.Relationship.merge()
```
No new relationship will be created and the old one will be returned.
