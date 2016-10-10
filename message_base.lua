--- A base class for all messages
-- @author Russell Haley, Created with IntelliJ IDEA.
-- @copyright 2016
-- @license BSD 2 Clause. See License.txt



--- The base message for all communications.
local message = {}

--- Sequence number from 0 to 255
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
message.type = ""
--- The message specific contents of a transmission
message.body = {}


--- Returns a new message.
local function new()
    return message;
end

return { new = new; }



