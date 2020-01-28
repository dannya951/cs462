ruleset twilio_app {
  meta {
    logging on
    shares send_sms
    use module twilio_api_keys
    use module twilio_api
      with account_sid = keys:twilio{"account_sid"}
        auth_token = keys:twilio{"auth_token"}
  }
   
  global {
  }
   
  rule send_sms {
    select when twilio send
    pre {
      source = (event:attr("source") == "" || event:attr("source").isnull() => "+15034064270" | ("+1"+event:attr("source"))).klog("Source: ")
      dest = (event:attr("dest") == "" || event:attr("dest").isnull() => "+18017848121" | ("+1"+event:attr("dest"))).klog("Destination: ")
      message = (event:attr("message") == "" || event:attr("message").isnull() => "This message was sent through Twilio for Lab 2" | (event:attr("message"))).klog("Message: ")
    }
    twilio_api:send_message(source, dest, message)
  }
   
}
