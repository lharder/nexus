local udp = require "defnet.udp"
local Envelope = require( "nexus.envelope" )
local Registry = require( "nexus.registry" )
local Commands = require( "level.playground.commands" )
local Events = require( "level.playground.events" )


local SEND_INTERVAL = 1 / 20


local Client = {}
Client.__index = Client

function Client.new()
	local this = {}
	setmetatable( this, Client )

	-- queue of commands to send
	this.queue = {}
	this.nextSendTime = socket.gettime()

	this.registry = Registry.new()
	
	this.indexOfTypes = {}

	local cmd 
	local url
	local id
	this.srv = udp.create( function( data, ip, port )
		assert( data, "Payload must be available in request!" )
		
		cmd = Envelope.deserialize( data )
		-- pprint( "Client " .. GAME.meHost.ip .. " received: " .. getCmdEvtName( cmd ) .. " from " .. ip ) 

		url = cmd:getUrl()
		-- if no absolute url is available, it must be a global id: 
		-- replace globalId with local url
		if url:find( ":/", 1, true ) == nil then 
			id = GAME.client.registry:getClientId( url )
			cmd:setUrl( msg.url( nil, id, nil ) )
		end
		
		msg.post( cmd:getUrl(), GAME.MSG_EXEC_CMD, cmd:toTable() )
			
	end, GAME.CLIENT_PORT )

	return this
end


function Client:send( ip, env, port )
	if ip == nil or env == nil then return end

	-- by default, clients always send to the server
	if port == nil then port = GAME.SERVER_PORT end

	-- important: must make an independent copy to be stored
	-- in the queue! Otherwise undesired changes afterwards possible!
	env = env:deepCopy()
	env.meta:putString( "ip", ip )
	env.meta:putString( "port", port )

	-- redundant information should be sent once per batch only,
	-- e.g. multiple position data of gameobjects. Allow for 
	-- keeping track of all envelopes for the next batch sending
	-- and send only one of that type per batch if flag is set
	if env.meta:get( "latestOnly" ) then 
		-- for "latestOnly"-envelope-types, remember its position 
		-- in array and if another shows up, replace the first
		local index = self.indexOfTypes[ env:getType() ]
		if index then 
			-- previous one already exists, replace in situ
			-- pprint( "Replace envelope: latest only..." )
			self.queue[ index ] = env
		else
			-- first time this type occurrs in this batch
			table.insert( self.queue, env )
			self.indexOfTypes[ env:getType() ] = #self.queue
		end
	else 
		-- any amount of same type envelopes can be sent
		table.insert( self.queue, env )
	end
	
end


-- send the same envelope directly to all other clients
function Client:sendToOtherClients( env )
	for i, callsign in pairs( GAME.match.proposal ) do
		local host = GAME.hosts:get( callsign )
		if host.ip ~= GAME.meHost.ip then 
			self:send( host.ip, env, GAME.CLIENT_PORT ) 
		end
	end
end


function Client:sendToServer( env )
	self:send( GAME:getServerHost().ip, env, GAME.SERVER_PORT )
end


function Client:update()
	-- listen to incoming network packets
	if self.srv then self.srv.update( self ) end

	-- send out events waiting in queue in fixed interval
	now = socket.gettime()
	if now >= self.nextSendTime then
		-- reset clock
		self.nextSendTime = now + SEND_INTERVAL
		-- send out everything in the queue
		-- pprint( "Queue: " .. #self.queue )
		for _, evt in ipairs( self.queue ) do
 			-- pprint( "Client " .. GAME.meHost.ip .. " sending:  " .. getCmdEvtName( evt ) .. " to " .. evt.meta:get( "ip" ) .. ":" .. evt.meta:get( "port" ) )
			self.srv.send( evt:serialize(), evt.meta:get( "ip" ), evt.meta:get( "port" ) )
			self.queue = {}
			self.indexOfTypes = {}
		end
	end
end


function Client:destroy()
	if self.srv then self.srv.destroy() end
end


return Client

