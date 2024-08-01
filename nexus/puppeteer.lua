local factorycreate = require( "factorycreate.factorycreate" )
local Commands = require( "nexus.commands" )

local SEC_PER_SYNC = 0.1


-- Allows for different syncproviders for gameobject types.
-- A type is defined by the factoryurl used to create it.
-- The default is to use the same "default" syncprovider 
-- for all entities: syncproviders[ factName ] = { synp }
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
	return self.syncprovider:get( self )
end

function Entity:setParams( params )
	return self.syncprovider:set( self, params )
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
	this.syncprovider = syncproviders[ cmdattrs.factName ] or syncproviders[ "default" ]

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
	this.syncprovider = syncproviders[ factName ] or syncproviders[ "default" ]

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

	this.nextSyncTime 	= socket.gettime()					-- start sync immediately
	this.others 		= {}
	this.isPlaying 		= false
	
	return this
end

-- return the global gid to a local id
function Puppeteer:getGid( id )
	local entity = self.workers[ id ] or self.drones[ id ]
	return entity.gid
end


-- return the host local id for a global gid
function Puppeteer:getId( gid )
	return self.workerIds[ gid ] or self.droneIds[ gid ]
end


-- create a new worker on this host and multiple drones on remote hosts
function Puppeteer:newEntity( gid, workerFactName, droneFactName, pos, rot, attrs, scale )
	local cmd = Commands.newCreateDrone( gid, droneFactName, pos, rot, attrs, scale ) 
	self.nexus:broadcast( cmd, self.others )

	local worker = Worker.create( gid, workerFactName, pos, rot, attrs, scale )
	self.workers[ worker.id ] = worker
	self.workerIds[ gid ] = worker.id
	
	return worker.id
end


function Puppeteer:delete( gid, doBroadcast )
	assert( gid, "Object to delete must have a gid!" )
	
	local id = self:getId( gid )
	if id == nil then pprint( "Delete id is nil: " .. gid ) return end

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
			
			for ip, worker in pairs( self.workers ) do 
				for ipPort, contact in pairs( self.others ) do
					local cmd = Commands.newUpdate( worker.gid, worker:getParams() ) 
					self.nexus:broadcast( cmd, self.others )
				end
			end
			
		end
	end
end


function Puppeteer:setSyncProvider( synp, factName )
	if not factName then factName = "default" end
	syncproviders[ factName ] = synp 
end


function Puppeteer:start()
	-- cleanup matcher info: not required anymore
	for ipPort, contact in pairs( self.nexus.contacts ) do
		contact.proposal = nil
		if contact.game and contact.game.proposal then contact.game.proposal = nil end
	end		
	
	self.others = self.nexus:others()
	self.isPlaying = true
end

function Puppeteer:stop()
	self.isPlaying = false 
end


return Puppeteer

