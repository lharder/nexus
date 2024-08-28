local Events = require( "nexus.events" )

Events.FACTORY_CREATED = Events.create( "factorycreated" )


local function factorycreate( facturl, pos, rot, attrs, scale )
	local evHandler = Events.FACTORY_CREATED:subscribe( function( self, fnInit ) 
		fnInit( self, attrs )
	end )

	local id = factory.create( facturl, pos, rot, nil, scale )

	Events.FACTORY_CREATED:unsubscribe( evHandler )

	return id
end

return factorycreate

