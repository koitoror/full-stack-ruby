# Rails 5: The Tour - Step by Step


## Prerequisites

- Watch [Rails 5: The Tour](https://youtu.be/OaDhY_y8WTo) video.
- Create a [Cloud9](https://c9.io) account.
- Create a new Cloud9 Workspace **using the Ruby template** and run the following command from the terminal to setup everyting:
``` sh
curl -sL https://git.io/v9bfL | bash; rvm use ruby-2.4.1
```
- Install Ruby on Rails gem:
``` sh
gem install rails
```

## App creation


Start the new weblog application:
``` sh
rails new weblog --database postgresql --skip-coffee
```

Go the app folder:
``` sh
cd weblog
```

Have a look at the rails command options:
``` sh
rails --help
```

Start the rails server (in a separate terminal tab) and preview the running application on _https://***.c9users.io_:
``` sh
rails server
```
Yay! You’re on Rails! 🎉


## Post model

Generate a post scaffold and have a look at all the files generated:
``` sh
rails generate scaffold post title:string body:text
```

Create and migrate the database:
``` sh
rails db:create
rails db:migrate
```

Visit _http://***.c9users.io/posts/new_ and create a new post.
You can give a try to _http://***.c9users.io/posts.json_, yeah JSON API for free!

Add a title presence validation to the `Post` model and
try to create a new post without a title (don't forget to save you file!):
``` ruby
# app/models/post.rb
class Post < ApplicationRecord
  validates :title, presence: true
end
```

Play with the rails console and try to create/load a post:
``` sh
rails console
Post.all
Post.last
Post.create! title: 'Learnin Ruby on Rails', body: 'Oh Yeah!'
Post.last
```

Generate a new comment resource referencing the post model and run the migration:
``` sh
rails generate resource comment post:references body:text
rails db:migrate
```


## Comment model

Nest the comments resources route in posts resources and have a look at all the routes with `rails routes`:
``` ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :posts do
    resources :comments
  end
end
```

Add the comments relationship in the `Post` model:
``` ruby
# app/models/post.rb
class Post < ApplicationRecord
  has_many :comments, dependent: :destroy

  validates :title, presence: true
end
```

Add a comments section on the show post template:
``` erb
<%# app/views/posts/show.html.erb %>
<p id="notice"><%= notice %></p>

<p>
  <strong>Title:</strong>
  <%= @post.title %>
</p>

<p>
  <strong>Body:</strong>
  <%= @post.body %>
</p>

<%= link_to 'Edit', edit_post_path(@post) %> |
<%= link_to 'Back', posts_path %>

<br><br>

<h2>Comments</h2>

<div id="comments">
  <%# Expands to render partial: 'comments/comment', collection: @post.comments %>
  <%= render @post.comments %>
</div>

<%= render 'comments/new', post: @post %>
```

Add comments `_comment.html.erb` and `_new.html.erb` view partials:
``` erb
<%# app/views/comments/_comment.html.erb %>
<p><%= comment.body %> -- <%= comment.created_at.to_s(:long) %></p>
```
``` erb
<%# app/views/comments/_new.html.erb %>
<%= form_with(model: [@post, Comment.new], remote: true) do |form| %>
  Your comment:<br>
  <%= form.text_area :body, size: '50x20' %><br>
  <%= form.submit %>
<% end %>
```

Create a new `create` action in the `CommentsController`:
```ruby
# app/controllers/comments_controller.rb
class CommentsController < ApplicationController
  before_action :set_post

  # POST /posts/:post_id/comments
  # POST /posts/:post_id/comments.json
  def create
    @post.comments.create!(comments_params)
    redirect_to @post
  end

  private
    def set_post
      @post = Post.find(params[:post_id])
    end

    def comments_params
      params.require(:comment).permit(:body)
    end
end
```

Now you can try to add a comment to an existing post on _http://***.c9users.io/posts/1_, please have a look at the rails server logs to see what is happening.


## Comments mailer

Generate a new comments mailer with a submitted mail view:
``` sh
rails generate mailer comments submitted
```

Edit the freshly created `CommentsMailer`:
``` ruby
# app/mailers/comments_mailer.rb
class CommentsMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.comments_mailer.submitted.subject
  #
  def submitted(comment)
    @comment = comment

    mail to: "blog-owner@example.org", subject: 'New comment!'
  end
end
```

Edit the comments mailer view templates:
``` erb
<%# app/views/comments_mailer/submitted.html.erb %>
<h1>You got a new comment on <%= @comment.post.title %></h1>

<%= render @comment %>
```
``` erb
<%# app/views/comments_mailer/submitted.text.erb %>
You got a new comment on <%= @comment.post.title %>: <%= @comment.body %>
```

Edit the `CommentsMailerPreview` and preview a submitted email by visiting
_https://***.c9users.io/rails/mailers/comments_mailer/submitted_
``` ruby
# test/mailers/previews/comments_mailer_preview.rb
class CommentsMailerPreview < ActionMailer::Preview
  def submitted
    CommentsMailer.submitted(Comment.first)
  end
end
```

Now that your email is ready we can send it after the comment creation in the `CommentsController`:
``` ruby
  def create
    comment = @post.comments.create!(comments_params)
    CommentsMailer.submitted(comment).deliver_later

    redirect_to @post
  end
```

Try to create a new comment from the browser and look at the server logs, you should see the email content ✉️.


## Comments channel

Generate a new comments channel:
``` sh
rails generate channel comments
```

Add a `self.broadcast` class method to the new `CommentsChannel` class:
``` ruby
# app/channels/comments_channel.rb
class CommentsChannel < ApplicationCable::Channel
  def self.broadcast(comment)
    broadcast_to comment.post, comment:
      CommentsController.render(partial: 'comments/comment', locals: { comment: comment })
  end

  def subscribed
    # Only stream the last post for the demo!
    stream_for Post.last
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
```

Edit the comments channel javascript file to append any new comment to the post show page:
``` javascript
// app/assets/javascripts/channels/comments.js
App.comments = App.cable.subscriptions.create("CommentsChannel", {
  connected: function() {
    // Called when the subscription is ready for use on the server
    console.log('connected');
  },

  disconnected: function() {
    // Called when the subscription has been terminated by the server
    console.log('disconnected');
  },

  received: function(data) {
    // Called when there's incoming data on the websocket for this channel
    console.log('received: ');
    console.log(data);
    document.getElementById('comments').innerHTML += data.comment;
  }
});
```

Broadcast the new comment from `CommentsController#create`:

``` ruby
def create
  comment = @post.comments.create!(comments_params)
  CommentsMailer.submitted(comment).deliver_later
  CommentsChannel.broadcast(comment)

  redirect_to @post
end
```

All set! Now open the **last** post from _https://***.c9users.io/posts_ on
two different browsers/tabs and try to create a comment on one of them ✨.
(protip: Have a look at the browser inspector and the rails server log!)