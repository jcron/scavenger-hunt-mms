# MMS based Scavenger hunt using Sinatra and Twilio MMS.

# install postgres
# (on mac)
brew install postgres

# install gems
bundle install

# start postgres
postgres -D /usr/local/var/postgres/

# create database for program (only done once)
createdb scavenger

# setup env variables
export TWILIO_NUMBER=<number>
export TWILIO_ACCOUNT_SID=<account_sid>
export TWILIO_AUTH_TOKEN=<token>

# run sinatra app
ruby ./app.rb

# if dev, ngrok it
ngrok -subdomain=scavenger 4567

# setup twilio text message url as http://scavenger.ngrok.com/scavenger
# start hunt


### bug when recovering from injury - doesn't count that clue as completed
### bug printing fastest time in final text message - came as blank
