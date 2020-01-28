ruleset twilio_api {
  meta {
    logging on
    configure using account_sid = ""
    	auth_token = ""
    provides send_message
  }
   
  global {
    send_message=defaction(source, destination, message) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
      http:post(base_url + "Messages.json", form = {
                "From":source,
                "To":destination,
                "Body":message
            })
    }
  }
}
