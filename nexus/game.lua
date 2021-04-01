local lua = require( "deflibs.lualib" )
local Map = require( "nexus.map" )
local udp = require( "defnet.udp" )
local Beacon = require( "nexus.beacon" )
local Server = require( "nexus.server" )
local Client = require( "nexus.client" )


local function lastOctet( ipv4 )
	if ipv4 == nil then return end
	local octets = ipv4:split( "." )
	if #octets ~= 4 then return nil end
	
	return tonumber( octets[ 4 ] )
end


local function selectServerHost( fixedIp )
	local srv 
	local max = 0
	for _, callsign in ipairs( GAME.hosts:keys() ) do
		local host = GAME:getHost( callsign )
		if fixedIp then
			-- select the host with a given ip
			if host.ip == fixedIp then return host end

		else
			-- no fixed id is provided, use arbitrary algorithm:
			-- host with highest last octet of ip becomes server
			local oct = lastOctet( host.ip )
			if oct > max then 
				srv = host
				max = oct
			end
		end
	end
	return srv
end


-- Game ---------------------------------------
local Game = {}
Game.__index = Game

Game.SERVER_PORT = 9999
Game.CLIENT_PORT = 9998

Game.MSG_EXEC_CMD 	= hash( "execCmd" )



-- Match --------------------------------------
local Match = {}
Match.__index = Match

function Match.new( ... )
	local this = {}
	setmetatable( this, Match )

	-- list of callsigns containing my desired game peers
	this.proposal = {...} 

	-- confirmations received from hosts
	this.confirms = {}
	
	return this
end


function Match:propose( agreedHandler )
	self.game.negotiator = udp.create( function( data, ip, port )
		if data == nil then return end

		local callsigns = data:split( "," )
		if lua.haveSameItems( self.proposal, callsigns ) then

			-- remember that this ip has sent an answer
			self.confirms[ ip ] = true

			-- check how many have agreed
			local cntConfirms = lua.length( self.confirms ) 
			if cntConfirms == #self.proposal then 
				-- stop sending out this proposal to all hosts
				timer.cancel( self.proposeTimer )
				self.game.negotiator:destroy()
				self.game.negotiator = nil
				
				-- callback application handler when all agreed
				if agreedHandler then agreedHandler() end
			end
		end
	end, self.game.CLIENT_PORT )

	-- always include player himself
	if not lua:contains( self.proposal, self.callsign ) then
		table.insert( self.proposal, self.callsign )
	end

	-- keep sending player's proposal until others agree
	self.proposeTimer = timer.delay( .5, true, function()
		-- send proposal to all hosts
		for i, callsign in ipairs( self.proposal ) do
			local host = self.game:getHost( callsign )
			self.game.negotiator.send( self:toString(), host.ip, self.game.CLIENT_PORT )
		end
	end )
end



function Match:toString()
	return table.concat( { unpack( self.proposal ) }, "," )
end



-- Game --------------------------------------
function Game.new( name )
	local this = {}
	setmetatable( this, Game )

	this.name = name
	this.hosts = Map.new()
	this.callbacks = {}
	
	return this
end


-- returns ip address of the localhost
function Game.getLocalhostIP()
	local ip = nil
	local ifaddrs = sys.get_ifaddrs()
	for _,interface in ipairs(ifaddrs) do
		if interface.name == "en0" then
			local adr = interface.address
			if adr ~= nil then
				local cntDots = adr:cntSubstr( "%." )
				if cntDots == 3 then 
					ip = adr
				end
			end
		end
	end
	-- there may be no network interface available!
	if ip == nil then ip = "127.0.0.1" end

	return ip
end


function Game:broadcast( callsign, callbackOnFound )
	self.callsign = callsign
	
	-- create a beacon to send and receive peer hosts info
	self.beacon = Beacon.new( self, callsign, callbackOnFound )
end


function Game:addHost( host )
	if host == nil then return end
	self.hosts:put( host.callsign, host )
end


function Game:getHost( callsign )
	return self.hosts:get( callsign )
end


function Game:getHostByIp( ip )
	local host
	for i, callsign in ipairs( self.hosts:keys() ) do
		host = self.hosts:get( callsign )
		if host and host.ip == ip then 
			break 
		else 
			host = nil
		end
	end
	return host
end


function Game:newMatch( ... )
	-- stop previous match negotiation
	if self.match then	
		timer.cancel( self.match.proposeTimer )
		self.negotiator:destroy()
		self.negotiator = nil
	end
	
	-- a list of desired players including the player himself
	self.match = Match.new( ... )
	self.match.game = self
	
	return self.match
end



function Game:update()
	if self.beacon then 
		self.beacon:update( self ) 
	end
	if self.negotiator then 
		self.negotiator.update() 
	end
end


function Game:isServer()
	if self.meHost == nil or self.srvHost == nil then return false end
	return self.meHost.ip == self.srvHost.ip
end


function Game:getServerHost()
	return self.srvHost
end


function Game:start()
	-- stop and destroy beacon
	if self.beacon then 
		self.beacon:destroy() 
		self.beacon = nil
	end

	-- declare one host to be the game server, no matter which.
	-- But the decision must be unanimous among all hosts!
	-- Implementation: either a fixed ip to be provided at will
	-- or the one with the highest last octet number gets selected
	self.srvHost = selectServerHost( "192.168.178.24" )	

	-- which host am I?
	self.meHost = self:getHostByIp( Game.getLocalhostIP() )

	-- check if this host is the (only) game server?
	if self:isServer() then
		if self.server then self.server:destroy() end
		self.server = Server.new()
	end

	-- every host is a game client
	if self.client then self.client:destroy() end
	self.client = Client.new()	
end



return Game

