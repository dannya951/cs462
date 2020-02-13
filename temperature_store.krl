ruleset temperature_store {
  meta {
    logging on
    shares temperatures, threshold_violations, inrange_temperatures, __testing
    provides temperatures, threshold_violations, inrange_temperatures
    use module twilio_api_keys
    use module twilio_api
      with account_sid = keys:twilio{"account_sid"}
        auth_token = keys:twilio{"auth_token"}
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing" }, {"name": "temperatures"}, 
                {"name": "threshold_violations"}, {"name": "inrange_temperatures"} ],
                "events": [ { "domain": "sensor", "type": "reading_reset" } ] }
    
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
      temperature = event:attrs.get(["temperature"]).decode()
      temperature_value = temperature.get(["temperatureF"])
      timestamp = event:attrs.get(["timestamp"]).decode()
      message = "Temperature at " + timestamp + ": " + temperature_value + " Degrees"
    }
    //send_directive("Collected New Temperature Reading", {"Message": message})
    noop()
    always{
      ent:readings := ent:readings.defaultsTo([])
      ent:readings := ent:readings.append({"temperature": temperature_value, "timestamp": timestamp})
    }
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      temperature = event:attrs.get(["temperature"]).decode()
      temperature_value = temperature.get(["temperatureF"])
      timestamp = event:attrs.get(["timestamp"]).decode()
      message = "Temperature at " + timestamp + ": " + temperature_value + " Degrees"
    }
    send_directive("Received New Threshold Violation", {"Message": message})
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
    }
  }
  
}