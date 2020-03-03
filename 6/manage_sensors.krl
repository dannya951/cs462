ruleset manage_sensors {
  meta {
    logging on
    shares sensor_added, sensor_removed, sensors, temperatures, __testing
    use module io.picolabs.wrangler alias wrangler
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing"}, {"name": "sensors" }, {"name": "temperatures"}],
                "events": [{ "domain": "sensor", "type": "new_sensor", "attrs": ["name"] }, 
                  {"domain": "sensor", "type": "unneeded_sensor", "attrs": ["name"] } ] }
                
    threshold_temperature = function() {
      threshold = ent:threshold_temperature.defaultsTo(100)
      threshold
    }
    
    sms_number = function() {
      number = ent:sms_number.defaultsTo("+19519651576")
      number
    }
    
    sensors = function() {
      sensors = ent:sensors.defaultsTo({})
      sensors
    }
    
    temperatures = function() {
      temperature_map = sensors().map(
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
      name_unique = not(sensors() >< name)
    }
    
    //name not provided or name not unique
    if not name_provided || not name_unique then
      send_directive("Could not create new child pico", 
        {"name_provided": name_provided, "name_unique": name_unique})
    
    notfired{
      // name provided and name_unique
      ent:sensors := ent:sensors.defaultsTo({}).put(name, "eci_placeholder")
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
      // profile_update_map = ({"name": name, "threshold": threshold, "number": number}).encode()
    }
    
    // Call updated_profile event on child pico to update name, threshold, 
    // and number.
    event:send({"eci": eci, "eid": "update_profile", "domain": "sensor", "type": "profile_updated", "attrs": profile_update_map})
    // send_directive("Registering child pico with parent", {"name": name})
    
    always {
      // Update the sensors entity variable so that the child pico's name maps 
      // to its eci.
      ent:sensors := ent:sensors.defaultsTo({}).put(name, eci)
    }
  }
  
  rule sensor_removed {
    select when sensor unneeded_sensor
    pre {
      name_provided = (event:attr("name") == "" || event:attr("name").isnull()) 
        => false | true
      name = name_provided => event:attr("name") | "default name"
      name_exists = sensors() >< name
    }
    if not name_provided || not name_exists then
      send_directive("Could not remove unneeded sensor", {"sensor_name": name})
    notfired {
      ent:sensors := ent:sensors.defaultsTo({}).delete(name)
      raise wrangler event "child_deletion"
        attributes {"name": name}
    }
  }
  
}