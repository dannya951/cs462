ruleset hello_world {
  meta {
    logging on
    shares __testing
  }
   
  global {
    __testing = { "queries": [],
                  "events": [ { "domain": "echo", "type": "monkey" } ]
    }
  }
   
  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }

  rule hello_monkey {
  	select when echo monkey
  	pre {
  	  name = event:attr("name").defaultsTo("Monkey").klog("Name supplied for event: ")
  	}
  	send_directive("Hello " + name)
  }
   
}
