local factorycreate = require( "factorycreate.factorycreate" )
local Commands = require( "nexus.commands" )

local SEC_PER_SYNC = 0.1


-- Allows for different syncproviders for gameobject types.
-- A type is defined by the factoryurl used to create it.
-- The default is to use the same "default" syncprovider 
-- for all entities: syncproviders[ factName ] = { synp }
-- A type may also define that it does not sync at all
-- by setting its syncprovider = nil
local syncproviders = {}


-- Entity -----------------------------------------
local Entity = {}
Entity.__index = Entity

function Entity.create()
	local this = {}
	setmetatable( this, Entity )
	return this
end

function Entity:getParams()
	if self.syncprovider == nil then return end
	return self.syncprovider:get( self )
end

function Entity:setParams( params )
	if self.syncprovider == nil then return end
	return self.syncprovider:set( self, params )
end

function Entity:setSyncProvider( factName )
	self.syncprovider = syncproviders[ factName ] or syncproviders[ "default" ]
	if self.syncprovider == "none" then self.syncprovider = nil end
end



-- Drone, passive entity mirroring a corresponding worker ----
local Drone = {}
Drone.__index = Entity

function Drone.create( cmdattrs )
	local this = {}
	setmetatable( this, Drone )

	local factUrl = msg.url( cmdattrs.factName )
	this.id = factorycreate( factUrl, cmdattrs.pos, cmdattrs.rot, cmdattrs.params, cmdattrs.scale )
	this.gid = cmdattrs.gid
	this.params = {}

	this:setSyncProvider( cmdattrs.factName )

	return this
end


-- Worker, active entity controlling remote drones --------
local Worker = {}
Worker.__index = Entity

function Worker.create( gid, factName, pos, rot, attrs, scale )
	local this = {}
	setmetatable( this, Worker )

	this.id = factorycreate( msg.url( factName ), pos, rot, attrs, scale )
	this.gid = gid
	this.params = {}

	this:setSyncProvider( factName )

	return this
end



-- Puppeteer ----------------------------------------------
local Puppeteer = {}
Puppeteer.__index = Puppeteer

function Puppeteer.create( nexus )
	local this = {}
	setmetatable( this, Puppeteer )

	this.nexus 			= nexus 

	this.workers 		= {}		-- map of workers: 		workers[ id ] = { worker }
	this.workerIds 		= {}		-- map of ids by gids: 	workerIds[ gid ] = id
	this.drones 		= {}		-- map of drones: 		drones[ id ] = { drone }
	this.droneIds		= {}		-- map of ids by gids: 	droneIds[ gid ] = id

	this.nextSyncTime 	= socket.gettime()		-- start sync immediately
	this.coplayers 		= {}					-- all player contacts in this match except me
	this.players		= {}					-- all player contacts in this match
	this.isPlaying 		= false

	return this
end

-- return the global gid to a local id
function Puppeteer:getGid( id )
	local entity = self.workers[ id ] or self.drones[ id ]
	if entity == nil then return nil end
	return entity.gid
end


-- return the host local id for a global gid
function Puppeteer:getId( gid )
	if gid == nil then return nil end
	return self.workerIds[ gid ] or self.droneIds[ gid ]
end


-- create a new worker on this host and multiple drones on remote hosts
function Puppeteer:newEntity( gid, workerFactName, droneFactName, pos, rot, attrs, scale )
	local cmd = Commands.newCreateDrone( gid, droneFactName, pos, rot, attrs, scale ) 
	self.nexus:broadcast( cmd, self.coplayers )

	local worker = Worker.create( gid, workerFactName, pos, rot, attrs, scale )
	self.workers[ worker.id ] = worker
	self.workerIds[ gid ] = worker.id

	return worker.id
end


function Puppeteer:delete( gid, doBroadcast )
	assert( gid, "Object to delete must have a gid!" )

	local id = self:getId( gid )
	if id == nil then go.delete() return end

	if doBroadcast == true then 
		local cmd = Commands.newDelete( gid, go.get_position( id ) )
		self.nexus:broadcast( cmd )
	end

	if self.workers[ id ] 		then self.workers[ id ] = nil 		end
	if self.workerIds[ gid ] 	then self.workerIds[ gid ] = nil 	end
	if self.drones[ id ] 		then self.drones[ id ] = nil 		end
	if self.droneIds[ gid ] 	then self.droneIds[ gid ] = nil 	end

	go.delete( id )
end


-- create a new drone on this host by command of a remote host controlling its worker
function Puppeteer:createDrone( cmdattrs )
	local drone = Drone.create( cmdattrs )
	-- pprint( "createDrone:" .. drone.id )
	self.drones[ drone.id ] = drone
	self.droneIds[ cmdattrs.gid ] = drone.id

	return drone.id
end


function Puppeteer:update( dt )
	if self.isPlaying then 
		if socket.gettime() >= self.nextSyncTime then 
			self.nextSyncTime = socket.gettime() + SEC_PER_SYNC

			-- pprint( table.length( self.workers ) ..  " / " .. table.length( self.drones ) )
			for ip, worker in pairs( self.workers ) do 
				if worker.syncprovider then 
					for ipPort, contact in pairs( self.coplayers ) do
						-- only send data if there are new params (not nil)
						self.params = worker:getParams()
						if self.params then  
							local cmd = Commands.newUpdate( worker.gid, self.params ) 
							self.nexus:broadcast( cmd, self.coplayers )
						end
					end
				end
			end

		end
	end
end


-- Sets the syncprovider for every type of managed entity:
-- syncproviders get/set data to be synced autom. at a constant rate.
-- Every entity type may sync different data and use its own provider.
-- If a syncprovider is set without a factoryUrl, that is the default.
-- If a factUrl is set but the syncprovider is nil then that means
-- that for this type of entity, no automatic sync is intended.
function Puppeteer:setSyncProvider( synp, factName )
	-- without factoryUrl, treat as default
	if factName == nil then factName = "default" end
	syncproviders[ factName ] = synp 

	-- without syncprovider, do not sync for this type
	if synp == nil then syncproviders[ factName ] = "none" end
end


function Puppeteer:start()
	-- cleanup matcher info: not required anymore
	for ipPort, contact in pairs( self.nexus.contacts ) do
		contact.proposal = nil
		if contact.game and contact.game.proposal then contact.game.proposal = nil end
	end		

	self.coplayers = self.nexus:coplayers()
	self.players = self.nexus:players()

	self.isPlaying = true
end

function Puppeteer:stop()
	self.isPlaying = false 
end


return Puppeteer

