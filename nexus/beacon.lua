-- local p2pLib = require( "defnet.p2p_discovery" )
local p2pDiscovery = require( "nexus.p2pdiscovery" )
local Contact = require( "nexus.contact" )
local OrderedMap = require( "nexus.orderedmap" )
local Localhost = require( "nexus.localhost" )


local SEARCH_PORT = 5898

-- strings --------
local function indexOf( s, txt, startAtPos )
	if startAtPos == nil then startAtPos = 0 end

	-- returns two values: start and end position!
	local start, stop = string.find( s, txt, startAtPos, true )
	if start then 
		return start 
	else
		return -1
	end
end


-- Beacon --------------------------
local Beacon = {}
Beacon.__index = Beacon

function Beacon.new( gamename, callsign, onContactFound, attrs )
	local this = {}
	setmetatable( this, Beacon )

	this.contacts = OrderedMap.new()
	this.contact = Contact.new( Localhost.getIP(), SEARCH_PORT, callsign, attrs )

	-- send out my beacon to other peers in the network
	this.srv = p2pDiscovery.create( SEARCH_PORT )

	-- message coming in contains the remote user's callsign
	this.srv:listen( gamename, function( ip, port, serialized )
		local attrs = sys.deserialize( serialized )

		-- treat callsign as extra property
		local callsign = attrs.callsign
		attrs.callsign = nil
		
		-- for every peer, fire event exactly once
		if this.contacts:get( callsign ) == nil then
			-- remember this new contact
			local other = Contact.new( ip, port, callsign, attrs )
			this.contacts:put( callsign, other )
			
			-- custom callback handler - optional
			if onContactFound then onContactFound( other ) end
		end
	end, true )

	if attrs == nil then attrs = {} end
	attrs.callsign = callsign

	local msg = gamename .. sys.serialize( attrs )
	this.srv:broadcast( msg )

	return this
end


function Beacon:others()
	local results = {}
	local keys = self.contacts:keys()
	for i, key in ipairs( keys ) do
		local contact = self.contacts:get( key )
		if( contact.ip ~= self.contact.ip ) then 
			table.insert( results, contact ) 
		end
	end
	return results
end

function Beacon:all()
	return self.contacts
end

function Beacon:me()
	return self.contact
end


function Beacon:update()
	if self.srv then self.srv:update() end
end


function Beacon:destroy()
	if self.srv then self.srv:destroy() end
	self.srv = nil
end


return Beacon

