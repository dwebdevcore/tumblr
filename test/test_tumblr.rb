require 'helper'

class TestTumblr < Test::Unit::TestCase  
  describe 'Reader' do
    test 'sets up credentials for authentication' do
      reader = Tumblr::Reader
      assert !reader.new.defaults
      params = {:email => 'test@testermcgee.com', :password => 'dontrevealmysecrets'}
      credentials = reader.new(params[:email],params[:password]).defaults
      assert credentials.has_key? :email
      assert credentials.has_key? :password
      assert_equal params, credentials
    end
    
    test 'handles parameters for reads' do
      reader = Tumblr::Reader
      options = {:start => 5, :num => 10, :foo => 'Bar', :type => 'video'}
      cred = {:email => 'test@testermcgee.com', :password => 'dontrevealmysecrets'}
      assert !reader.new.parameters(options).has_key?(:foo)
      assert_equal cred[:email], reader.new(*cred.values).parameters(options)[:email]
      assert reader.new(*cred.values).parameters(options).has_key?(:password)
    end
    
    test 'convenience method for reads' do
      t = Tumblr::Reader
      assert_respond_to t, :read
      assert_equal :get, t.read('mwunsch').via
      assert_equal 'http://mwunsch.tumblr.com/api/read/', t.read('mwunsch').uri.normalize.to_s
      assert_equal :post, t.read('mwunsch',:post).via
      params = {:email => 'test@testermcgee.com', :password => 'dontrevealmysecrets'}
      assert_equal params.to_params, t.read('mwunsch',:post,params).with
    end
  
    test 'reads posts' do
      reader = Tumblr::Reader
      mwunsch = reader.new.read('mwunsch')
      assert_respond_to mwunsch, :perform
      assert_equal 'http://mwunsch.tumblr.com/api/read/', mwunsch.uri.normalize.to_s
      response = hijack! mwunsch, 'read/mwunsch'
      assert response.success?
      assert_equal :xml, response.format
    end
    
    test 'reads posts with some optional parameters' do
      reader = Tumblr::Reader
      options = {:num => 5, :type => :video}
      posts = reader.new.read 'mwunsch', options
      assert_equal options.to_params, posts.with
      response = hijack! posts, 'read/optional'
      parsed = response.parse["tumblr"]["posts"]
      assert_equal "video", parsed["type"]
      assert_equal 5, parsed['post'].count
    end
    
    test 'attempts to perform an authenticated read' do
      reader = Tumblr::Reader
      auth = reader.new('test@testermcgee.com','dontrevealmysecrets').authenticated_read('mwunsch',{:state => :draft})
      response = hijack! auth, 'read/authenticated'
      assert_equal '420292045', response['tumblr']['posts']['post']['id']
    end
    
    test 'sometimes authentication fails' do
      reader = Tumblr::Reader
      auth = reader.new('test@testermcgee.com','dontrevealmysecrets').authenticated_read('mwunsch')
      response = hijack! auth, 'read/authentication failure'
      assert !response.success?
      assert_equal 403, response.code
    end
    
    test 'can not do an authenticated read without credentials' do
      reader = Tumblr::Reader
      assert_raise RuntimeError do 
        reader.new.authenticated_read('mwunsch')
      end
    end
    
    # need to test these more thoroughly
    test 'has several other authenticated read methods' do
      reader = Tumblr::Reader.new
      assert_respond_to reader, :dashboard
      assert_respond_to reader, :likes
      assert_respond_to reader, :like
      assert_respond_to reader, :unlike
    end
  end
  
  describe 'Writer' do
    test 'sets up credentials for authentication' do
      writer = Tumblr::Writer
      params = {:email => 'test@testermcgee.com', :password => 'dontrevealmysecrets'}
      credentials = writer.new(params[:email],params[:password]).defaults
      assert credentials.has_key? :email
      assert credentials.has_key? :password
    end
  
    test 'writes a post' do
      writer = Tumblr::Writer
      assert_respond_to writer.new, :write
      post = {:type => :regular, :body => 'Hello world.', :group => 'tumblrgemtest.tumblr.com'}
      publisher = Tumblr::Writer.new('test@testermcgee.com','dontrevealmysecrets')
      response = hijack! publisher.write(post), 'write/write'
      assert_equal 201, response.code
    end
    
    test 'edits an existing post' do
      assert_respond_to Tumblr::Writer.new, :edit
      publisher = Tumblr::Writer.new('test@testermcgee.com','dontrevealmysecrets')
      post = {:'post-id' => "431830023", :body => 'Hello world?'}
      response = hijack! publisher.edit(post), 'write/edit'
      assert_equal 201, response.code
    end
    
    test 'deletes a post' do
      assert_respond_to Tumblr::Writer.new, :edit
      publisher = Tumblr::Writer.new('test@testermcgee.com','dontrevealmysecrets')
      post = {:'post-id' => "431830023"}
      response = hijack! publisher.delete(post), 'write/delete'
      assert response.success?
      assert_equal 'Deleted', response.body
    end
  end
  
  describe 'Post' do
    describe 'Basic' do
      test 'has a set of post-specific parameters' do
        klass = Class.new(Tumblr::Post)
        assert_respond_to klass, :parameters
        klass.parameters :title, :body
        assert klass.parameters.include? :title
        post = klass.new
        assert_respond_to post, :title
        post.title = 'Hello world'
        assert_equal 'Hello world', post.title
      end
      
      test 'can have a post_id already set' do
        post = Tumblr::Post.new
        assert !post.post_id
        post = Tumblr::Post.new 123
        assert_equal 123, post.post_id
      end
      
      test 'sets a date for publishing in the past' do
        post = Tumblr::Post.new
        assert_respond_to post, :date
        right_now = Time.now.iso8601
        post.date = right_now
        assert_equal right_now, post.date
      end
      
      test 'can be a private post' do
        post = Tumblr::Post.new
        assert_respond_to post, :private?
        assert !post.private?
        post.private = true
        assert post.private?
      end
      
      test 'has a comma separated list of tags' do
        post = Tumblr::Post.new
        assert_respond_to post, :tags
        post.tags :tumblr, :whatever, :ruby
        assert_equal 'tumblr,whatever,ruby', post.tags
      end
      
      test 'can set its format to be html or markdown' do
        post = Tumblr::Post.new
        assert_respond_to post, :format
        post.format = :foobar
        assert !post.format
        post.format = :markdown
        assert_equal :markdown, post.format
      end
      
      test 'can set this post to be published to a secondary blog' do
        post = Tumblr::Post.new
        assert_respond_to post, :group
        post.group = 'mygroup.tumblr.com'
        assert_equal 'mygroup.tumblr.com', post.group
      end
      
      test 'sets a slug for its url' do
        post = Tumblr::Post.new
        assert_respond_to post, :slug
        post.slug = "this-string-right-here"
        assert_equal "this-string-right-here", post.slug
      end
      
      test 'can change published state' do
        post = Tumblr::Post.new
        assert_respond_to post, :state
        post.state = 'queue'
        assert_equal :queue, post.state
        assert_raise RuntimeError do
          post.state = 'foobar'
        end
      end
      
      test 'sends to twitter' do
        post = Tumblr::Post.new
        assert_respond_to post, :send_to_twitter
        assert !post.send_to_twitter
        post.send_to_twitter :no
        assert !post.send_to_twitter
        post.send_to_twitter 'Updating twitter through tumblr'
        assert_equal 'Updating twitter through tumblr', post.send_to_twitter
      end
      
      test 'if the published state is in the queue, specify a publish date' do
        post = Tumblr::Post.new
        assert_respond_to post, :publish_on
        right_now = Time.now.iso8601
        post.publish_on right_now
        assert !post.publish_on
        post.state = :queue
        post.publish_on right_now
        assert_equal right_now, post.publish_on
      end 
    
      test 'converts to a hash' do
        post = Tumblr::Post.new(123)
        post.private = 1
        assert_respond_to post, :to_h
        assert_equal 1, post.to_h[:private]
        assert_equal 123, post.to_h[:'post-id']
        klass = Class.new(post.class)
        klass.parameters :title, :body
        new_post = klass.new(456)
        new_post.title = "Hello world"
        assert_equal 'Hello world', new_post.to_h[:title]
        assert !new_post.to_h.has_key?(:body)
      end
    
      test 'publishes itself on tumblr' do
        klass = Class.new Tumblr::Post
        post = klass.new
        post.instance_variable_set(:@type,:regular)
        assert post.write('test@testermcgee.com','dontrevealmysecrets').is_a? Weary::Request
      end
    end
  
    describe 'Regular' do
      test 'is of regular type' do
        reg = Tumblr::Post::Regular.new
        assert_equal :regular, reg.type
      end
      
      test 'has a body' do
        reg = Tumblr::Post::Regular.new
        assert_respond_to reg, :body
        reg.body = "Hi"
        assert_equal "Hi", reg.body
      end
      
      test 'has a title' do
        reg = Tumblr::Post::Regular.new
        assert_respond_to reg, :title
        reg.title = "Hi"
        assert_equal "Hi", reg.title
      end
    end
  
    describe 'Photo' do
      test 'is a photo' do
        photo = Tumblr::Post::Photo.new
        assert_equal :photo, photo.type
      end
      
      test 'has a source' do
        photo = Tumblr::Post::Photo.new
        photo.source = "http://foo.bar/picture.png"
        assert_equal "http://foo.bar/picture.png", photo.source
      end
      
      test 'has a caption' do
        photo = Tumblr::Post::Photo.new
        photo.caption = "Me in my youth"
        assert_equal "Me in my youth", photo.caption
      end
      
      test 'has a click-through-url' do
        photo = Tumblr::Post::Photo.new
        photo.click_through_url = "http://tumblr.com"
        assert_equal "http://tumblr.com", photo.click_through_url
      end
    end
    
    describe 'Quote' do
      test 'is a quote' do
        quote = Tumblr::Post::Quote.new("To be or not to be")
        assert_equal :quote, quote.type
      end
      
      test 'the quote is text' do
        quote = Tumblr::Post::Quote.new("To be or not to be")
        assert_equal "To be or not to be", quote.quote
        quote.quote = "that is the question."
        assert_equal "that is the question.", quote.quote
      end
      
      test 'the quote has a source' do
        quote = Tumblr::Post::Quote.new("To be or not to be")
        quote.source = "Hamlet"
        assert_equal 'Hamlet', quote.source
      end
    end
    
    describe 'Link' do
      test 'is a link' do
        link = Tumblr::Post::Link.new('http://tumblr.com')
        assert_equal :link, link.type
      end
      
      test 'is a link to something' do
        link = Tumblr::Post::Link.new('http://tumblr.com')
        assert_equal 'http://tumblr.com', link.url
      end
      
      test 'has an optional name' do
        link = Tumblr::Post::Link.new('http://tumblr.com')
        link.name = 'Tumblr'
        assert_equal 'Tumblr', link.name
      end
      
      test 'has an optional description' do
        link = Tumblr::Post::Link.new('http://tumblr.com')
        link.description = "Simple blogging"
        assert_equal 'Simple blogging', link.description
      end
    end
    
    describe 'Conversation' do
      test 'is a conversation' do
        conversation = Tumblr::Post::Conversation.new('Me: hey whatsup')
        assert_equal :conversation, conversation.type
      end
      
      test 'requires a chat' do
        conversation = Tumblr::Post::Conversation.new('Me: hey whatsup')
        assert_equal 'Me: hey whatsup', conversation.conversation
      end
      
      test 'has an optional title' do
        conversation = Tumblr::Post::Conversation.new('Me: hey whatsup')
        conversation.title = 'Inner dialogue'
        assert_equal 'Inner dialogue', conversation.title
      end
    end
    
    describe 'Video' do
      test 'is a video' do
        video = Tumblr::Post::Video.new('http://www.youtube.com/watch?v=CW0DUg63lqU')
        assert_equal :video, video.type
      end
      
      test 'has a url or embed code' do
        video = Tumblr::Post::Video.new('http://www.youtube.com/watch?v=CW0DUg63lqU')
        assert_equal 'http://www.youtube.com/watch?v=CW0DUg63lqU', video.embed
      end
      
      test 'has a caption' do
        video = Tumblr::Post::Video.new('http://www.youtube.com/watch?v=CW0DUg63lqU')
        video.caption = 'Good artists copy...'
        assert_equal 'Good artists copy...', video.caption
      end
    end
    
    describe 'Audio' do
      test 'is audio' do
        audio = Tumblr::Post::Audio.new
        assert_equal :audio, audio.type
      end
      
      test 'can be a hosted url to an mp3 file' do
        audio = Tumblr::Post::Audio.new
        audio.externally_hosted_url = 'http://foobar.com/some.mp3'
        assert_equal 'http://foobar.com/some.mp3', audio.externally_hosted_url
      end
      
      test 'has an optional caption' do
        audio = Tumblr::Post::Audio.new
        audio.caption = 'not pirated'
        assert_equal 'not pirated', audio.caption
      end
    end
  end
end
