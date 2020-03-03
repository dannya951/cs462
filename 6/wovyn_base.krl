ruleset wovyn_base {
  meta {
    logging on
    shares process_heartbeat, __testing
    use module sensor_profile
    use module twilio_api_keys
    use module twilio_api
      with account_sid = keys:twilio{"account_sid"}
        auth_token = keys:twilio{"auth_token"}
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing" } ],
                "events": [ { "domain": "wovyn", "type": "heartbeat",
                              "attrs": ["genericThing"] } ] }
    source_number = "+15034064270"
  }
   
  rule process_heartbeat {
    select when wovyn heartbeat where not event:attr("genericThing").isnull()
    pre{
      genericThing = event:attrs.get(["genericThing"]).decode()
      data = genericThing.get(["data"]).decode()
      temperature = data.get(["temperature"]).decode().head()
      timestamp = time:now()
    }
    //send_directive("Heartbeat Received")
    noop()
    fired{
      raise wovyn event "new_temperature_reading"
        attributes {
          "temperature": temperature,
          "timestamp": timestamp
        }
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre{
      temperature = event:attrs.get(["temperature"]).decode()
      temperature_value = temperature.get(["temperatureF"])
      exceeded_temp = temperature_value > sensor_profile:threshold_temperature()
      directive_message = exceeded_temp => "Temperature Threshold Exceeded" | "Temperature at or Below Threshold"
    }
    //send_directive("Temperature Status", {"Message": directive_message})
    noop()
    always{
      raise wovyn event "threshold_violation"
        attributes {
          "temperature": event:attrs.get(["temperature"]),
          "timestamp": event:attrs.get(["timestamp"])
        } if exceeded_temp
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      temperature = event:attrs.get(["temperature"]).decode()
      temperature_value = temperature.get(["temperatureF"])
      timestamp = event:attrs.get(["timestamp"]).decode()
      message = "Temperature Threshold Exceeded; Temperature at " + timestamp + ": " + temperature_value + " Degrees"
      dest_number = sensor_profile:sms_number()
    }
    // twilio_api:send_message(source_number, dest_number, message)
    // send_directive("Temperature Threshold Alert", {"Message": message})
    noop()
  }
  
}