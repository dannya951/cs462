ruleset registry {
  meta {
    logging on
    shares registered_drivers, __testing
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
   
  global {
    __testing = {"queries": [
                  {"name": "registered_drivers"}],
                "events": [
                  {"domain": "registry", "type": "driver_registration", "attrs": 
                    ["driver_Rx"]},
                  {"domain": "registry", "type": "driver_disconnection", "attrs": 
                    ["driver_Rx"]}]}
  
    registered_drivers = function() {
      drivers = ent:registered_drivers.defaultsTo({})
      drivers
    }
  }
  
  // one-time scheduled health check event dependent on continued activity
   
  // raised by drivers
  rule driver_registered {
    select when registry driver_registration
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
      time = time:strftime(time:now(), "%c")
    }
    noop()
    fired{
      ent:registered_drivers := registered_drivers().put(driver_Rx, time)
      
      // update other registries
      schedule wrangler event "send_event_on_subs" at time:add(time:now(), {"seconds": 3}) attributes {
        "domain": "registry",
        "type": "add_update",
        "Rx_role": "registry",
        "attrs": {"driver_Rx": driver_Rx, "time": time}
      }
      
      // schedule first one-time scheduled health check event
      
      // send driver_Rx peers to connect to
      raise registry event "registration_response" attributes attrs
      
      raise registry event "color_updated"
    }
  }
  
  //raised by other registries
  rule driver_added {
    select when registry add_update
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
      time = event:attrs.get("time")
    }
    noop()
    fired {
      ent:registered_drivers := registered_drivers().put(driver_Rx, time)
      
      raise registry event "color_updated"
    }
  }
  
  // raised by drivers
  rule driver_disconnected {
    select when registry driver_disconnection
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
    }
    noop()
    fired {
      ent:registered_drivers := registered_drivers().delete(driver_Rx)
      
      // update other registries
      schedule wrangler event "send_event_on_subs" at time:add(time:now(), {"seconds": 3}) attributes {
        "domain": "registry",
        "type": "remove_update",
        "Rx_role": "registry",
        "attrs": {"driver_Rx": driver_Rx}
      }
      
      raise registry event "color_updated"
    }
  }
  
  //raised by other registries
  rule driver_removed {
    select when registry remove_update
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
    }
    noop()
    fired {
      ent:registered_drivers := registered_drivers().delete(driver_Rx)
      
      raise registry event "color_updated"
    }
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
  rule update_color {
    select when registry color_updated
    pre {
      node_Tx = wrangler:myself().get("eci")
      
      registered_drivers_string = registered_drivers().encode()
      info_hash = math:hash("sha256", registered_drivers_string)
      
      color = "#" + info_hash.substr(0,6).defaultsTo("87cefa")
      dname = wrangler:myself(){"name"}
      attrs = {"color": color, "dname": dname}
    }
    send_directive("Update color", {"node_Tx": node_Tx, "color": color})
    fired {
      raise visual event "update" attributes attrs
    }
  }
}