ruleset manage_sensors {
  meta {
    logging on
    shares sensor_added, sensor_removed, subscription_sensors, temperatures, 
      subscription_requested, all_reports, records_reset, recent_reports, __testing
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
   
  global {
    __testing = {"queries": [ {"name": "__testing"}, {"name": "subscription_sensors" }, 
                  {"name": "temperatures"}, {"name": "all_reports"}, {"name": "recent_reports"}],
                "events": [{ "domain": "sensor", "type": "new_sensor", "attrs": ["name"] }, 
                  {"domain": "sensor", "type": "unneeded_sensor", "attrs": ["name"] }, 
                  {"domain": "manager", "type": "report_requested"}, 
                  {"domain": "manager", "type": "records_reset"}, 
                  {"domain": "manager", "type": "subscription", 
                    "attrs": ["name", "Tx_host", "wellKnown_Tx", "Rx_role", 
                    "Tx_role", "channel_type"]}] }
                
    threshold_temperature = function() {
      threshold = ent:threshold_temperature.defaultsTo(85)
      threshold
    }
    
    sms_number = function() {
      number = ent:sms_number.defaultsTo("+18017848121")
      number
    }
    
    
    subscription_sensors = function() {
      subscription_sensors = Subscriptions:established("Tx_role", "sensor")
      subscription_sensors
    }
     
    concurrent_correlation_ID = function(name, proposed_corr_ID) {
      corr_ID = not(ent:recorded_corr_IDs.defaultsTo({}) >< name) => proposed_corr_ID | 
        ent:recorded_corr_IDs.defaultsTo({}).get(name) >= proposed_corr_ID => 
        concurrent_correlation_ID(name, ent:recorded_corr_IDs.defaultsTo({}).get(name) + 1) | 
        proposed_corr_ID
      corr_ID
    }
    
    temperatures = function() {
      temperature_array = subscription_sensors().map(
        function(sub_info) {
          info = sub_info// .klog("***** Subscription Info *****: ")
          Tx = sub_info.get("Tx")
          Tx_host = sub_info.get("Tx_host")// .klog("***** Tx host *****: ")
          sub_name = ent:subscription_values.defaultsTo({})
            .filter(function(v, k){v.get("Tx") == Tx}).keys().head()
            // .klog("***** Subscription Name *****: ")
          ruleset_name = "temperature_store"
          function_name = "current_temperature"
          temperature = wrangler:skyQuery(Tx, ruleset_name, function_name, [], Tx_host)
          array_result = {}.put(sub_name, temperature)
          array_result
        }
      )
      temperature_array.reduce(function(map_1, map_2){map_1.put(map_2.keys().head(), map_2.values().head())})
    }
    
    all_reports = function() {
      ent:reports_map.defaultsTo({})
    }
    
    recent_reports = function() {
      string_corr_IDs = ent:reports_map.defaultsTo({}).keys()
      sorted_string_corr_IDs = string_corr_IDs.sort("numeric")
      // number_corr_IDs = string_corr_IDs.map(function (corr_ID) {corr_ID.as("Number")})
      corr_IDs_count = sorted_string_corr_IDs.length()
      slice_index = corr_IDs_count - 5 < 0 => 0 | corr_IDs_count - 5
      sliced_corr_IDs = sorted_string_corr_IDs.slice(slice_index, corr_IDs_count - 1)
      sliced_reports = ent:reports_map.defaultsTo({}).filter(function(v, k) {sliced_corr_IDs >< k})
      sliced_reports
    }
  }
  
  rule async_temperatures {
    select when manager report_requested 
      foreach subscription_sensors() setting(sub_info)
      pre {
        info = sub_info// .klog("***** Subscription Info *****: ")
        Tx = sub_info.get("Tx")
        Tx_host = sub_info.get("Tx_host")
        name = ent:subscription_values.defaultsTo({})
          .filter(function(v, k){v.get("Tx") == Tx}).keys().head()
          // .klog("***** Subscription Name *****: ")
        event_domain = "wovyn"
        event_type = "temperature_requested"
        response_eci = sub_info.get("Rx")
        
        // this could be protected more by having a record for each name 
        // pertaining to specific scatter requests.  It's not necessary here 
        // because we only have one asynchronous service.
        proposed_corr_ID = ent:corr_ID_tracker.defaultsTo(0)
          // .klog("***** Proposed Correlation ID *****: ")
        corr_ID = concurrent_correlation_ID(name, proposed_corr_ID)
          // .klog("***** Actual Correlation ID *****: ")
        response_event_domain = "manager"
        response_event_type = "async_received"
        
        Rx_host_unformatted = meta:host
        Rx_host = Rx_host_unformatted.substr(0,7) != "http://" => 
        "http://" + Rx_host_unformatted | Rx_host_unformatted
        attrs = {"response_eci": response_eci, "name": name, "corr_ID": corr_ID, 
                "response_event_domain": response_event_domain, 
                "response_event_type": response_event_type, "Rx_host": Rx_host}
        
        corr_ID_request_count = (ent:corr_IDs_request_counts.defaultsTo({}) >< corr_ID => 
          ent:corr_IDs_request_counts.defaultsTo({}).get(corr_ID) | 0)
            // .klog("***** Correlation ID Request Count *****: ")
      }
      event:send(
          {"eci": Tx, "domain": event_domain, "type": event_type, "attrs": attrs}, host=Tx_host)
      always {
        ent:recorded_corr_IDs := ent:recorded_corr_IDs.defaultsTo({}).put(name, corr_ID)
        ent:corr_IDs_request_counts := ent:corr_IDs_request_counts.defaultsTo({})
          .put(corr_ID, ent:corr_IDs_request_counts.get(corr_ID).defaultsTo(0) + 1)
        ent:corr_ID_tracker := ent:corr_ID_tracker.defaultsTo(0) + 1 on final
      }
  }
  
  rule update_report {
    select when manager async_received
    pre {
      name = event:attrs.get("name")
      corr_ID = event:attrs.get("corr_ID")
      temperature = event:attrs.get("temperature")
      
      temperature_sensors = ent:corr_IDs_request_counts.defaultsTo({}).get(corr_ID).defaultsTo(0)
      old_temperatures = ent:reports_map.defaultsTo({}).get(corr_ID).defaultsTo({}).get("temperatures").defaultsTo([])
      temperatures = old_temperatures.union([{}.put(name, temperature)])
      responding = temperatures.length()
      updated_report_content = {}
        .put("temperature_sensors", temperature_sensors)
        .put("responding", responding)
        .put("temperatures", temperatures)
      updated_report = {}.put(corr_ID, updated_report_content)
    }
    noop()
    fired {
      // ent:reports_map := ent:reports_map.defaultsTo({}).put([corr_ID, name], temperature)
      // ent:reports_map := ent:reports_map.defaultsTo({}).put(corr_ID, ent:reports_map.defaultsTo({}).get(corr_ID).defaultsTo([]).union([{}.put(name, temperature)]))
      ent:reports_map := ent:reports_map.defaultsTo({}).put(updated_report)
    }
  }
  
  rule records_reset {
    select when manager records_reset
    always {
      ent:corr_ID_tracker := null
      ent:corr_IDs_request_counts:= null
      ent:recorded_corr_IDs:= null
      ent:reports_map:= null
    }
  }
   
  rule sensor_added {
    select when sensor new_sensor
    pre {
      // The lab specifies that the name must come from the event attributes;
      // if no name is provided, we will enforce that no new child pico can be 
      // created.
      name_provided = (event:attr("name") == "" || event:attr("name").isnull()) => false | true
      name = name_provided => event:attr("name") | "default name"
      
      name_unique = not(ent:subscription_values.defaultsTo({}).keys() >< name)
    }
    
    // name not provided or name not unique
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
      ent:subscription_values := ent:subscription_values.defaultsTo({}).put(name, subscription_values)
    }
  }
  
}