ruleset driver_manager {
  meta {
    logging on
    shares child_sensors, __testing
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing"}, {"name": "child_sensors" }],
                "events": [{ "domain": "sensor", "type": "new_sensor", "attrs": ["name"]}, 
                  {"domain": "sensor", "type": "unneeded_sensor", "attrs": ["name"]},
                  {"domain": "sensor", "type": "set_process", "attrs": ["status"]},
                  {"domain": "sensor", "type": "reset"}]}
    
    
    child_sensors = function() {
      sensors = ent:child_sensors.defaultsTo({})
      sensors
    }
    
    setup_child = defaction(eci) {
      every {
        // start gossip node heartbeat once child has been initialized
        event:send({"eci": eci, "eid": "start_heartbeat", "domain": "gossip", 
          "type": "heartbeat"})
        
        // refer driver to registry
        event:send({"eci": eci, "eid": "refer_registry", "domain": "gossip", 
          "type": "registration_referral"})
      }
    }
  }
  
  rule set_child_process {
    select when sensor set_process
    foreach child_sensors() setting (child_eci, child_name)
      pre {
        status = event:attrs.get("status").as("Boolean").defaultsTo(false)
      }
      event:send({"eci": child_eci, "eid": "process_status", "domain": "gossip", 
        "type": "process", "attrs": {"status": status}})
  }
  
  rule child_reset {
    select when sensor reset
    foreach child_sensors() setting (child_eci, child_name)
      event:send({"eci": child_eci, "eid": "child_reset", "domain": "test", 
        "type": "reset"})
  }
   
  rule sensor_added {
    select when sensor new_sensor
    pre {
      name = event:attrs.get("name")
      name_unique = name => not(child_sensors().keys() >< name) | false
    }
    
    if not name_unique then send_directive("Could not create new child pico", 
        {"name": name, "name_unique": name_unique})
    
    notfired{
      ent:child_sensors := child_sensors().put(name, "eci_placeholder")

      raise wrangler event "child_creation"
        attributes {"name": name, "rids": ["driver_gossip_protocol"]}
    }
  }
  
  rule child_initialized {
    select when wrangler child_initialized
    pre {
      // The child ECI is included in the child_initialized event attributes.
      eci = event:attr("eci")
      
      name = event:attr("name")
      // Tx_host = event:attr("_headers").get("host")
      
    }
    
    setup_child(eci)
    
    fired {
      // Update the sensors entity variable so that the child pico's name maps 
      // to its eci.
      ent:child_sensors := child_sensors().put(name, eci)
    }
  }
  
  rule sensor_removed {
    select when sensor unneeded_sensor
    pre {
      name = event:attrs.get("name")
      name_exists = name => child_sensors().keys() >< name | false
    }
    if not name_exists then send_directive("Could not remove unneeded sensor", {"sensor_name": name})
    
    notfired {
      raise wrangler event "child_deletion"
        attributes {"name": name}
      ent:child_sensors := child_sensors().delete(name)
    }
  }
}