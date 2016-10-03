--- message1
-- A base class for all messages
-- Created by IntelliJ IDEA.


--- The base message for all communications.
local message = {}

--basic construc of a message
--- sequence number from 0 to 255
message.sequence = 0
--- Unique Client ID
message.client_id = 0
--- Message Unique Identifier
message.uuid = "0-0-0-0"
--- Source Address
message.source = ""
--- Destination Address
message.destination = ""
--- Type of message
message.type = "status"
--- Message Body. Another table
message.body = {}


--- new
-- Returns a new message.
local function new()
    return message;
end

return { new = new; }



