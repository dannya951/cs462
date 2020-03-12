ruleset manage_sensors {
  meta {
    logging on
    shares sensor_added, sensor_removed, subscription_sensors, temperatures, subscription_requested, __testing
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing"}, {"name": "subscription_sensors" }, {"name": "temperatures"}],
                "events": [{ "domain": "sensor", "type": "new_sensor", "attrs": ["name"] }, 
                  {"domain": "sensor", "type": "unneeded_sensor", "attrs": ["name"] }, 
                  {"domain": "manager", "type": "subscription", 
                    "attrs": ["name", "Tx_host", "wellKnown_Tx", "Rx_role", 
                    "Tx_role", "channel_type"]}] }
                
    threshold_temperature = function() {
      threshold = ent:threshold_temperature.defaultsTo(100)
      threshold
    }
    
    sms_number = function() {
      number = ent:sms_number.defaultsTo("+19519651576")
      number
    }
    
    
    subscription_sensors = function() {
      subscription_sensors = Subscriptions:established("Tx_role", "sensor")
      subscription_sensors
    }
    
    
    temperatures = function() {
      temperature_map = subscription_sensors().map(
        function(eci,name) {
          temperature = wrangler:skyQuery(eci, "temperature_store", "current_temperature", [])
          temperature
        }
      )
      temperature_map
    }
  }
   
  rule sensor_added {
    select when sensor new_sensor
    pre {
      // The lab specifies that the name must come from the event attributes;
      // if no name is provided, we will enforce that no new child pico can be 
      // created.
      name_provided = (event:attr("name") == "" || event:attr("name").isnull()) 
        => false | true
      name = name_provided => event:attr("name") | "default name"
      
      name_unique = not(ent:subscription_values.defaultsTo({}).keys() >< name)
    }
    
    //name not provided or name not unique
    if not name_provided || not name_unique then
      send_directive("Could not create new child pico", 
        {"name_provided": name_provided, "name_unique": name_unique})
    
    notfired{
      // name provided and name_unique
      ent:subscription_values := ent:subscription_values.defaultsTo({}).put(name, "subscription_placeholder")
      ent:child_sensors := ent:child_sensors.defaultsTo({}).put(name, "eci_placeholder")
      raise wrangler event "child_creation"
        attributes {"name": name, "rids": ["temperature_store", "wovyn_base", "sensor_profile"]}
    }
  }
  
  rule child_initialized {
    select when wrangler child_initialized
    pre {
      name = event:attr("name")
      
      // The lab specifies that the threshold must come from a default value.   
      threshold = threshold_temperature() 
      
      // The lab makes no requirement with regard to where the number must come 
      // from, so we'll just provide it in a default value (like the threshold).
      number = sms_number()
      
      // The child ECI is included in the child_initialized event attributes.
      eci = event:attr("eci")
      
      profile_update_map = {"name": name, "threshold": threshold, "number": number}
      
      Tx_host = event:attr("_headers").get("host")
    }
    
    // Call updated_profile event on child sensor pico to update name, threshold, 
    // and number.
    if ent:child_sensors >< name then
      event:send({"eci": eci, "eid": "update_profile", "domain": "sensor", 
        "type": "profile_updated", "attrs": profile_update_map})
    
    //send_directive("Registered child sensor pico with parent")
    
    fired {
      // Update the sensors entity variable so that the child pico's name maps 
      // to its eci.
      ent:child_sensors := ent:child_sensors.defaultsTo({}).put(name, eci)
      
      // Establish subscription for new child sensor pico.
      raise manager event "subscription"
        attributes {"Tx_host": Tx_host, "name": name, "wellKnown_Tx": eci, 
          "Tx_role": "sensor"}
    }
  }
  
  rule sensor_removed {
    select when sensor unneeded_sensor
    pre {
      name_provided = (event:attr("name") == "" || event:attr("name").isnull()) 
        => false | true
      name = name_provided => event:attr("name") | "default name"
      name_exists = ent:subscription_values.defaultsTo({}).keys() >< name
    }
    if not name_provided || not name_exists then
      send_directive("Could not remove unneeded sensor", {"sensor_name": name})
    notfired {
      // Remove the subscription before deleting the corresponding sensor pico.
      raise manager event "unneeded_subscription" 
        attributes {"name": name}
      
      raise wrangler event "child_deletion"
        attributes {"name": name}
      ent:child_sensors := ent:child_sensors.defaultsTo({}).delete(name)
    }
  }
  
  rule subscription_removed {
    select when manager unneeded_subscription
      pre {
        name = event:attr("name")
        name_present = ent:subscription_values.defaultsTo({}) >< name
        name_subscription = ent:subscription_values.get(name)
        Tx_present = name_subscription >< "Tx"
        Tx = name_subscription.get("Tx")
      }
    if name_present && Tx_present then noop()
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Tx": Tx}
      ent:subscription_values := ent:subscription_values.defaultsTo({}).delete(name)
    }
  }
  
  rule subscription_requested {
    select when manager subscription
    pre {
      Tx_host_non_null = event:attr("Tx_host") == "" || event:attr("Tx_host").isnull() => 
        meta:host | event:attr("Tx_host")
      Tx_host = Tx_host_non_null.substr(0,7) != "http://" => 
        "http://" + Tx_host_non_null | Tx_host_non_null
      
      
      name = event:attr("name")
      wellKnown_Tx = event:attr("wellKnown_Tx")
      Tx_role = event:attr("Tx_role")
      Rx_role = event:attr("Rx_role") == "" || event:attr("Rx_role").isnull() => 
        Tx_role + "_manager" | event:attr("Rx_role")
      channel_type = "subscription"
      
      attrs = {"name": name, "Tx_host": Tx_host, "wellKnown_Tx": wellKnown_Tx, 
        "Rx_role": Rx_role, "Tx_role": Tx_role, "channel_type": channel_type}
      
      name_in_use = ent:subscription_values.defaultsTo({}).keys() >< name
      name_is_placeholder = ent:subscription_values.get(name) == "subscription_placeholder"
      name_is_a_child = ent:child_sensors.defaultsTo({}).keys() >< name
      working_with_the_child = name_in_use && name_is_placeholder && name_is_a_child
      name_is_valid = not name_in_use || working_with_the_child
    }
    if name_is_valid then noop()
    fired {
      ent:subscription_values := ent:subscription_values.defaultsTo({}).put(name, "subscription_placeholder") if not name_in_use
      raise wrangler event "subscription"
        attributes attrs
    }
  }
  
  rule subscription_added {
    select when wrangler subscription_added
    pre {
      subscription_values = event:attrs
      name = subscription_values.get("name")
      from_sensor_subscription = subscription_values.get("Rx_role") == "sensor"
    }
    if from_sensor_subscription then 
      noop()
    fired {
      ent:subscription_values := ent:subscription_values.defaultTo({}).put(name, subscription_values)
    }
  }
  
}