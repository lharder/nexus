-- local p2pLib = require( "defnet.p2p_discovery" )
local p2pDiscovery = require( "nexus.p2pdiscovery" )
local Contact = require( "nexus.contact" )
local OrderedMap = require( "nexus.orderedmap" )
local Localhost = require( "nexus.localhost" )


local SEARCH_PORT = 5898


-- Beacon --------------------------
local Beacon = {}
Beacon.__index = Beacon

function Beacon.new( gamename, callsign, onContactFound )
	local this = {}
	setmetatable( this, Beacon )

	this.contacts = OrderedMap.new()
	this.contact = Contact.new( Localhost.getIP(), SEARCH_PORT, callsign )

	-- send out my beacon to other peers in the network
	this.srv = p2pDiscovery.create( SEARCH_PORT )

	-- message coming in contains the remote user's callsign
	this.srv:listen( gamename, function( ip, port, callsign )
		-- for every peer, fire event exactly once
		if this.contacts:get( callsign ) == nil then
			-- remember this new contact
			local other = Contact.new( ip, port, callsign )
			this.contacts:put( callsign, other )
			
			-- custom callback handler - optional
			if onContactFound then onContactFound( other ) end
		end
	end, true )

	local msg = gamename .. callsign
	this.srv:broadcast( msg )

	return this
end


function Beacon:others()
	local results = {}
	for i, contact in ipairs( self.contacts ) do
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

