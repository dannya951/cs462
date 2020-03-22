ruleset wovyn_base {
  meta {
    logging on
    shares process_heartbeat, __testing
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
    use module sensor_profile
    use module temperature_store
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
  
  rule async_temperature {
    select when wovyn temperature_requested
    pre {
      response_eci = event:attrs.get("response_eci")
      name = event:attrs.get("name")
      corr_ID = event:attrs.get("corr_ID")
      response_event_domain = event:attrs.get("response_event_domain")
      response_event_type = event:attrs.get("response_event_type")
      Tx_host = event:attrs.get("Rx_host")
      temperature = temperature_store:current_temperature()
      attrs = {"name": name, "corr_ID": corr_ID, "temperature": temperature}
    }
    event:send(
      {"eci": response_eci, "domain": response_event_domain, 
        "type": response_event_type, "attrs": attrs}, host=Tx_host)
  }
   
  rule process_heartbeat {
    select when wovyn heartbeat where not event:attr("genericThing").isnull()
    pre{
      genericThing = event:attrs.decode().get("genericThing").decode()// .klog("Generic Thing Input: ")
      data = genericThing.get("data").decode()
      temperature_str = data.get("temperature").decode().head().klog("Temperature Value: ")
      temp_name = temperature_str.get("name").decode()
      temp_f = temperature_str.get("temperatureF").decode().as("Number")
      temperature = {}.put("name", temp_name).put("temperatureF", temp_f)
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
      temperature = event:attrs.get("temperature")
      temperature_value = temperature.get("temperatureF")
      exceeded_temp = temperature_value > sensor_profile:threshold_temperature()
      directive_message = exceeded_temp => "Temperature Threshold Exceeded" | "Temperature at or Below Threshold"
    }
    //send_directive("Temperature Status", {"Message": directive_message})
    noop()
    always{
      raise wovyn event "threshold_violation"
        attributes {
          "temperature": event:attrs.get("temperature"),
          "timestamp": event:attrs.get("timestamp")
        } if exceeded_temp
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      temperature = event:attrs.get("temperature")
      temperature_value = temperature.get("temperatureF")
      timestamp = event:attrs.get("timestamp")
      message = "Temperature at Sensor " + sensor_profile:sensor_name() + " Exceeded Threshold Temperature of " + sensor_profile:threshold_temperature() + " Degrees at " + timestamp + "; Temperature was " + temperature_value + " Degrees."
      dest_number = sensor_profile:sms_number()
      
      manager_sub_info = Subscriptions:established("Rx_role", "sensor").filter(function(v){v.get("Tx_role") == "sensor_manager"}).head()
        // .klog("***** Manager Subscription Info *****: ")
      manager_Tx_host = manager_sub_info.get("Tx_host")
        // .klog("***** Manager Tx host *****: ")
    }
    // twilio_api:send_message(source_number, dest_number, message)
    // send_directive("Temperature Threshold Alert", {"Message": message})
    if manager_sub_info && manager_Tx_host then noop()
    fired {
      // Tx = manager_sub_info.get("Tx")
      // Tx_host = manager_sub_info.get("Tx_host")
      Id = manager_sub_info.get("Id")
      raise wrangler event "send_event_on_subs" attributes {
        "domain": "manager", "type": "threshold_violation", "subID": Id, 
        "attrs": {"message": message} }
    }
  }
  
  /*
  {
    "Rx_role": "sensor",
    "Tx_role": "sensor_manager",
    "Tx_host": "http://192.168.1.21:8080",
    "Id": "ck7p8j0y6003w7yjx0flx17oo",
    "Tx": "YAiUyFWzwA3az11YT1NZeV",
    "Rx": "MBtFT3gPoQXfud2ygYjRYc",
    "Tx_verify_key": "HzGScHvVNyDi9p4MqwZALnRxUVcbULYx8jmKB6mFAKVx",
    "Tx_public_key": "67xB6w3wA7Jt1UMiz7FAJLrAUv2rrYCnXt8f1LzomNvV"
  }
  */
  // { "name": "established" /*,"args":["key","value"]*/}
  /*
  ent:established [
    {
      "Tx":"", //The channel identifier this pico will send events to
      "Rx":"", //The channel identifier this pico will be listening and receiving events on
      "Tx_role":"", //The subscription role or purpose that the pico on the other side of the subscription serves
      "Rx_role":"", //The role this pico serves, or this picos purpose in relation to the subscription
      "Tx_host": "" //the host location of the other pico if that pico is running on a separate engine
      "Tx_verify_key": ,
      "Tx_public_key":
    },...,...
  ]
  */
  
  rule auto_accept {
    // In the future, we may want to verify that the subscription request is 
    // coming from the sensor_manager pico.
    select when wrangler inbound_pending_subscription_added
    noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
}