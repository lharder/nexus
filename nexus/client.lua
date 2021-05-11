local udp = require "defnet.udp"
local Envelope = require( "nexus.envelope" )
local Syncset = require( "nexus.syncset" )
local Registry = require( "nexus.registry" )
local Events = require( "level.playground.events" )

local EVENT_TYPE_SYNC = -1
local MSG_EXEC_CMD 	= hash( "execCmd" )


local function syncHandler( data, ip, port )
	-- nexus sync events for gameobjects
	local evt = Syncset.deserialize( data )

	gid = evt:getGlobalId()
	if gid then 
		cid = this.registry:getClientId( gid )
		if cid then
			pos = evt:getPosition()
			if pos then go.set_position( pos, cid ) end

			rot = evt:getRotation()
			if rot then go.set_rotation( rot, cid ) end
		end
	end
end



local Client = {}
Client.__index = Client

function Client.new( game )
	local this = {}
	setmetatable( this, Client )

	this.game = game

	-- queue of events to send
	this.queue = {}
	this.nextSendTime = socket.gettime()
	this.syncObjs = {}
	this.registry = Registry.new()
	this.indexOfTypes = {}

	this.syncer = udp.create( syncHandler, game.SYNC_PORT )
	
	this.srv = udp.create( function( data, ip, port )
		local evt = Envelope.deserialize( data )

		-- custom game events
		local url = evt:getUrl()
		-- if no absolute url is available, it must be a global id: 
		-- replace globalId with local url
		if url:find( ":/", 1, true ) == nil then 
			evt:setUrl( msg.url( nil, game.client.registry:getClientId( url ), nil ) )
		end

		msg.post( evt:getUrl(), game.MSG_EXEC_CMD, evt:toTable() )
	end, game.CLIENT_PORT )

	return this
end


function Client:send( ip, env, port )
	if ip == nil or env == nil then return end

	-- by default, clients always send to the server
	if port == nil then port = self.game.SERVER_PORT end

	-- important: must make an independent copy to be stored
	-- in the queue! Otherwise undesired changes afterwards possible!
	env = env:deepCopy()
	env:setIP( ip )
	env:setPort( port )

	-- redundant information should be sent once per batch only,
	-- e.g. multiple position data of gameobjects. Allow for 
	-- keeping track of all envelopes for the next batch sending
	-- and send only one of that type per batch if flag is set
	if env:getLatestOnly() then 
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
	for i, callsign in pairs( self.game.match.proposal ) do
		local host = self.game.hosts:get( callsign )
		if host.ip ~= self.game.meHost.ip then 
			self:send( host.ip, env, self.game.CLIENT_PORT ) 
		end
	end
end


function Client:sendToServer( env )
	self:send( self.game:getServerHost().ip, env, self.game.SERVER_PORT )
end


function Client:update()
	-- listen to incoming network packets
	if self.srv then self.srv.update( self ) end
	if self.syncer then self.syncer.update( self ) end

	-- send out events waiting in queue in fixed interval
	now = socket.gettime()
	if now >= self.nextSendTime then
		-- reset clock
		self.nextSendTime = now + self.game.SEND_INTERVAL

		-- send auto synced objects' data in a single event
		if #self.syncObjs > 0 then
			-- send out properties of auto-synced objects 
			for i, gid in ipairs( self.syncObjs ) do
				local cid = self.registry:getClientId( gid )
				if cid then
					local syncset = Syncset.new( gid )
					syncset:setPosition( go.get_position( cid ) )
					syncset:setRotation( go.get_rotation( cid ) )
				else
					-- object no longer exists, stop sync automatically
					table.remove( self.syncObjs, i )
				end

				for i, callsign in pairs( self.game.match.proposal ) do
					local host = self.game.hosts:get( callsign )
					if host.ip ~= self.game.meHost.ip then 
						self.srv.send( syncset:serialize(), host.ip, self.game.SYNC_PORT ) 
					end
				end
			end
		end

		-- send out everything in the queue
		-- pprint( "Queue: " .. #self.queue )
		for _, evt in ipairs( self.queue ) do
			-- pprint( "Client " .. self.game.meHost.ip .. " sending:  " .. Event.getName( evt ) .. " to " .. evt:getIP() .. ":" .. evt:getPort() )
			self.srv.send( evt:serialize(), evt:getIP(), evt:getPort() )
			self.queue = {}
			self.indexOfTypes = {}
		end
	end
end


function Client:destroy()
	if self.srv then self.srv.destroy() end
	if self.syncer then self.syncer.destroy() end
end


function Client:sync( gid )
	table.insert( self.syncObjs, gid )
end


return Client

