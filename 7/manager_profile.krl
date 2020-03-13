ruleset manager_profile {
  meta {
    logging on
    shares profile_updated, reset_profile, threshold_notification, sms_number, __testing
    // provides sms_number
    use module twilio_api_keys
    use module twilio_api
      with account_sid = keys:twilio{"account_sid"}
        auth_token = keys:twilio{"auth_token"}
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing" }, {"name": "sms_number"}],
                "events": [ { "domain": "manager", "type": "profile_updated", 
                              "attrs": ["number"] }, 
                            {"domain": "manager", "type": "reset_profile" },
                            {"domain": "manager", "type": "threshold_violation", 
                              "attrs": ["message"] } , 
                            {"domain": "manager", "type": "sms_message", 
                              "attrs": ["source_number", "dest_number", "message" ] } ] }

    sms_number = function() {
      number = ent:sms_number.defaultsTo("+19519651576")
      number
    }

    source_number = function() {
      "+15034064270"
    }
  }
   
  rule profile_updated {
    select when manager profile_updated
    pre {
      parsed_number = event:attrs.get("number") == "" || event:attrs.get("number").isnull() 
        => "+19519651576" | event:attrs.get("number")
      number = parsed_number.substr(0, 1) == "+" => parsed_number | "+" + parsed_number
    }
    noop()
    always{
      ent:sms_number := ent:sms_number.defaultsTo("+19519651576")
      ent:sms_number := number
    }
  }
  
  rule reset_profile {
    select when manager reset_profile
    noop()
    always{
      ent:sms_number := "+19519651576"
    }
  }
  
  rule threshold_notification {
    select when manager threshold_violation
    pre {
      source_number = source_number()
      dest_number = sms_number()
      message = event:attrs.get("message").defaultsTo("No Message Provided.")
    }
    if source_number && dest_number && message then noop()
    fired {
      raise manager event "sms_message"
        attributes {"source_number": source_number, "dest_number": dest_number, "message": message}
    }
  }
  
  rule notification_message {
    select when manager sms_message
    twilio_api:send_message(event:attrs.get("source_number"), event:attrs.get("dest_number"), event:attrs.get("message"))
  }
  
}