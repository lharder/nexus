local p2pLib = require( "defnet.p2p_discovery" )
local nexus = require( "nexus.nexus" )
local Host = require( "nexus.host" )

local SEARCH_PORT = 9997


local Beacon = {}
Beacon.__index = Beacon

function Beacon.new( game, callsign, onHostFound )
	local this = {}
	setmetatable( this, Beacon )

	-- beacon's parent game
	this.game = game
	this.callback = onHostFound

	-- send out my beacon to other peers in the network
	local msg = game.name .. callsign
	this.sender = p2pLib.create( SEARCH_PORT )
	this.sender.broadcast( msg )

	-- listen to incoming peer messages on that same port 
	this.listener = p2pLib.create( SEARCH_PORT )

	-- message coming in contains the remote user's callsign
	this.listener.listen( game.name, function( ip, port, message )
		-- for every peer, fire event exactly once
		if game.hosts:get( message ) == nil then
			local host = Host.new( ip, port, message )
			game:addHost( host )
			this:onHostFound( host )
		end
	end, 
	true )

	return this
end


function Beacon:update()
	if self.sender then self.sender:update() end
	if self.listener then self.listener:update() end
end


function Beacon:onHostFound( host )
	if self.callback then self.callback( host ) end
end


function Beacon:destroy()
	self.sender = nil
	self.listener = nil
	self.callback = nil
	self.game = nil
end


return Beacon

