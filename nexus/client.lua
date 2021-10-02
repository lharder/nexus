require( "deflibs.defold" )

local udp = require "defnet.udp"
local Envelope = require( "nexus.envelope" )
local Syncpack = require( "nexus.syncpack" )
local Registry = require( "nexus.registry" )
local Syncmap = require( "nexus.syncmap" )

local EVENT_TYPE_SYNC = -1
local MSG_EXEC_CMD 	= hash( "execCmd" )


-- Syncinfo ----------------------
local Syncinfo = {}
function Syncinfo.new( gid, custKeyTypes )
	local this = {}

	this.gid = gid
	this.custKeyTypes = custKeyTypes
	this.hasCustomProps = custKeyTypes ~= nil

	return this
end


-- Client -------------------------
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
	this.state = Syncmap.new( this )

	-- server for auto sync gameobject states
	this.syncer = udp.create( function( data, ip, port )
		-- nexus sync events for gameobjects
		local evt = Syncpack.deserialize( data )

		gid = evt:getGlobalId()
		if gid then 
			cid = this.registry:getClientId( gid )

			-- Might be that the gameobject no longer exists:
			-- level (un)loading kills them while packets are
			-- on the wire. Costs a little performance, not much:
			-- go.get_position()  				-- 0.0020
			-- pcall( go.get_position, nil )  	-- 0.0021
			-- goExists( nil )  				-- 0.0024
			if cid and goExists( cid ) then 			
				pos = evt:getPosition()
				if pos then go.set_position( pos, cid ) end

				rot = evt:getRotation()
				if rot then go.set_rotation( rot, cid ) end

				if evt:hasCustomProps() then 
					for key, value in pairs( evt.attrs ) do 
						go.set( msg.url( nil, cid, "script" ), key, value )
					end
				end
			end
		end
	end, game.SYNC_PORT )

	-- server for regular communications
	this.srv = udp.create( function( data, ip, port )
		local evt = Envelope.deserialize( data )

		-- internal nexus system envelopes 
		if evt:isInternal() then 
			-- currently, only one internal type: sync state variables.
			-- gid is used as namespace for key/value pairs
			local gid = evt:getUrl()
			for k, v in pairs( evt:toTable().attrs ) do
				this.state:put( gid, k, v )
				pprint( this.state:get( gid, k ) )
			end
			
		else
			-- custom game logic events 
			local url = evt:getUrl()
			-- if no absolute url is available, it must be a global id: 
			-- replace globalId with local url
			if url:find( ":/", 1, true ) == nil then 
				evt:setUrl( msg.url( nil, game.client.registry:getClientId( url ), nil ) )
			end

			msg.post( evt:getUrl(), game.MSG_EXEC_CMD, evt:toTable() )
		end
	end, game.CLIENT_PORT )

	return this
end


function Client:send( ip, env, port )
	if ip == nil or env == nil then return end

	-- by default, clients always send to client port
	if port == nil then port = self.game.CLIENT_PORT end

	-- important: must make an independent copy to be stored
	-- in the queue! Otherwise undesired changes afterwards possible!
	env = env:deepCopy()
	env:setIP( ip )
	env:setPort( port )

	self.queue[ #self.queue + 1 ] = env 
end


-- send the same envelope to all clients
function Client:sendToClients( env )
	for i, callsign in pairs( self.game.match.proposal ) do
		local host = self.game.hosts:get( callsign )
		self:send( host.ip, env, self.game.CLIENT_PORT ) 
	end
end

-- send the same envelope to all clients except the given ip
function Client:sendToClientsExcept( ip, env )
	for i, callsign in pairs( self.game.match.proposal ) do
		local host = self.game.hosts:get( callsign )
		if ip ~= host.ip then self:send( host.ip, env, self.game.CLIENT_PORT ) end
	end
end


-- send the same envelope to all other clients except me
function Client:sendToOtherClients( env )
	self:sendToClientsExcept( self.game.meHost.ip, env )
end


function Client:sendToServer( env )
	self:send( self.game:getServerHost().ip, env )
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
			for i, syncinfo in ipairs( self.syncObjs ) do
				local cid = self.registry:getClientId( syncinfo.gid )
				if cid then
					local syncpack = Syncpack.new( syncinfo.gid )
					syncpack:setPosition( go.get_position( cid ) )
					syncpack:setRotation( go.get_rotation( cid ) )

					-- try to avoid custom properties! Cost performance.
					-- But if necessary, include keys, types and values...
					if syncinfo.hasCustomProps then 
						for _, kt in ipairs( syncinfo.custKeyTypes ) do 
							syncpack:put( kt.key, kt.type, go.get( msg.url( nil, cid, "script" ), kt.key ) )
						end
					end

					-- send syncpack to all clients
					for i, callsign in pairs( self.game.match.proposal ) do
						local host = self.game.hosts:get( callsign )
						if host.ip ~= self.game.meHost.ip then 
							self.srv.send( syncpack:serialize(), host.ip, self.game.SYNC_PORT ) 
						end
					end
				else
					-- object no longer exists, stop sync automatically
					table.remove( self.syncObjs, i )
				end
			end
		end

		-- send out everything in the queue
		-- pprint( "Queue: " .. #self.queue )
		for _, evt in ipairs( self.queue ) do
			-- pprint( "Client " .. self.game.meHost.ip .. " sending:  " .. Event.getName( evt ) .. " to " .. evt:getIP() .. ":" .. evt:getPort() )
			self.srv.send( evt:serialize(), evt:getIP(), evt:getPort() )
			self.queue = {}
		end
	end
end


function Client:destroy()
	if self.srv then self.srv.destroy() end
	if self.syncer then self.syncer.destroy() end
end


function Client:sync( gid, custKeyTypes )
	-- ---------------------------------
	-- Convention: Nexus assumes custom properties to be 
	-- defined in a gameobject script named "{cid}#script"!
	-- ---------------------------------
	table.insert( self.syncObjs, Syncinfo.new( gid, custKeyTypes ) )
end


return Client

