local Factoryevent = require( "nexus.factoryevent" )


local function factorycreate( facturl, pos, rot, attrs, scale )
	local evHandler = Factoryevent:subscribe( function( self, fnInit ) 
		fnInit( self, attrs )
	end )

	local id = factory.create( facturl, pos, rot, nil, scale )

	Factoryevent:unsubscribe( evHandler )

	return id
end

return factorycreate

