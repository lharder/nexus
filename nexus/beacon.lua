local HttpClient = require( "nexus.httpclient" )
local TcpClient = require( "defnet.tcp_client" )
local Contact = require( "nexus.contact" )


local nop = function() 
end 

-- advance declaration, impl comes later....
local newReconnector

--------------------------------------
local function newTcpClient( self, ip, port )
	local ipPort = ( "%s:%s" ):format( ip, port )

	-- On disconnect of client (e.g. remote server is shutdown):
	-- My client(!) gets disconnected from the remote host. That
	-- is a sign that the remote server(!) is down. Use callback
	-- to inform that the remote player is no longer available.
	local onDisconnect = function()
		local contact = self.nexus.contacts[ ipPort ]
		pprint( "No longer available: " .. contact.profile.callsign .. " (" .. ipPort .. ")" )

		-- beacon is active: if peer disconnects, 
		-- delete it to allow for reconnect
		if self.isSearching then 
			-- inform interested scripts via callback
			self:onPlayerDisconnect( contact )

			-- cleanup, contact is no longer available.
			-- Thus get ready to connect again!
			contact.tcpclient.destroy()
			self.nexus.contacts[ ipPort ] = nil

		else
			-- Not searching and matching anymore, now we are playing!
			-- When disconnected, do not destroy client, but try to 
			-- reestablish the connection to proceed as soon as peer is 
			-- available again. Assume it is the same and has the same
			-- state, e.g. because it was interrupted by a tel call.
			-- When a coplayer is disconnected, all others should pause
			-- immediately to keep common state: up to the game via callback.
			contact.tcpclient = newReconnector( self, ip, port )

			-- inform via callback to allow e.g. for pausing the game
			self:onPlayerDisconnect( contact )
		end
	end

	return pcall( TcpClient.create, ip, port, nop, onDisconnect, self.options )
end


-- Reconnector --------------------------------------------
-- Temporary drop-in to replace a disconnected TcpClient:
-- tries to reconnect on update() until new connection 
-- can be established. Implements all methods of a regular
-- TcpClient and replaces itself automatically when successful.
newReconnector = function( beacon, ip, port )
	local rec 		= {}
	rec.beacon 		= beacon
	rec.ip 			= ip
	rec.port 		= port
	rec.ipPort 		= ( "%s:%s" ):format( ip, port )
	rec.nextconnect = socket.gettime()

	rec.send = function() 
		-- pprint( "No sending to disconnected " .. rec.ipPort )
	end

	rec.destroy = function()
		-- destroy myself
		rec.beacon.nexus.contacts[ rec.ipPort ].tcpclient = nil
	end

	rec.update = function()
		if socket.gettime() > rec.nextconnect then 
			rec.nextconnect = socket.gettime() + 1
			-- pprint( "Try to reconnect to " .. rec.ipPort .. "....." )

			_, rec.tcpclient = newTcpClient( rec.beacon, rec.ip, rec.port )
			local success = ( type( rec.tcpclient ) == "table" )
			if success then 
				-- replace myself with a "real" tcpclient again
				pprint( "Reconnect to " .. rec.ipPort .. " successful!" )
				rec.beacon.nexus.contacts[ rec.ipPort ].tcpclient = rec.tcpclient
				pprint( "Replaced myself with my new TcpClient! Reconnector out ;o)" )

				-- callback and inform about successfully reestablishing connection
				local contact = rec.beacon.nexus.contacts[ rec.ipPort ]
				rec.beacon:onPlayerConnect( contact )
			end
		end
	end

	return rec
end


-- Send my player data to a remote server and receive all my peers' data.
-- That way, a problematic p2p search in the local network is not needed.
-- params can contain optional custom name/value pairs with game data.
-- matchkey is an optional arbitrary name to be entered by all players
-- who want to play a match together. It overrides the default behavior: 
-- beacon server will return all players from the same (router) ip address.
-- In large networks, however, that may not work - then use a matchkey.
local function sendIntro( self, callback )
	local contact = self.nexus:me()
	
	if contact == nil then 
		-- create "me" contact
		local ip = self.nexus.cmdsrv.ip
		local port = self.nexus.cmdsrv.port
		local mocktcpclient = {}		
		contact = Contact.create( ip, port, mocktcpclient )

		-- add required param
		contact:put( "callsign", self.callsign )

		-- add optional custom parameters 
		if self.params then 
			for k, v in pairs( self.params ) do contact:put( k, v ) end
		end
	end
	
	local player = { 
		gamename 	= self.nexus.gamename,
		gameversion = self.nexus.gameversion,
		matchkey	= self.matchkey,
		callsign	= self.callsign,
		contact 	= contact
	}

	self.http:put( "beacon/player", player, callback ) 
end


-- Beacon ------------------
local Beacon = {}
Beacon.__index = Beacon


function Beacon.create( nexus, host, login, pwd )
	local this = {}
	setmetatable( this, Beacon )

	this.nexus 			= nexus
	this.isSearching 	= false
	this.http 			= HttpClient.create( host, login, pwd )
	
	this.options = { 
		binary = true,  
		connection_timeout = 1.0
	}

	return this
end


function Beacon:search( callsign, params, onClientConnect, onClientDisconnect, matchkey )
	self.callsign 			= callsign
	self.params 			= params
	self.onClientConnect	= onClientConnect
	self.onClientDisconnect	= onClientDisconnect
	self.matchkey 			= matchkey
	self.isSearching 		= true
	self.interval			= socket.gettime() + 2
	
	pprint( "I am " .. callsign )
	sendIntro( self, function( httpclient, id, resp )
		pprint( "Response status " .. resp.status .. ". " .. resp.response )
	end )
end


function Beacon:update( dt )
	if self.isSearching then 
		if socket.gettime() > self.interval then 
			self.interval = socket.gettime() + 3
			
			sendIntro( self, function( httpclient, id, resp )
				if resp.status > 299 then 
					pprint( "Response status " .. resp.status .. ". " .. resp.response )
	
				else
					local contacts = json.decode(  resp.response )
					pprint( ( "Received %d contacts in our network" ):format( #contacts ) )
					
					for i, con in ipairs( contacts ) do 
						-- profile comes back as string, must be deserialized extra
						con.profile = json.decode( con.profile )
						
						local ipPort = ( "%s:%s" ):format( con.ip, con.port )
						pprint( con.profile.callsign .. ": " .. ipPort )
						
						if self.nexus.contacts[ ipPort ] == nil then 
							local _, tcpclient = newTcpClient( self, con.ip, con.port )
							local success = ( type( tcpclient ) == "table" )
							if success then 
								pprint( ( "Game client '%s' discovered at %s:%s." ):format( 
									con.profile.callsign, 
									con.ip, 
									con.port ) 
								) 

								-- remember all technical communication information for this contact
								local contact = Contact.create( con.ip, con.port, tcpclient )
								contact.profile = con.profile
								self.nexus.contacts[ ipPort ] = contact 

								-- inform custom script
								self:onPlayerConnect( contact )			
							end
						end
					end
				end
			end )
		end
	end
end


-- Inform via callback that a player (i.e. tcp client with proper
-- announcement) has been found
function Beacon:onPlayerConnect( contact )
	if self.onClientConnect then self.onClientConnect( contact ) end
end

-- Inform via callback that a player (i.e. tcp client with proper
-- announcement) has been disconnected and is no longer available
function Beacon:onPlayerDisconnect( contact )
	if self.onClientDisconnect then self.onClientDisconnect( contact ) end
end


function Beacon:stop()
	self.isSearching = false
end



return Beacon

