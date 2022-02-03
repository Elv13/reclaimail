local rest = require("rest")

rest.send_async_command("api", rest.generate_uuid(), rest.generate_uuid(), rest.generate_uuid(), "moo", 42)
