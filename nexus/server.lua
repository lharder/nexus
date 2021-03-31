local udp = require "defnet.udp"
local Envelope = require( "nexus.envelope" )
local Personality = require( "nexus.personality" )
local lua = require( "deflibs.lualib" )
local Events = require( "level.playground.events" )
local Commands = require( "level.playground.commands" )


local SEND_INTERVAL = 1 / 20

local now 


local Server = {}
Server.__index = Server

function Server.new()
	local this = {}
	setmetatable( this, Server )

	-- queue of commands to send
	this.queue = {}
	this.nextSendTime = socket.gettime()

	-- serverside behaviors
	this.personalities = {}
	
	-- listen to incoming events
	this.srv = udp.create( function( data, ip, port )
		assert( data, "Received udp data must not be nil!" )
		
		-- incoming event from one of the clients
		local evt = Envelope.deserialize( data )
		-- pprint( "Server " .. GAME.meHost.ip .. " received: " .. getCmdEvtName( evt ) )
		
		-- events contain the gid of the gameobject emitting this event as url
		local gid = evt:getUrl()
		if this.personalities[ gid ] then 
			-- pprint( GAME.meHost.ip .. ".onmessage( " .. getCmdEvtName( evt ) .. " ) ) to " .. gid .. " from " .. ip )
			this.personalities[ gid ]:getActiveBehavior():onmessage( evt, ip, port )
		end
	end, GAME.SERVER_PORT )
	
	return this
end


function Server:update( dt )
	if self.srv then 
		-- listen to incoming network packets
		self.srv.update()

		-- send out commands in regular intervals
		now = socket.gettime()
		-- pprint( "tick" )
		if now >= self.nextSendTime then
			-- pprint( "tick - send" )
			-- reset clock
			self.nextSendTime = now + SEND_INTERVAL
			-- send out everything in the queue
			for _, cmd in ipairs( self.queue ) do
				-- pprint( "Server " .. GAME.meHost.ip .. " sending:  " .. getCmdEvtName( cmd ) .. " to " .. cmd.meta:get( "ip" ) )
				self.srv.send( cmd:serialize(), cmd.meta:get( "ip" ), GAME.CLIENT_PORT )
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
	env.meta:putString( "ip", ip )
	env.meta:putString( "port", port )
	table.insert( self.queue, env )
end


-- send the same command to all clients
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
	self.personalities[ gid ]:put( behavior, key )

	-- automatically activate behavior if this is the first/only
	if lua.length( self.personalities[ gid ].behaviors  ) == 1 then
		-- set active behavior of this personality
		self.personalities[ gid ].active = key
		-- init behavior
		behavior:init( key )
	end
end


return Server

