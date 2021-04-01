local udp = require "defnet.udp"
local Envelope = require( "nexus.envelope" )
local Personality = require( "nexus.personality" )
local lua = require( "deflibs.lualib" )
local Events = require( "level.playground.events" )


local SEND_INTERVAL = 1 / 20


local Server = {}
Server.__index = Server

function Server.new()
	local this = {}
	setmetatable( this, Server )

	-- queue of events to send
	this.queue = {}
	this.nextSendTime = socket.gettime()

	-- serverside behaviors
	this.personalities = {}
	
	-- listen to incoming events
	this.srv = udp.create( function( data, ip, port )
		assert( data, "Received udp data must not be nil!" )
		
		-- incoming event from one of the clients
		local evt = Envelope.deserialize( data )
		-- pprint( "Server " .. GAME.meHost.ip .. " received: " .. Events.getName( evt ) )
		
		-- events contain the gid of the gameobject emitting this event as url
		local gid = evt:getUrl()
		if this.personalities[ gid ] then 
			-- pprint( GAME.meHost.ip .. ".onmessage( " .. Events.getName( evt ) .. " ) ) to " .. gid .. " from " .. ip )
			this.personalities[ gid ]:getActiveBehavior():onmessage( evt, ip, port )
		end
	end, GAME.SERVER_PORT )
	
	return this
end


function Server:update( dt )
	if self.srv then 
		-- listen to incoming network packets
		self.srv.update()

		-- send out events in regular intervals
		self.now = socket.gettime()
		if self.now >= self.nextSendTime then
			-- reset clock
			self.nextSendTime = self.now + SEND_INTERVAL
			-- send out everything in the queue
			for _, evt in ipairs( self.queue ) do
				-- pprint( "Server " .. GAME.meHost.ip .. " sending:  " .. Event.getName( evt ) .. " to " .. evt:getIP() )
				self.srv.send( evt:serialize(), evt:getIP(), GAME.CLIENT_PORT )
				self.queue = {}
			end
		end
	end

	-- update gameobject logic
	for _, personality in pairs( self.personalities ) do
		personality:update( dt )
	end
end


function Server:send( ip, env, port )
	if ip == nil or env == nil then return end

	-- by default, server always sends to clients
	if port == nil then port = GAME.CLIENT_PORT end
	
	-- important: must make an independent copy to be stored
	-- in the queue! Otherwise undesired changes afterwards possible!
	env = env:deepCopy()
	env:setIP( ip )
	env:setPort( port )
	table.insert( self.queue, env )
end


-- send the same events to all clients
function Server:sendToClients( env )
	for i, callsign in pairs( GAME.match.proposal ) do
		local host = GAME.hosts:get( callsign )
		self:send( host.ip, env, GAME.CLIENT_PORT )
	end
end


-- send to all clients except the one with the given ip:
-- typically used for propagating info from one client 
-- to all others via the server
function Server:sendToClientsExcept( ip, env )
	for i, callsign in pairs( GAME.match.proposal ) do
		local host = GAME.hosts:get( callsign )
		if ip ~= host.ip then self:send( host.ip, env, GAME.CLIENT_PORT ) end
	end
end


function Server:destroy()
	if self.srv then self.srv.destroy() end
end


-- Provide one or more serverside behaviors for a gid / gameobject
-- many behaviors form a personality object
-- every behavior can transition to another within the same personality
-- the personality object is internal only, user provides behaviors
-- if there is only a single behavior, no key is needed ("default")
function Server:putBehavior( gid, behavior, key )
	if self.personalities[ gid ] == nil then 
		self.personalities[ gid ] = Personality.new( gid )
	end

	if key == nil then key = "default" end
	self.personalities[ gid ]:put( key, behavior )

	-- automatically activate behavior if this is the first/only
	if lua.length( self.personalities[ gid ].behaviors  ) == 1 then
		-- set active behavior of this personality
		self.personalities[ gid ].active = key
		-- init behavior
		behavior:init( key )
	end
end


return Server

