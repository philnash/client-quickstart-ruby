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
  twiml = Twilio::TwiML::Response.new do |r|
    if params['To'] and params['To'] != ''
      r.Dial callerId: ENV['TWILIO_CALLER_ID'], action: "/holding" do |d|
        # wrap the phone number or client name in the appropriate TwiML verb
        # by checking if the number given has only digits and format symbols
        if params['To'] =~ /^[\d\+\-\(\) ]+$/
          d.Number params['To']
        else
          d.Client params['To']
        end
      end
    else
      r.Say "Thanks for calling!"
    end
  end

  content_type 'text/xml'
  twiml.text
end

post '/hold/:call_sid' do
  parent_call_sid = params[:call_sid]
  child_call = client.calls.list(:parent_call_sid => parent_call_sid).first
  child_call.update(:url => "http://philnash.ngrok.io/enqueue")
  200
end

post '/holding' do
  twiml = Twilio::TwiML::Response.new do |r|
    r.Say 'You have a caller on hold...'
    r.Redirect '/holding'
  end
  content_type 'text/xml'
  twiml.text
end

post '/enqueue' do
  twiml = Twilio::TwiML::Response.new do |r|
    r.Enqueue "ON_HOLD", waitUrl: "http://twimlets.com/holdmusic?Bucket=com.twilio.music.guitars"
  end
  content_type 'text/xml'
  twiml.text
end

post '/reconnect/:call_sid' do
  client.calls.get(params[:call_sid]).update(:url => 'http://philnash.ngrok.io/dequeue')
  200
end

post '/dequeue' do
  twiml = Twilio::TwiML::Response.new do |r|
    r.Dial action: "/holding" do |d|
      d.Queue "ON_HOLD"
    end
  end
  content_type 'text/xml'
  twiml.text
end
