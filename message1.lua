--
-- Created by IntelliJ IDEA.
-- User: russellh
-- Date: 9/24/16
-- Time: 4:03 PM
-- To change this template use File | Settings | File Templates.
--
message = {}

message.sequence = 0
message.uuid = "0-0-0-0"
message.destination = ""
message.type = "status"
message.body = {}

local function new()
   return message;
end
return {new = new;}



