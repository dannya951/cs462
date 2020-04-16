ruleset store_ruleset {
    meta {
        use module io.picolabs.subscription alias Subscriptions
        
        /*
        // use module **this depends on where we have api keys**
        use module twilio_v2_api alias twilio
            with account_sid = keys:twilio{"account_sid"}
            auth_token =  keys:twilio{"auth_token"}
        */
        use module twilio_api_keys
        use module twilio_api alias twilio
          with account_sid = keys:twilio{"account_sid"}
            auth_token = keys:twilio{"auth_token"}    
        
        use module distance_api_keys
        use module distance alias dist
            with auth_token = keys:distance{"auth_token"}
            
        shares __testing, get_all_orders, get_bids, get_assigned_orders, 
          get_completed_orders, getLocation
    }
    global {
        __testing = {
            "queries": [
              {"name": "get_all_orders"}, 
              {"name": "get_bids"}, 
              {"name": "get_assigned_orders"}, 
              {"name": "get_completed_orders"}, 
              {"name": "getLocation"}],
            "events": [
              {"domain": "order", "type": "new", "attrs": 
                ["phone", "description"]}, 
              {"domain": "store", "type": "setLocation", "attrs": 
                ["latitude", "longitude"]}]}
            
                
        getLocation = function() {
            ent:location
        }
        
        get_assigned_orders = function() {
            ent:orders.filter(function(a) {
                not a{"assigned_driver"}.isnull() && a{"delivered_at"}.isnull();
            });
        }
        
        get_completed_orders = function() {
            ent:orders.filter(function(a) {
                not a{"delivered_at"}.isnull()
            });
        }
        
        /*
        get_driver = function() {
            subs = Subscriptions:established("Rx_role","driver").klog("Drivers:");
            // Return a random driver from this list of drivers the store knows about
            rand_sub = random:integer(subs.length() - 1);
            subs[rand_sub]
        }
        */
        
        order_by_id = function(id) {
            ent:orders{id}
        }
        
        get_all_orders = function() {
            ent:orders
        }
        
        get_bids = function() {
            ent:bids
        }
        
        getDistance = function(alat, alon, blat, blon) {
            output = dist:get_distance(alat,alon,blat,blon).klog("Store dist calculated:");
            output;
        }
        
        chooseBidForOrder = function(orderId) {
            filtered = ent:bids.filter(function(a){a{"id"} == orderId}).klog("Filtered:");
            sorted = filtered.sort(function(a, b) {
                alat = a{["driverLocation", "latitude"]};
                alon = a{["driverLocation", "longitude"]};
                blat = b{["driverLocation", "latitude"]};
                blon = b{["driverLocation", "longitude"]};
                storelat = ent:location{"latitude"};
                storelon = ent:location{"longitude"};
                a{"rating"} > b{"rating"}  => -1 |
                a{"rating"} == b{"rating"} && (getDistance(alat, alon, storelat, storelon) < getDistance(blat, blon, storelat, storelon)) =>  -1 | 1
            }).klog("Sorted:");
            sorted[0];
        }
        
        getRejectedBids = function(acceptedBid) {
            filtered = ent:bids.filter(function(a){
                a{"id"} == acceptedBid{"id"} && a{"driverEci"} != acceptedBid{"driverEci"}
            });
            filtered
        }
        
        get_registry = function() {
          registry_Rx = ent:registry_Rx.defaultsTo(
            ["HoxSRJwJPnfATNMa6gFESy", "KajeqGfUkRpHWT2VmVR9gN", "9Xebtm27yd3Xp9ZWKfcqDv"]
            [random:integer(2)])
          registry_Rx
    }
    }
    
    
    rule ruleset_added {
        select when wrangler ruleset_added where rids >< meta:rid
        always {
            ent:bids := [];
            ent:orders := {};
            ent:bidWindowTime := 10;
            ent:storePhoneNumber := "+15034064270";
            ent:location := {"latitude": "40.2968979", "longitude": "-111.69464749999997"};
        }
    }
    
    // Customer order triggers this rule
    rule new_order {
        select when order new 
        pre {
            // Create unique identifier for this new order
            id = random:uuid()
            customer_phone = event:attr("phone")
            description = event:attr("description")
            new_order = {
                "id": id,
                "customer_phone": customer_phone,
                "description": description
            }
        }
        always {
            ent:orders := get_all_orders().put(id, new_order);
            raise order event "request_bids" attributes {"id": id}
        }
    }
    
    // The flower shop will only ever initiate subscriptions
    /*
    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            attrs = event:attrs.klog("subcription:")
        }
        always {
            raise wrangler event "pending_subscription_approval"
            attributes attrs
        }
    }
    */
    
    rule update_customer_via_text {
        select when customer sendMessage
        pre {
            message = event:attr("message").defaultsTo("Confirmation of flower delivery")
            toNumber = event:attr("phoneNumber").defaultsTo("+18017848121")
        }
        // send_message=defaction(source, destination, message)
        twilio:send_message(ent:storePhoneNumber, toNumber, message)
    }
    
    rule set_location {
        select when store setLocation
        pre {
            lat = event:attr("latitude").defaultsTo(ent:location{"latitude"})
            lon = event:attr("longitude").defaultsTo(ent:location{"longitude"})
        }
        always {
            ent:location := {"latitude": lat, "longitude": lon}
        }
    }
}