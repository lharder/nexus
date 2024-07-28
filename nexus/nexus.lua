local PORTS = require( "nexus.ports" )
local Localhost = require( "nexus.localhost" )
local b64 = require( "nexus.b64" )
local CmdServer = require( "nexus.cmdserver" )
local Commands = require( "nexus.commands" )
local Beacon = require( "nexus.beacon" )
local Matcher = require( "nexus.matcher" )
local Puppeteer = require( "nexus.puppeteer" )
local SyncProvider = require( "nexus.syncprovider" )


local MAX_INT_32 = 2^32

-- Nexus ----------------------------------------------
local Nexus = {}
Nexus.__index = Nexus


function Nexus.create( gamename, gameversion )
	local this = {}
	setmetatable( this, Nexus )

	this.CUSTOM_MSG = hash( "nexusMsg" )
	
	this.gamename 		= gamename
	this.gameversion	= gameversion
	this.contacts		= {}
	this.beacon 		= Beacon.create( this )
	this.matcher		= Matcher.create( this )
	this.puppeteer		= Puppeteer.create( this )

	-- default sync provider
	local synp = SyncProvider.create( 
		-- get params
		function( entity ) 
			entity.params.pos = go.get_position( entity.id )
			entity.params.rot = go.get_rotation( entity.id )
			return entity.params
		end, 
		-- set params
		function( entity, params ) 
			go.animate( entity.id, "position", go.PLAYBACK_ONCE_FORWARD, params.pos, go.EASING_LINEAR, .2 )
			go.animate( entity.id, "rotation", go.PLAYBACK_ONCE_FORWARD, params.rot, go.EASING_LINEAR, .2 )
			entity.params = params
		end 
	)
	this.puppeteer:setSyncProvider( synp )
	
	-- command server ------------------------------
	this.cmdsrv = CmdServer.create( PORTS[ 1 ], 
		function( ip, port, client )
			pprint( ( "Tcp client %s:%d connected!" ):format( ip, port ) )
		end, 

		function( ip, port, client )
			pprint( ( "Tcp client %s:%d disconnected!" ):format( ip, port ) )
		end,

		PORTS[ 2 ] 
	)

	this.cmdsrv.ip = Localhost.getIP()

	-- Request handlers logic -----------------------
	-------------------------------------------------
	-- New profile announced: a tcp contact must provide the name 
	-- and version of the game it wants to play. If it does not, then 
	-- it is not a valid game client and must be removed from the list
	-- of valid contacts.    
	this.cmdsrv:addCmdHandler( Commands.ANNOUNCE, function( cmdattrs ) 
		-- pprint( "Announce message received."  )
		if cmdattrs.gamename == this.gamename then 
			-- internal information, not needed for player profile
			cmdattrs.gamename = nil
			cmdattrs.gameversion = nil
			
			-- Accept this client: it wants to play our game!
			local contact = this.contacts[ cmdattrs.id ]
			if contact ~= nil then 
				-- set or update player's profile in case of changes
				contact.profile = cmdattrs
				
				-- Call handler only the first time player is discovered!
				if contact.accepted == nil then this.beacon:onPlayerConnect( contact ) end
				contact.accepted = socket.gettime()
			end
		end
	end )

	-- new incoming proposal --------------------------
	this.cmdsrv:addCmdHandler( Commands.PROPOSE, function( cmdattrs ) 
		-- local ipPort = ( "%s:%s" ):format( this.cmdsrv.ip, this.cmdsrv.port )
		-- pprint( ( "Message with proposal profiles from %s received at %s" ):format( cmdattrs.id,  ipPort ) )
		
		if this.contacts[ cmdattrs.id ] ~= nil then 
			this.contacts[ cmdattrs.id ].proposal = cmdattrs.profiles
			-- pprint( this.contacts[ cmdattrs.id ].proposal )
		end
	end )

	-- incoming readyToPlay messages to the designated gamemaster only 
	-- All players must declare readiness, then gamemaster signals start
	-- Gamemaster must start last to be certain that clients will receive
	-- all commands to setup the first game level properly.
	this.cmdsrv:addCmdHandler( Commands.READYTOPLAY, function( cmdattrs ) 
		pprint( "Status 'ReadyToPlay' confirmed by:" .. cmdattrs.id )

		local game = this:me().game
		if game and game.isGamemaster == true then 
			if game.profiles[ cmdattrs.id ] ~= nil then 
				game.profiles[ cmdattrs.id ].isReadyToPlay = true
				-- pprint( game.profiles[ cmdattrs.id ] )
			end
		
			-- have all other players sent their ready report to me?
			local cntReadys = 1
			for ipPort, profile in pairs( game.profiles ) do 
				if profile.isReadyToPlay then cntReadys = cntReadys + 1 end
			end	
			
			-- send command to all clients to stop waiting and start the game 
			if cntReadys == table.length( game.profiles ) then 
				local cmd = Commands.newStartToPlay()
				local gamecontacts = {}
				for ipPort, profile in pairs( game.profiles ) do 
					gamecontacts[ ipPort ] = this.contacts[ ipPort ]
				end
				this:broadcast( cmd, gamecontacts )

				-- execute the callbacks from match making done:
				-- should lead to loading of playground level
				-- and immediate start of the action. Normally,
				-- should be only one callback function:
				if #this.matcher.callbacks > 0 then 
					for i, callback in ipairs( this.matcher.callbacks ) do callback() end
					this.matcher.callbacks = {}
				end
			end
		else
			pprint( "But I am NOT the gamemaster for this proposal! I should not receive this message!" )
		end
	end )

	
	-- Game start command for clients to stop waiting ---------------
	this.cmdsrv:addCmdHandler( Commands.STARTTOPLAY, function( cmdattrs ) 
		local ipPort = ( "%s:%s" ):format( this.cmdsrv.ip, this.cmdsrv.port )
		pprint( "StartToPlay message received at " .. ipPort )

		-- execute callback from nexus:readytoplay( cb )
		-- There may be several callback functions.
		if #this.matcher.callbacks > 0 then 
			for i, callback in ipairs( this.matcher.callbacks ) do callback() end
			this.matcher.callbacks = {}
		end
	end )


	-- Create a new remote controlled drone on this host
	this.cmdsrv:addCmdHandler( Commands.CREATE_DRONE, function( cmdattrs ) 
		local ipPort = ( "%s:%s" ):format( this.cmdsrv.ip, this.cmdsrv.port )
		-- pprint( "CreateDrone message received at " .. ipPort )
		this.puppeteer:createDrone( cmdattrs )
	end )


	-- Update a remote drone entity with params from its worker
	this.cmdsrv:addCmdHandler( Commands.UPDATE, function( cmdattrs ) 
		local id = this.puppeteer.droneIds[ cmdattrs.gid ]
		if id then this.puppeteer.drones[ id ]:setParams( cmdattrs ) end
	end )
	
	-- Send a custom message from a remote game host to an entity that is 
	-- either worker or drone on this host. If it is neither, try using
	-- the gid as a local id: allows for sending to static, non-nexus
	-- gameobjects with a fixed id at compile time (e.g. doors, etc). 
	this.cmdsrv:addCmdHandler( Commands.CUSTOM_MESSAGE, function( cmdattrs ) 
		local id = this.puppeteer.droneIds[ cmdattrs.gid ]
		if id == nil then id = this.puppeteer.workerIds[ cmdattrs.gid ] end
		if id == nil then id = cmdattrs.gid end
		if id and go.exists( id ) then 
			-- pprint( "Sending custom message (" .. cmdattrs.gid .. ") to " .. id )
			msg.post( id, this.CUSTOM_MSG, cmdattrs ) 
		else
			pprint( "Custom message for unknown id ignored: " .. cmdattrs.gid )
		end
	end )


	-- delete local entity, worker or drone, for a given gid
	this.cmdsrv:addCmdHandler( Commands.DELETE, function( cmdattrs ) 
		local id = this.puppeteer:getId( cmdattrs.gid )
		if id == nil then return end 
		go.animate( id, "position", go.PLAYBACK_ONCE_FORWARD, cmdattrs.pos, go.EASING_LINEAR, .1, 0, function() 
			-- delete only locally, do not broadcast (again)
			-- make sure the worker's delete position is reached before being deleted
			this.puppeteer:delete( cmdattrs.gid, false )
		end )
	end )
	
	return this
end


-- Beacon search ---------------
function Nexus:startsearch( callsign, onClientConnect, onClientDisconnect )
	self.beacon:search( callsign, onClientConnect, onClientDisconnect )
end

function Nexus:stopsearch( callsign )
	self.beacon:stop()
end

-- Matcher proposal -------------
function Nexus:startpropose( profiles, fnOnMatchFound )
	self.matcher:start( profiles, fnOnMatchFound )
end

function Nexus:stoppropose( callsign )
	self.matcher:stop()
	self.puppeteer:start()
end

function Nexus:readytoplay( callback )
	-- custom game usage
	self.matcher:readytoplay( callback )
end

-- Puppeteer ---------------------
function Nexus:setSyncProvider( syncprov, facturl )
	self.puppeteer:setSyncProvider( syncprov, facturl )
end

-- return the global gid to a local id
function Nexus:getGid( id )
	return self.puppeteer:getGid( id )
end

-- return the host local id for a global gid
function Nexus:getId( gid )
	return self.puppeteer:getId( gid )
end


function Nexus:newEntity( gid, workerFactName, droneFactName, pos, rot, attrs, scale )
	return self.puppeteer:newEntity( gid, workerFactName, droneFactName, pos, rot, attrs, scale )
end


function Nexus:delete( gid )
	-- broadcast to all clients
	self.puppeteer:delete( gid, true )
end


-- Nexus -------------------------
function Nexus:update( dt )	
	-- update communications: server
	self.cmdsrv:update( dt ) 
	self.beacon:update( dt ) 
	self.matcher:update( dt ) 
	self.puppeteer:update( dt ) 

	-- update communications: discovered client connections
	for ip, contact in pairs( self.contacts ) do contact.tcpclient.update() end
end


function Nexus:send( cmd, contact )
	if cmd == nil or contact == nil then return false end
	contact.tcpclient.send( b64.encode( cmd:serialize() ) .. "\n" )
end

function Nexus:broadcast( cmd, contacts )
	if cmd == nil then return end
	if contacts == nil then contacts = self:others() end

	local payload = b64.encode( cmd:serialize() ) .. "\n"
	for ipPort, contact in pairs( contacts ) do
		contact.tcpclient.send( payload )
		
		-- if cmd.type ~= Commands.UPDATE then 
		-- 	pprint( "Broadcasting to " .. tostring(contact.profile.callsign) .. " at " .. ipPort ) 
		-- end
	end
end

-- my own contact object
function Nexus:me()
	local ipPort = ( "%s:%s" ):format( self.cmdsrv.ip, self.cmdsrv.port )
	return self.contacts[ ipPort ]
end


-- returns the local gameobject's id of a global entity on this host
function Nexus:getId( gid )
	return self.puppeteer.workerIds[ gid ]
end

-- returns the global entity id of a local gameobject
function Nexus:getGid( id )
	return self.puppeteer.workers[ id ].gid
end


-- make unique global id for puppeteer gameobjects
function Nexus:makeGid( key )
	if key == nil then key = "" .. socket.gettime() .. math.random( 0, MAX_INT_32 ) end
	return self:me().profile.callsign .. "-" .. key 
end


-- return all contacts filtered by a custom function:
-- if it returns true that contact is included in the result
function Nexus:filter( fnFilter )
	if fnFilter == nil then 
		fnFilter = function( c ) return true end 
	end
	
	local results = {}
	for ipPort, contact in pairs( self.contacts ) do
		if fnFilter( contact ) then results[ ipPort ] = contact end
	end
	-- pprint( "Nexus:filter() rendered " .. table.length( results ) .. " results" )
	return results
end

-- all other contacts except myself
function Nexus:others()
	return self:filter( function( contact ) 
		return ( contact.ip ~= self.cmdsrv.ip ) or ( contact.port ~= self.cmdsrv.port )
	end )
end


return Nexus
