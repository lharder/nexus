local Commands = require( "nexus.commands" )
local Stack = require( "nexus.stack" )
local udp = require( "defnet.udp" )

local COM_PORT = 5898
local MSG_PER_SEC = 6


function round( num )
	return math.floor( num + .5 )
end

local function equals( v1, v2 )
	return 	math.abs( round( v1.x ) ) == math.abs( round( v2.x ) ) and
	math.abs( round( v1.y ) ) == math.abs( round( v2.y ) ) and
	math.abs( round( v1.z ) ) == math.abs( round( v2.z ) ) 
end


-- create gameobjects with complex init data.
-- go script must be ready to process an "init" msg with params after creation
local function factorycreate( facturl, pos, rot, params, scale )
	local id = factory.create( facturl , pos, rot, nil, scale )
	msg.post( id, "init", params )
	return id
end


local function createDrone( self, cmd )
	-- cmd.pos.x = cmd.pos.x + 530

	-- local drone game object, remote controlled
	local id = factorycreate( cmd.factUrl, cmd.pos, cmd.rot, cmd.params, cmd.scale )

	self.passives.gids[ id ] = cmd.gid
	self.passives.ids[ cmd.gid ] = id
end


local function deleteDrone( self, cmd )
	local id = self.passives.ids[ cmd.gid ]
	if id then 
		self.passives.ids[ cmd.gid ] = nil
		self.passives.gids[ id ] = nil
		go.delete( id, cmd.recursive )
	end
end


local function updateDrone( self, cmd )
	-- cmd.pos.x = cmd.pos.x + 530

	-- calculate position of active GO msgPerSecFraction secs in the future...
	local id = self.passives.ids[ cmd.gid ]
	if self.passives.data[ cmd.gid ] == nil then self.passives.data[ cmd.gid ] = {} end

	self.passives.data[ cmd.gid ].target = cmd.pos + cmd.dir * cmd.speed * self.msgPerSecFraction
	self.passives.data[ cmd.gid ].speed = cmd.speed
	self.passives.data[ cmd.gid ].degrees = cmd.degrees
end


local function playFlipbookDrone( self, cmd )
	local id = self.passives.ids[ cmd.gid ]
	if id then sprite.play_flipbook( msg.url( nil, id, cmd.sprite ), cmd.anim ) end
end


local function doSoundDrone( self, cmd )
	local id = self.passives.ids[ cmd.gid ]
	if id then 
		local url = msg.url( nil, id, cmd.sound )
		if cmd.doplay then sound.play( url, cmd.props ) else sound.stop( url ) end
	end
end


local function sendMsgCmd( self, cmd )
	local id = self.passives.ids[ cmd.gid ]
	if id then msg.post( id, cmd.message_id, cmd.message ) end
end


local function execCmd( self, cmd )
	if cmd.type then 
		if cmd.type == Commands.CREATE then
			createDrone( self, cmd.attrs )

		elseif cmd.type == Commands.DELETE then
			deleteDrone( self, cmd.attrs )

		elseif cmd.type == Commands.UPDATE then
			updateDrone( self, cmd.attrs )

		elseif cmd.type == Commands.ANIMATE then 
			playFlipbookDrone( self, cmd.attrs )

		elseif cmd.type == Commands.SOUND then 
			doSoundDrone( self, cmd.attrs )

		elseif cmd.type == Commands.MESSAGE then
			sendMsgCmd( self, cmd.attrs )
		end
	end
end


local function doSoundPlayer( self, url, doPlay, props )
	assert( url.path, "Please provide a proper url!" )

	local gid = self.actives.gids[ url.path ]
	local cmd = Commands.newSound( gid, url.fragment, doPlay, props )
	self.actives.cmdQueue:push( cmd )

	if doPlay then sound.play( url, props ) else sound.stop( url ) end
end	



-- Puppeteer --------------------------
local Puppeteer = {}
Puppeteer.__index = Puppeteer

function Puppeteer.new( gamemaster, mycontact, others  )
	local this = {}
	setmetatable( this, Puppeteer )

	this.mycontact = mycontact
	this.others = others or {}
	this.contacts = {}

	table.insert( this.contacts, mycontact )
	for i, other in ipairs( others ) do 
		table.insert( this.contacts, other ) 
	end

	this.isMaster = ( mycontact.ip == gamemaster.ip )
	this.msgPerSecFraction = 1 / MSG_PER_SEC

	this.actives = {}
	this.actives.gids = {}
	this.actives.ids = {}
	this.actives.cmdQueue = Stack.new()

	this.passives = {}
	this.passives.gids = {}
	this.passives.ids = {}
	this.passives.data = {}

	this.time = 0

	this.srv = udp.create( function( data, ip, port )
		if data == nil then return end
		execCmd( this, sys.deserialize( data ) )
	end, COM_PORT )

	return this
end


function Puppeteer:sendToOthers( cmd ) 
	if cmd == nil then return end

	local serialized = sys.serialize( cmd )
	for i, contact in ipairs( self.others ) do
		self.srv.send( serialized, contact.ip, contact.port )
	end
end


function Puppeteer:create( gid, factUrlCtrl, factUrlDrone, pos, rot, params, scale )
	assert( gid, "gid of new puppet must not be nil!" )

	local id = factorycreate( factUrlCtrl, pos, rot, params, scale )

	self.actives.gids[ id ] = gid
	self.actives.ids[ gid ] = id

	local cmdCreate = Commands.newCreate( gid, factUrlDrone, pos, rot, params, scale ) 
	self:sendToOthers( cmdCreate )
end


function Puppeteer:delete( gid, recursive )
	assert( gid, "gid of puppet to be deleted must not be nil!" )

	local id = self.actives.ids[ gid ]
	if id then 
		local cmd = Commands.newDelete( gid, recursive )
		self:sendToOthers( cmd )

		go.delete( id, recursive )
		self.actives.gids[ id ] = nil
		self.actives.ids[ gid ] = nil
	end
end


function Puppeteer:animate( url, anim )
	assert( url.path, "Please provide a proper url!" )

	local gid = self.actives.gids[ url.path ]
	local cmd = Commands.newAnimate( gid, url.fragment, anim )
	self.actives.cmdQueue:push( cmd )
	sprite.play_flipbook( url, anim )
end


function Puppeteer:soundPlay( url, props ) 
	doSoundPlayer( self, url, true, props )
end

function Puppeteer:soundStop( url, props ) 
	doSoundPlayer( self, url, false, props )
end


-- methods -------------------
function Puppeteer:update( dt )
	if self.srv then self.srv:update() end

	self.time = self.time + dt
	if self.time >= self.msgPerSecFraction then 
		self.time = 0
		-- every 1 / msgPerSec seconds, broadcast active GOs' 
		-- data to all other members
		for id, gid in pairs( self.actives.gids ) do
			local scrurl = msg.url( nil, id, "script" )
			self:sendToOthers( 
				Commands.newUpdate( 
					gid, 
					go.get_position( id ),
					go.get( id, "euler.z" ),
					go.get( scrurl, "dir" ),
					go.get( scrurl, "speed" )
				)
			)
		end

		-- also send all custom and non-update commands that
		-- may have been queued up since last sending
		local cmd
		repeat
			cmd = self.actives.cmdQueue:pop()
			if cmd then self:sendToOthers( cmd ) end
		until( cmd == nil )
	else
		-- every other frame, move passive GOs according to the
		-- data that has most recently been received from active
		local data
		local target
		local pos
		local speed
		local dir
		for id, gid in pairs( self.passives.gids ) do
			data = self.passives.data[ gid ]
			if data then 
				-- position
				pos = go.get_position( id )
				dir = data.target - pos 
				if vmath.length( dir ) > 0 then dir = vmath.normalize( dir ) end

				-- target pos has not been reached yet: MUST move, even if the master go has
				-- already stopped moving / no speed! In that case, continue with previous speed
				if not equals( data.target, pos ) then
					url = msg.url( nil, id, "script" )
					if data.speed == 0 then speed = go.get( url, "speed" ) else speed = data.speed end
					go.set( url, "speed", speed )
					go.set_position( pos + dir * speed * dt, id )
				end

				-- rotation
				go.animate( id, "euler.z", go.PLAYBACK_ONCE_FORWARD, data.degrees, go.EASING_LINEAR, self.msgPerSecFraction )
			end
		end
	end
end


function Puppeteer:getGid( id )
	return self.actives.gids[ id ] or self.passives.gids[ id ]
end 


function Puppeteer:getId( gid )
	return self.actives.ids[ gid ] or self.passives.ids[ gid ]
end 


return Puppeteer


