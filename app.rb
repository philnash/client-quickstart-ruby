require 'twilio-ruby'
require 'sinatra'
require 'sinatra/json'
require 'dotenv'
require 'faker'

# Load environment configuration
Dotenv.load

# Create Twilio Client
def client
  @client ||= Twilio::REST::Client.new(ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"])
end

# Render home page
get '/' do
  File.read(File.join('public', 'index.html'))
end

# Generate a token for use in our Video application
get '/token' do
  # Create a random username for the client
  identity = Faker::Internet.user_name.gsub(/[^0-9a-z_]/i, '')

  capability = Twilio::Util::Capability.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']
  # Create an application sid at
  # twilio.com/console/phone-numbers/dev-tools/twiml-apps and use it here
  capability.allow_client_outgoing ENV['TWILIO_TWIML_APP_SID']
  capability.allow_client_incoming identity
  token = capability.generate

  # Generate the token and send to client
  json :identity => identity, :token => token
end

post '/voice' do
  content_type 'text/xml'
  "
  <Response>
    <Dial callerId='#{ENV['TWILIO_CALLER_ID']}' action='/holding'>
      <Number>#{params['To']}</Number>
    </Dial>
  </Response>
  "
end

post '/hold/:call_sid' do
  # Get the caller's Call Sid. This is the Twilio Client side
  parent_call_sid = params[:call_sid]
  # Find the child call, this is the caller on the phone
  child_call = client.calls.list(:parent_call_sid => parent_call_sid).first
  # Redirect the child call to the TwiML to enqueue it
  child_call.update(:url => "http://philnash.ngrok.io/enqueue")
  200
end

post '/holding' do
  content_type 'text/xml'
  "
  <Response>
    <Say>You have a caller on hold...</Say>
    <Redirect>/holding</Redirect>
  </Response>
  "
end

post '/enqueue' do
  content_type 'text/xml'
  "
  <Response>
    <Enqueue waitUrl='http://twimlets.com/holdmusic?Bucket=com.twilio.music.guitars'>ON_HOLD</Enqueue>
  </Response>
  "
end

post '/reconnect/:call_sid' do
  # Again, we use the Twilio Client call sid, but this time we direct the call
  # to dial the queue where our caller who is on hold is.
  client.calls.get(params[:call_sid]).update(:url => 'http://philnash.ngrok.io/dequeue')
  200
end

post '/dequeue' do
  content_type 'text/xml'
  "
  <Response>
    <Dial action='/holding'>
      <Queue>ON_HOLD</Queue>
    </Dial>
  </Response>
  "
end
