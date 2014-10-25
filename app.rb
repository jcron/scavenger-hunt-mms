require "bundler/setup"
require "sinatra"
require "sinatra/multi_route"
require "data_mapper"
require "twilio-ruby"
require 'twilio-ruby/rest/messages'
require "sanitize"
require "erb"
require "rotp"
require "haml"
require "pry"
include ERB::Util

# Using DataMapper for our psql data manager
DataMapper::Logger.new(STDOUT, :debug)
DataMapper::setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/scavenger')

class Player
  include DataMapper::Resource

  property :id, Serial
  property :phone_number, String, :length => 30, :required => true
  property :name, String
  property :current, String
  property :status, Enum[ :new, :naming, :playing, :hunting, :clue1, :clue2, :clue3, :clue4, :clue5, :clue6, :clue7, :clue8, :clue9, :clue10, :clue11, :clue12, :clue13, :injured], :default => :new
  property :fastest, Float
  property :time_complete, Time, :default => Time.now
  property :missed, Integer, :default => 0
  property :complete, Integer, :default => 0
  property :remaining, Object
  property :injured, Time, :default => Time.now

end

DataMapper.finalize
DataMapper.auto_upgrade!

# Load up our necessary requirements before each function
before do
  @url = 'http://scavenger.ngrok.com/img/' # replace this below
  @twilio_number = ENV['TWILIO_NUMBER']
  @client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  if params[:error].nil?
    @error = false
  else
    @error = true
  end

end

_INJUREDWORDS = ['farted on by a deadly fart beetle', 'eaten by a hippopotamus', 'rubbed with poison ivy', 'stuck by a cactus', 'licked by a cat with thirty hepatitis tongues', 'kissed by a girl with dandruff', 'swallowed by a sink hole', 'kidnapped by jungle rebels with nerf guns', 'beaten by a blind and deaf troll', 'turned into a gnewt', 'hit with a flying gerbil', 'ran over by a deer driving a minivan', 'cast in the next star wars as a dead Gornt']

set :static, true

$CLUES = {
  "clue1" => {
    "keyword" => 'boygeorge',
    "title" => 'Humdinger of a clue',
    "url" => 'http://scavenger.ngrok.com/img/clue01.jpg'
  },
  "clue2" => {
    "keyword" => 'scumbucket',
    "title" => 'Let this clue float in your head for a bit.',
    "url" => 'http://scavenger.ngrok.com/img/clue02.jpg'
  },
  "clue3" => {
    "keyword" => 'billieidol',
    "title" => 'Wood you be my neighbor?',
    "url" => 'http://scavenger.ngrok.com/img/clue03.jpg'
  },
  "clue4" => {
    "keyword" => 'erasure',
    "title" => 'Time to hunt!',
    "url" => 'http://scavenger.ngrok.com/img/clue04.jpg'
  },
  "clue5" => {
    "keyword" => 'blondie',
    "title" => 'Can you handle this?',
    "url" => 'http://scavenger.ngrok.com/img/clue05.jpg'
  },
  "clue6" => {
    "keyword" => 'cinderella',
    "title" => 'Your days are numbered...',
    "url" => 'http://scavenger.ngrok.com/img/clue06.jpg'
  },
  "clue7" => {
    "keyword" => 'joejackson',
    "title" => 'Your inability to find these clues is grating on me.',
    "url" => 'http://scavenger.ngrok.com/img/clue07.jpg'
  },
  "clue8" => {
    "keyword" => 'onedirection',
    "title" => 'Your progress is a bad sign.',
    "url" => 'http://scavenger.ngrok.com/img/clue08.jpg'
  },
  "clue9" => {
    "keyword" => 'wildfire',
    "title" => 'Wash away your fears',
    "url" => 'http://scavenger.ngrok.com/img/clue09.jpg'
  },
  "clue10" => {
    "keyword" => 'slowmo',
    "title" => 'Are you getting tired of this?',
    "url" => 'http://scavenger.ngrok.com/img/clue10.jpg'
  },
  "clue11" => {
    "keyword" => 'dummy',
    "title" => 'The wicked clue is dead?',
    "url" => 'http://scavenger.ngrok.com/img/clue11.jpg'
  },
  "clue12" => {
    "keyword" => 'fakeplastic',
    "title" => 'Rock on dude!',
    "url" => 'http://scavenger.ngrok.com/img/clue12.jpg'
  },
  "clue13" => {
    "keyword" => 'menatwork',
    "title" => 'Keep looking!',
    "url" => 'http://scavenger.ngrok.com/img/clue13.jpg'
  },
  "clue14" => {
    "keyword" => 'duran',
    "title" => 'Dont lean on your senses.',
    "url" => 'http://scavenger.ngrok.com/img/clue14.jpg'
  },
  "clue15" => {
    "keyword" => 'jazzyjeff',
    "title" => 'Let cooler heads prevail.',
    "url" => 'http://scavenger.ngrok.com/img/clue15.jpg'
  },
}

get '/scavenger/?' do
  # Decide what do based on status and body
  @phone_number = Sanitize.clean(params[:From])
  @body = params[:Body].downcase

  # Find the user associated with this number if there is one
  @player = Player.first(:phone_number => @phone_number)

  # if the user doesn't exist create a new user.
  if @player.nil?
    # for the time being we create the code at the start of the game
    # TODO - Instead of creating user with code, allow user to submit their code to the listener as first step of signup. Then we assign code to user at the Real-world Event. That way we can hand out stickers, badges, with the code pre-written. 
    @player = create_user(@phone_number)
  end

  begin
    # this is our main game trigger, depending on users status in the game, respond appropriately
    status = @player.status
    case status

    # Setup the player details
    when :new
      output = "Welcome to the Twilio MMS scavenger hunt. First what is your super awesome nickname?"
      @player.update(:status => 'naming')

    # Get User Name
    when :naming
      if @player.name.nil?
        @player.name = @body
        @player.save
        output = "We have your nickname as #{@body}. Is this correct? [yes] or [no]?"
      else
        if @body == 'yes'
          puts "RECEIVED MESSAGE of YES"
          output = "Ok #{@player.name}, time to go find your first clue! You should receive a picture of it shortly. Once you find the object send back the word clue to this number."
          @player.update(:status => 'hunting')
          send_next_clue(@player)
        else
          output = "Okay safari dude. What is your nickname then?"
          @player.update(:name => nil)
        end
      end

    when :playing
        currentTime = Time.now
        if @player.injured > currentTime
          output = "Looks like you are still injured. Come back once you've healed."
        else
          output = "Hiddey Ho #{@player.name}, you look a little messed up from your injury, you should probably get that checked out. Anyway, here is the next picture clue!"
          @player.update(:status => 'hunting')
          send_next_clue(@player)
        end

    # When the user is hunting
    when :hunting
        currentTime = Time.now
        if @player.injured > currentTime
          output = "Looks like you are still injured. Come back once you've healed."
        else
          # check the attacker isn't injured
          current = @player.current
          remaining = @player.remaining
          clue = $CLUES[current]

          remaining = remaining.split(',')

          if @body == clue['keyword']
            # Score this point
            complete = @player.complete + 1

            # Check time and set fastest
            completed_time = time_diff(@player.time_complete, currentTime)
            if @player.fastest.nil?  
              @player.update(:fastest => completed_time)
            else
              if completed_time < @player.fastest
                @player.update(:fastest => completed_time)
              end
            end

            # Remove the clue that was just completed
            remaining.delete(current)

            # UPDATE THE USER
            @player.update(:complete => complete, :remaining => remaining.join(','), :time_complete => currentTime)
            if remaining.length == 0
              minutes = @player.fastest / 60
              output = "Congratulations #{@player.name}! You've finished the game and found #{@player.complete} clues! Your fastest time was #{minutes} minutes, which is pretty good! Now just wait for the others to finish and a special rewards ceremony."
            else
              output = "Well done #{@player.name}! You've just found a treasure! Now here's the next clue!"
              
              # Get next clue and send it.
              send_next_clue(@player)
            end

          else
            missed = @player.missed
            missed = missed + 1
            a = rand(0.._INJUREDWORDS.length)
            injuredStr = _INJUREDWORDS[a]
            output = "Oh no #{@player.name}! You were just #{injuredStr}! That means you can not submit another clue for 1 minute. PRO TIP: Don't just submit the first clue you find. Look around the area to find a clue that is hidden better."
            injuredTime = Time.now + 1*60
            @player.update(:status => 'playing', :injured => injuredTime, :missed => missed)
          end
        end
    end
  rescue
    output = "there was a user.status error."
  end

  if params['SmsSid'] == nil
    return nil
  else
    response = Twilio::TwiML::Response.new do |r|
      r.Sms output
    end
    response.text
  end
end

def send_next_clue(user)
  remaining = user.remaining
  remaining = remaining.split(',')

  l = remaining.length
  next_clue = remaining[rand(l)]

  clue = $CLUES[next_clue]
  puts $CLUES

  send_picture(@phone_number, clue['title'], clue['url'])

  @player.update(:current => next_clue)
end

def time_diff(start_time, end_time)
  (start_time - end_time).to_i.abs
end

def get_random_step
  num = rand(12)
  "clue#{num}"
end

def send_picture(to, msg, media)
  message = @client.account.messages.create(
    :from => ENV['TWILIO_NUMBER'],
    :to => @phone_number,
    :body => msg,
    :media_url => media,
  ) 
  puts message.to
end

def create_user(phone_number)
  @available_clues = ["clue1", "clue2", "clue3", "clue4", "clue5", "clue6", "clue7", "clue8", "clue9", "clue10", "clue11", "clue12", "clue13", "clue14", "clue15"]
  clues = @available_clues.join(',')
  user = Player.create(
    :phone_number => phone_number,
    :remaining => clues,
  )
  user.save
  user
end

get "/" do
  haml :index
end

get '/users/?' do
  @players = Player.all
  haml :users
end