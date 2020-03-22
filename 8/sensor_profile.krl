ruleset sensor_profile {
  meta {
    logging on
    shares profile_updated, profile, __testing
    provides sensor_location, sensor_name, threshold_temperature, sms_number, profile
    use module twilio_api_keys
    use module twilio_api
      with account_sid = keys:twilio{"account_sid"}
        auth_token = keys:twilio{"auth_token"}
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing" }, {"name": "profile"}],
                "events": [ { "domain": "sensor", "type": "profile_updated" }, 
                            {"domain": "sensor", "type": "reset_profile" } ] }
    
    sensor_location = function() {
      location = ent:sensor_location.defaultsTo("Provo, UT")
      location
    }
    
    sensor_name = function() {
      name = ent:sensor_name.defaultsTo("Wovyn Device")
      name
    }
    
    threshold_temperature = function() {
      threshold = ent:threshold_temperature.defaultsTo(85)
      threshold
    }
    
    sms_number = function() {
      number = ent:sms_number.defaultsTo("+18017848121")
      number
    }
    
    profile = function() {
      profile = {"location": sensor_location(), "name": sensor_name(), "threshold": threshold_temperature(), "number": sms_number()}
      profile
    }
  }
   
  rule profile_updated {
    select when sensor profile_updated
    pre {
      location = event:attrs.get("location") == "" || event:attrs.get("location").isnull() 
        => "Provo, UT" | event:attrs.get("location")
      name = event:attrs.get("name") == "" || event:attrs.get("name").isnull()
        => "Wovyn Device" | event:attrs.get("name")
      threshold = event:attrs.get("threshold") == "" || event:attrs.get("threshold").isnull() 
        => 85 | event:attrs.get("threshold").as("Number")
      parsed_number = event:attrs.get("number") == "" || event:attrs.get("number").isnull() 
        => "+18017848121" | event:attrs.get("number")
      number = parsed_number.substr(0, 1) == "+" => parsed_number | "+" + parsed_number
    }
    noop()
    always{
      ent:sensor_location := ent:sensor_location.defaultsTo("Provo, UT")
      ent:sensor_location := location
      ent:sensor_name := ent:sensor_name.defaultsTo("Wovyn Device")
      ent:sensor_name := name
      ent:threshold_temperature := ent:threshold_temperature.defaultsTo(85)
      ent:threshold_temperature := threshold
      ent:sms_number := ent:sms_number.defaultsTo("+18017848121")
      ent:sms_number := number
    }
  }
  
  rule reset_profile {
    select when sensor reset_profile
    noop()
    always{
      ent:sensor_location := "Provo, UT"
      ent:sensor_name := "Wovyn Device"
      ent:threshold_temperature := 85
      ent:sms_number := "+18017848121"
    }
  }
  
}