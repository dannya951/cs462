ruleset gossip_protocol {
  meta {
    logging on
    shares __testing, process_status, heartbeat_delay, random_message_type,
      peer_messages, peer_sequence_numbers, max_sequence_number, peer_missing_messages,
      choose_peer
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
   
  global {
    __testing = { "queries": [
                  {"name": "process_status"},
                  {"name": "heartbeat_delay"},
                  {"name": "random_message_type"},
                  {"name": "peer_messages"},
                  {"name": "peer_sequence_numbers"},
                  {"name": "max_sequence_number", "args": 
                    ["peer_Tx", "OriginID", "sequence_number"]},
                  {"name": "peer_missing_messages", "args": 
                    ["peer_Tx"]},
                  {"name": "choose_peer"}],
                "events": [
                  {"domain": "gossip", "type": "heartbeat"},
                  {"domain": "gossip", "type": "message_required"},
                  {"domain": "gossip", "type": "process", "attrs": 
                    ["status"]},
                  {"domain": "gossip", "type": "delay", "attrs": 
                    ["measurement", "magnitude"]},
                  {"domain": "gossip", "type": "subscription_requested", "attrs": 
                    ["Tx_host", "wellKnown_Tx"]},
                  {"domain": "gossip", "type": "unneeded_subscription", "attrs": 
                    ["wellKnown_Tx"]},
                  {"domain": "gossip", "type": "rumor", "attrs": 
                    ["Message"]},
                  {"domain": "gossip", "type": "seen", "attrs": 
                    ["Message"]},
                  {"domain": "gossip", "type": "update_sequence_numbers"},
                  {"domain": "test", "type": "test_rumor", "attrs": 
                    ["MessageID", "SensorID", "Temperature", "Timestamp", "peer_Tx"]},
                  {"domain": "test", "type": "test_rumor_remote", "attrs": 
                    ["MessageID", "SensorID", "Temperature", "Timestamp", "peer_wellKnown_Tx"]},
                  {"domain": "test", "type": "test_seen_remote", "attrs": 
                    ["peer_wellKnown_Tx"]},
                  {"domain": "test", "type": "test_sub_tx"},
                  {"domain": "test", "type": "test_sub_rx"},
                  {"domain": "test", "type": "reset"},
                  {"domain": "gossip", "type": "seen_response", "attrs": 
                    ["peer_Tx"]},
                  {"domain": "gossip", "type": "send_rumor", "attrs": 
                    ["peer_Tx", "Message"]},
                  {"domain": "gossip", "type": "send_seen", "attrs": 
                    ["peer_Tx", "Message"]},
                  {"domain": "gossip", "type": "generate_message", "attrs": 
                    ["Message"]},
                  {"domain": "test", "type": "test_generate", "attrs": 
                    ["Temperature", "Timestamp"]}]}
    
    process_status = function() {
      status = ent:process_status.defaultsTo(false)
      status
    }
    
    heartbeat_delay = function() {
      delay = ent:heartbeat_delay.defaultsTo({"measurement": "seconds", "magnitude": 10})
      delay
    }
    
    viable_measurements = function() {
      ["days", "weeks", "hours", "minutes", "seconds"]
    }
    
    subscriptions = function() {
      subscription_values = ent:subscription_values.defaultsTo({})
      subscription_values
    }
    
    random_message_type = function() {
      types = ["rumor", "seen"]
      random_index = random:integer(lower=0, upper=1)
      type = types[random_index]
      type
    }
    
    peer_messages = function() {
      messages = ent:peer_message_maps.defaultsTo({})
      messages
    }
    
    peer_sequence_numbers = function() {
      sequence_numbers = ent:peer_sequence_number_maps.defaultsTo({})
      sequence_numbers
    }
    
    max_sequence_number = function(peer_Tx, OriginID, sequence_number) {
      number = sequence_number.as("Number")
      number_to_check = (number + 1)
      OriginID_sequence_number_map = peer_messages().get([peer_Tx, OriginID])
      checked_number_exists = (OriginID_sequence_number_map >< number_to_check.as("String"))
      max_seq_num = checked_number_exists
        => max_sequence_number(peer_Tx, OriginID, number_to_check) | number
      max_seq_num
    }
    
    peer_missing_messages = function(peer_Tx) {
      peer_sequence_numbers_map = peer_sequence_numbers().get(peer_Tx).defaultsTo({})
      node_Tx = wrangler:myself().get("eci")
      node_sequence_numbers_map = peer_sequence_numbers().get(node_Tx).defaultsTo({})
      
      missing_OriginIDs = node_sequence_numbers_map.keys().difference(peer_sequence_numbers_map.keys())
      missing_OriginID_rumors = missing_OriginIDs.map(function(OriginID) {{}.put(OriginID, 0)})
      reduced_missing_OriginID_rumors = missing_OriginID_rumors.reduce(function(r1, r2) {r1.put(r2)}, {})
      
      relevant_OriginIDs = node_sequence_numbers_map.keys().intersection(peer_sequence_numbers_map.keys())
      incremented_relevant_OriginalID_sequence_numbers = relevant_OriginIDs
        .map(function(OriginID) {peer_sequence_numbers_map.get(OriginID).as("Number") 
        < node_sequence_numbers_map.get(OriginID).as("Number") 
        => {}.put(OriginID, peer_sequence_numbers_map.get(OriginID).as("Number") + 1) 
        | {}})
        reduced_incremented_relevant_OriginalID_sequence_numbers = incremented_relevant_OriginalID_sequence_numbers
          .reduce(function(r1, r2) {r1.put(r2)}, {})
          
        all_missing_messages = reduced_missing_OriginID_rumors
          .put(reduced_incremented_relevant_OriginalID_sequence_numbers)
        all_missing_message_keys = all_missing_messages.keys()
        all_missing_message_key_count = all_missing_message_keys.length()
        
        peer_chosen_message = all_missing_message_key_count == 0 
          => {} | peer_random_index_message(node_Tx, all_missing_messages)
        peer_chosen_message
    }
    
    peer_random_index_message = function(node_Tx, all_missing_messages) {
      all_missing_message_keys = all_missing_messages.keys()
      all_missing_message_key_count = all_missing_message_keys.length()
      
      random_OriginID = all_missing_message_keys.get(random:integer(all_missing_message_key_count - 1))
      random_sequence_number = all_missing_messages.get(random_OriginID)
      random_missing_message = peer_messages().get(node_Tx).get(random_OriginID)
        .get(random_sequence_number)
      random_missing_message
    }
    
    choose_peer = function() {
      peer_Tx_array = subscriptions().keys().map(function(name) {subscriptions().get(name).get("Tx")})
      peer_Tx_missing_messages_map = peer_Tx_array.map(function(peer_Tx) {
        {}.put(peer_Tx, peer_missing_messages(peer_Tx))})
        .reduce(function(m1, m2) {m1.put(m2)}, {})
      filtered_peer_Tx_missing_messages_map = peer_Tx_missing_messages_map
        .filter(function(message, peer_Tx) {message.length() > 0})
        
      unfiltered_peer_count = peer_Tx_missing_messages_map.length()
      filtered_peer_count = filtered_peer_Tx_missing_messages_map.length()
      
      chosen_peer_Tx = filtered_peer_count == 0 
        => peer_Tx_missing_messages_map.keys()[random:integer(unfiltered_peer_count - 1)] 
        | filtered_peer_Tx_missing_messages_map.keys()[random:integer(filtered_peer_count - 1)]
      chosen_peer_Tx
    }
  }

  rule gossip_heartbeat {
    select when gossip heartbeat
    pre {
      time = time:strftime(time:now(), "%c")
      heartbeat_delay = heartbeat_delay()
      delay_map = {}.put(heartbeat_delay.get("measurement"), heartbeat_delay.get("magnitude"))
      should_process = process_status()
      has_subscriptions = subscriptions().length() > 0
      node_Tx = wrangler:myself().get("eci")
    }
    send_directive("Gossip Heartbeat", {"Node": node_Tx})
    always {
      raise gossip event "message_required" if (should_process && has_subscriptions)
      raise gossip event "color_updated"
      schedule gossip event "heartbeat" at time:add(time:now(), delay_map)
    }
  }
  
  rule process_message {
    select when gossip message_required
    pre {
      chosen_peer_Tx = choose_peer()
      message_type = random_message_type()
      node_Tx = wrangler:myself().get("eci")
      Message = message_type == "rumor" 
        => peer_missing_messages(chosen_peer_Tx) 
        | peer_sequence_numbers().get(node_Tx).defaultsTo({})
      attrs = {"peer_Tx": chosen_peer_Tx, "Message": Message}
    }

    send_directive("Processing Message", {"Node": node_Tx, "Peer": chosen_peer_Tx, "Message Type": message_type})
    
    fired {
      raise gossip event "send_rumor" attributes attrs if message_type == "rumor"
      raise gossip event "send_seen" attributes attrs if message_type == "seen"
    }
  }
  
  rule send_rumor {
    select when gossip send_rumor
    pre {
      peer_Tx = event:attrs.get("peer_Tx")
      filtered_subscriptions = subscriptions().filter(function(v,k)
        {v.get("Tx") == peer_Tx})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      subID = subscriptions().get(filtered_subscription_name).get("Id")
      
      Message = event:attrs.get("Message")
      has_content = Message.length() > 0
      node_Tx = wrangler:myself().get("eci")
    }
    if has_content then send_directive("Sending Rumor Message", 
      {"Node": node_Tx, "Peer": peer_Tx, 
      "MessageID": Message.get("MessageID")})
    
    fired {
      raise wrangler event "send_event_on_subs" attributes 
        {"domain": "gossip", "type": "rumor", "subID": subID, "attrs":
          {"Message": Message}}
      raise gossip event "sent_rumor" attributes event:attrs
    }
  }
  
  rule send_seen {
    select when gossip send_seen
    pre {
      peer_Tx = event:attrs.get("peer_Tx")
      filtered_subscriptions = subscriptions().filter(function(v,k)
        {v.get("Tx") == peer_Tx})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      subID = subscriptions().get(filtered_subscription_name).get("Id")
      
      Message = event:attrs.get("Message")
      node_Tx = wrangler:myself().get("eci")
    }
    send_directive("Sending Seen Message", {"Node": node_Tx, "Peer": peer_Tx})
    fired {
      raise wrangler event "send_event_on_subs" attributes 
        {"domain": "gossip", "type": "seen", "subID": subID, "attrs":
          {"Message": Message}}
    }
  }
  
  rule generate_message {
    select when gossip generate_message
    pre {
      node_Tx = wrangler:myself().get("eci")
      
      // Message is provided in event:attrs, but it only contains 
      // "Temperature" and "Timestamp"
      Temperature = event:attrs.get(["Message", "Temperature"]).as("Number")
      SensorID = meta:picoId
      sequence_number = peer_messages().get([node_Tx, SensorID])
        .defaultsTo({}).length()
      MessageID = SensorID + ":" + sequence_number.as("String")
      Message = event:attrs.get("Message")
        .put("SensorID", SensorID)
        .put("MessageID", MessageID)
        .put("Temperature", Temperature)
    }
    send_directive("Generating Local Message", {"Node": node_Tx, "MessageID":MessageID})
    fired {
      ent:peer_message_maps := peer_messages().put([node_Tx, SensorID, sequence_number], Message)
      ent:peer_sequence_number_maps := peer_sequence_numbers().put([node_Tx, SensorID], sequence_number)
    }
  }
  
  rule generate_test {
    select when test test_generate
    pre {
      Temperature = event:attrs.get("Temperature") == "" || event:attrs.get("Temperature").isnull()
        => random:integer(upper = 99, lower = 50) 
        | event:attrs.get("Temperature").as("Number").defaultsTo(75)
      tz = {"tz": "America/Denver"}
      Timestamp = event:attrs.get("Timestamp") == "" || event:attrs.get("Timestamp").isnull()
        => time:strftime(time:now(tz), "%c") | event:attrs.get("Timestamp")
      Message = {"Temperature": Temperature, "Timestamp": Timestamp}
    }
    noop()
    fired {
       raise gossip event "generate_message" attributes {"Message": Message}
    }
  }
  
  rule update_sent_rumor {
    select when gossip sent_rumor
    pre {
      peer_Tx = event:attrs.get("peer_Tx")
      Message = event:attrs.get("Message")
      MessageID = Message.get("MessageID")
      MessageID_components = MessageID.split(re#:#)
      OriginID = MessageID_components[0]
      SequenceNumber = MessageID_components[1].as("Number")
      
      existing_sequence_number = peer_sequence_numbers().get([peer_Tx, OriginID]).defaultsTo(-1)
      numbers_sequential = existing_sequence_number + 1 == SequenceNumber
      
      node_Tx = wrangler:myself().get("eci")
    }
    if numbers_sequential then send_directive("Updating sequence number after rumor", {"Node": node_Tx, "Peer": peer_Tx, "MessageID": MessageID})
    fired {
      ent:peer_sequence_number_maps := peer_sequence_numbers().put([peer_Tx, OriginID], SequenceNumber)
    }
  }
  
  rule seen_received {
    select when gossip seen
    pre {
      Message = event:attrs.get("Message")
      has_content = Message.length() > 0
      
      peer_Rx = meta:eci
      filtered_subscriptions = subscriptions().filter(function(v,k){v.get("Rx") == peer_Rx})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      peer_Tx = subscriptions().get(filtered_subscription_name).get("Tx")
      
      delete_peer_Tx = (not has_content) && (peer_sequence_numbers() >< peer_Tx)
      
      node_Tx = wrangler:myself().get("eci")
    }
    send_directive("Seen message received", {"Node": node_Tx, "Peer": peer_Tx})
    fired {
      ent:peer_sequence_number_maps := peer_sequence_numbers().put(peer_Tx, Message)
        if has_content
      ent:peer_sequence_number_maps := peer_sequence_numbers().delete(peer_Tx)
        if delete_peer_Tx
      
      raise gossip event "seen_response" attributes {"peer_Tx": peer_Tx}
    }
  }
  
  rule respond_to_seen {
    select when gossip seen_response
    pre {
      peer_Tx = event:attrs.get("peer_Tx")
      Message = peer_missing_messages(peer_Tx)
      message_to_send = Message.length() > 0
      
      attrs = {"peer_Tx": peer_Tx, "Message": Message}
      
      node_Tx = wrangler:myself().get("eci")
    }
    if message_to_send then send_directive("Responding to Seen message", {"Node": node_Tx, "Peer": peer_Tx, "MessageID": Message.get("MessageID")})
    fired {
      raise gossip event "send_rumor" attributes attrs
    }
  }
  
  rule rumor_received {
    select when gossip rumor
    pre {
      Message = event:attrs.get("Message")
      MessageID = Message.get("MessageID")
      MessageID_components = MessageID.split(re#:#)
      OriginID = MessageID_components[0]
      SequenceNumber = MessageID_components[1].as("Number")
      
      peer_Rx = meta:eci
      filtered_subscriptions = subscriptions().filter(function(v,k){v.get("Rx") == peer_Rx})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      peer_Tx = subscriptions().get(filtered_subscription_name).get("Tx")
      node_Tx = wrangler:myself().get("eci")
    }
    send_directive("Rumor message received", {"Node": node_Tx, "Peer": peer_Tx, "MessageID": MessageID})
    fired {
      ent:peer_message_maps := peer_messages().put([peer_Tx, OriginID, SequenceNumber], Message)
      ent:peer_message_maps := peer_messages().put([node_Tx, OriginID, SequenceNumber], Message)
      
      raise gossip event "update_sequence_numbers"
    }
  }
  
  rule sequence_number_update {
    select when gossip update_sequence_numbers
      foreach peer_messages() setting (OriginID_message_maps, peer_Tx)
        foreach OriginID_message_maps setting (sequence_number_maps, OriginID)
          pre {
            existing_SequenceNumber = peer_sequence_numbers().get([peer_Tx, OriginID]).defaultsTo(-1)
            max_SequenceNumber = max_sequence_number(peer_Tx, OriginID, -1)
            
            SequenceNumber = existing_SequenceNumber > max_SequenceNumber
              => existing_SequenceNumber | max_SequenceNumber
            SequenceNumber_exists = SequenceNumber > -1
          }
          if SequenceNumber_exists then noop()
          fired {
            ent:peer_sequence_number_maps := peer_sequence_numbers().put([peer_Tx, OriginID], SequenceNumber)
          }
  }
  
  rule reset {
    select when test reset
    noop()
    fired {
      ent:peer_message_maps := {}
      ent:peer_sequence_number_maps := {}
    }
  }
  
  rule remote_rumor_test {
    select when test test_rumor_remote
    pre {
      MessageID = event:attrs.get("MessageID")
      SensorID = event:attrs.get("SensorID")
      Temperature = event:attrs.get("Temperature")
      Timestamp = event:attrs.get("Timestamp")
      Message = {"MessageID": MessageID, "SensorID": SensorID, 
        "Temperature": Temperature, "Timestamp": Timestamp}
      
      peer_wellKnown_Tx = event:attrs.get("peer_wellKnown_Tx")
      filtered_subscriptions = subscriptions().filter(function(v,k)
        {(k.split(re#:#)[0] == peer_wellKnown_Tx) || (k.split(re#:#)[1] == peer_wellKnown_Tx)})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      subID = subscriptions().get(filtered_subscription_name).get("Id")
    }
    noop()
    fired {
      // performing explicitly instead of raising send_rumor to avoid update
      raise wrangler event "send_event_on_subs" attributes 
        {"domain": "gossip", "type": "rumor", "subID": subID, "attrs":
          {"Message": Message}}
      // no update_state, not pertinet to test rule
    }
  }
  
  rule remote_seen_test {
    select when test test_seen_remote
    pre {
      peer_wellKnown_Tx = event:attrs.get("peer_wellKnown_Tx")
      filtered_subscriptions = subscriptions().filter(function(v,k)
        {(k.split(re#:#)[0] == peer_wellKnown_Tx) || (k.split(re#:#)[1] == peer_wellKnown_Tx)})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      peer_Tx = subscriptions().get(filtered_subscription_name).get("Tx")
      
      node_Tx = wrangler:myself().get("eci")
      Message = peer_sequence_numbers().get(node_Tx)
      
      attrs = {"peer_Tx": peer_Tx, "Message": Message}
    }
    noop()
    fired {
      raise gossip event "send_seen" attributes attrs
    }
  }
  
  rule direct_rumor_test {
    select when test test_rumor
    pre {
      MessageID = event:attrs.get("MessageID")
      MessageID_components = MessageID.split(re#:#)
      OriginID = MessageID_components[0]
      SequenceNumber = MessageID_components[1].as("Number")
      SensorID = event:attrs.get("SensorID")
      Temperature = event:attrs.get("Temperature")
      Timestamp = event:attrs.get("Timestamp")
      Message = {"MessageID": MessageID, "SensorID": SensorID, 
        "Temperature": Temperature, "Timestamp": Timestamp}
        
      peer_Tx = event:attrs.get("peer_Tx")
      node_Tx = wrangler:myself().get("eci")
    }
    noop()
    fired {
      ent:peer_message_maps := peer_messages().put([peer_Tx, OriginID, SequenceNumber], Message)
      ent:peer_message_maps := peer_messages().put([node_Tx, OriginID, SequenceNumber], Message)
      
      raise gossip event "update_sequence_numbers"
    }
  }
  
  rule subscription_Tx_test {
    select when test test_sub_tx
    pre {
      subscription_keys = subscriptions().keys()
      head_subscription_name = subscription_keys.head()
      sub_Tx = subscriptions().get(head_subscription_name).get("Tx")
      sub_ID = subscriptions().get(head_subscription_name).get("Id")
    }
    noop()
    fired {
      raise wrangler event "send_event_on_subs" attributes 
        {"domain": "test", "type": "test_sub_rx", "subID": sub_ID}
    }
  }
  
  rule subscription_Rx_test {
    select when test test_sub_rx
    pre {
      subscription_keys = subscriptions().keys()
      head_subscription_name = subscription_keys.head()
      sub_Rx = subscriptions().get(head_subscription_name).get("Rx")
      sub_ID = subscriptions().get(head_subscription_name).get("Id")
      peer_Rx = meta:eci
      filtered_subscriptions = subscriptions().filter(function(v,k){v.get("Rx") == peer_Rx})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      peer_Tx = subscriptions().get(filtered_subscription_name).get("Tx")
    }
    noop()
    fired {
      
    }
  }
  
  rule set_process {
    select when gossip process
    pre {
      status = event:attrs.get("status") == "" || event:attrs.get("status").isnull()
        => not process_status() | event:attrs.get("status").as("Boolean").defaultsTo(false)
    }
    // send_directive("Set Process", {"Status": status})
    noop()
    always {
      ent:process_status := status
    }
  }
  
  rule set_delay {
    select when gossip delay
    pre {
      raw_delay_measurement = event:attrs.get("measurement") == "" || event:attrs.get("measurement").isnull() 
        => "seconds" | event:attrs.get("measurement")
      delay_measurement = viable_measurements() >< raw_delay_measurement => raw_delay_measurement | "seconds"
      
      raw_delay_magnitude = event:attrs.get("magnitude") == "" || event:attrs.get("magnitude").isnull() 
        => 10 | event:attrs.get("magnitude").as("Number").defaultsTo(10)
      delay_magnitude = delay_measurement == "seconds" && raw_delay_magnitude < 5 => 5 | raw_delay_magnitude
      delay_map = {"measurement": delay_measurement, "magnitude": delay_magnitude}
    }
    // send_directive("Set Delay", {"Delay Measurement": delay_measurement, "Delay Magnitude": delay_magnitude})
    noop()
    always {
      ent:heartbeat_delay := delay_map
    }
  }
  
  rule subscription_requested {
    select when gossip subscription_requested
    pre {
      Tx_host_non_null = event:attr("Tx_host") == "" || event:attr("Tx_host").isnull() => 
        meta:host | event:attr("Tx_host")
      Tx_host = Tx_host_non_null.substr(0,7) != "http://" => 
        "http://" + Tx_host_non_null | Tx_host_non_null
      
      wellKnown_Tx = event:attr("wellKnown_Tx") //this is the destination pico's eci
      name = Subscriptions:wellKnown_Rx().get("id") + ":" + wellKnown_Tx
      Tx_role = "node"
      Rx_role = "node"
      channel_type = "gossip_subscription"
      
      attrs = {"name": name, "Tx_host": Tx_host, "wellKnown_Tx": wellKnown_Tx, 
        "Rx_role": Rx_role, "Tx_role": Tx_role, "channel_type": channel_type}
    }
    if wellKnown_Tx then noop()
    fired {
      raise wrangler event "subscription"
        attributes attrs
    }
  }
  
  rule subscription_added {
    select when wrangler subscription_added
    pre {
      all_values = event:attrs
      name = all_values.get("name")
      subscription_values = all_values.get("bus")
      from_gossip_subscription = subscription_values.get("Rx_role") == "node"
    }
    if from_gossip_subscription then 
      noop()
    fired {
      ent:subscription_values := subscriptions().put(name, subscription_values)
    }
  }
  
  rule unneeded_subscription {
    select when gossip unneeded_subscription
      pre {
        wellKnown_Tx = event:attrs.get("wellKnown_Tx")
        wellKnown_Rx = Subscriptions:wellKnown_Rx().get("id")
        name = subscriptions() >< wellKnown_Rx + ":" + wellKnown_Tx 
          => wellKnown_Rx + ":" + wellKnown_Tx | wellKnown_Tx + ":" + wellKnown_Rx
        name_present = subscriptions() >< name
        name_subscription = subscriptions().get(name)
        Tx_present = name_subscription >< "Tx"
        Tx = name_subscription.get("Tx")
      }
    if name_present && Tx_present then noop()
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Tx": Tx}
    }
  }
  
  rule subscription_removed {
    select when wrangler subscription_removed
    pre {
      Id = event:attrs.get("Id")
      filtered_subscriptions = subscriptions().filter(function(v,k){v.get("Id") == Id})
      filtered_subscription_keys = filtered_subscriptions.keys()
      filtered_subscription_name = filtered_subscription_keys.head()
      peer_Tx = subscriptions().get(filtered_subscription_name).get("Tx")
    }
    noop()
    fired {
      ent:subscription_values := subscriptions().delete(filtered_subscription_name)
      ent:peer_message_maps := peer_messages().delete(peer_Tx)
      ent:peer_sequence_number_maps := peer_sequence_numbers().delete(peer_Tx)
    }
  }
  
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
  
  rule update_color {
    select when gossip color_updated
    pre {
      node_Tx = wrangler:myself().get("eci")
      
      peer_messages_string = peer_messages().get(node_Tx).defaultsTo({}).encode()
      // peer_sequence_numbers_string = peer_sequence_numbers().encode()
      // maps_string = peer_messages_string + peer_sequence_numbers_string
      info_hash = math:hash("sha256", peer_messages_string)
      
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