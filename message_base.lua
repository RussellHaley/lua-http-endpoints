--- A base class for all messages
-- @copyright (c) 2016 Russell Haley
-- @license FreeBSD License. See License.txt



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
local function New(t)
    if t then
        if t.client_id then message.initiator = t.client_id end;
        if t.uuid then message.uuid = t.uuid end;
        if t.sequence and tonumber(t.sequence) then
            message.sequence = t.sequence +1
            if message.sequence > 255 then message.sequence = 1 end;
        end;
        if t.source then message.destination = t.source end;
        if t.destination then message.source = t.destination end;
        if t.type then message.type = t.type end;
    end

    return message
end

return { New = New }



