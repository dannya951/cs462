ruleset temperature_store {
  meta {
    logging on
    shares temperatures, threshold_violations, inrange_temperatures, current_temperature, __testing
    provides temperatures, threshold_violations, inrange_temperatures, current_temperature
    use module twilio_api_keys
    use module twilio_api
      with account_sid = keys:twilio{"account_sid"}
        auth_token = keys:twilio{"auth_token"}
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing" }, {"name": "temperatures"}, 
                {"name": "threshold_violations"}, {"name": "inrange_temperatures"}, 
                {"name": "current_temperature"} ],
                "events": [ { "domain": "sensor", "type": "reading_reset" } ] }
                
    current_temperature = function() {
      len = temperatures().length()
      temp = len > 0 => temperatures()[len -1]["temperature"] | ent:temp.defaultsTo("No Reading Yet")
      temp
    }
    
    temperatures = function() {
      readings = ent:readings.defaultsTo([])
      readings
    }
    
    threshold_violations = function() {
      violations = ent:violations.defaultsTo([])
      violations
    }
    
    inrange_temperatures = function() {
      inrange = ent:readings.defaultsTo([]).difference(ent:violations.defaultsTo([]))
      inrange
    }
  }
   
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      temperature = event:attrs.get("temperature")
      temperature_value = temperature.get("temperatureF")
      timestamp = event:attrs.get("timestamp")
      message = ("Temperature at " + timestamp + ": " + temperature_value + " Degrees")
        .klog("New Reading Message: ")
    }
    // temperatureF
    //send_directive("Collected New Temperature Reading", {"Message": message})
    noop()
    always{
      ent:readings := ent:readings.defaultsTo([])
      ent:readings := ent:readings.append({"temperature": temperature_value, "timestamp": timestamp})
      ent:temp := ent:temp.defaultsTo("No Reading Yet")
      ent:temp := temperature_value
    }
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      temperature = event:attrs.get("temperature")
      temperature_value = temperature.get("temperatureF")
      timestamp = event:attrs.get("timestamp")
      message = ("Temperature at " + timestamp + ": " + temperature_value + " Degrees")
        .klog("Threshold Violation Message: ")
    }
    //send_directive("Received New Threshold Violation", {"Message": message})
    noop()
    always{
      ent:violations := ent:violations.defaultsTo([])
      ent:violations := ent:violations.append({"temperature": temperature_value, "timestamp": timestamp})
    }
  }
  
  rule clear_temeratures {
    select when sensor reading_reset
    noop()
    always{
      ent:readings := []
      ent:violations := []
      ent:temp := "No Reading Yet"
    }
  }
  
}