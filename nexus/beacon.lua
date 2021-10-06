-- local p2pLib = require( "defnet.p2p_discovery" )
local p2pDiscovery = require( "nexus.p2pdiscovery" )
local Host = require( "nexus.host" )

local Beacon = {}
Beacon.__index = Beacon

function Beacon.new( game, callsign, onHostFound )
	local this = {}
	setmetatable( this, Beacon )

	-- beacon's parent game
	this.game = game
	this.callback = onHostFound

	-- send out my beacon to other peers in the network
	this.srv = p2pDiscovery.create( game.SEARCH_PORT )

	-- message coming in contains the remote user's callsign
	this.srv:listen( game.name, function( ip, port, message )
		-- for every peer, fire event exactly once
		if game.hosts:get( message ) == nil then
			local host = Host.new( ip, port, message )
			game:addHost( host )
			this:onHostFound( host )
		end
	end, true )

	local msg = game.name .. callsign
	this.srv:broadcast( msg )

	return this
end


function Beacon:update()
	if self.srv then self.srv:update() end
end


function Beacon:onHostFound( host )
	if self.callback then self.callback( host ) end
end


function Beacon:setCustomIP( ip )
	self.srv:setCustomIP( ip )
end


function Beacon:destroy()
	if self.srv then self.srv:destroy() end
	
	self.srv = nil
	self.callback = nil
	self.game = nil
end


return Beacon

