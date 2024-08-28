local Event = require( "nexus.event" )


-- Events -----------------------
local Events = {}
Events.types = {}

function Events.create( key ) 
	if Events.types[ key ] ~= nil then 
		pprint( "There already is an event of type '" .. key .. "'!" )
	else
		Events.types[ key ] = Event.create( key )
	end
	return Events.types[ key ]
end


function Events:get( key )
	return Events.types[ key ]
end


return Events

