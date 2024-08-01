local Localhost = require( "nexus.localhost" )
local Commands = require( "nexus.commands" )
-- local b64 = require( "nexus.b64" )


local function determineGamemaster( contacts, fixedIp )
	local mastercontact 
	local maxOct = 0
	for i, contact in pairs( contacts ) do
		if contact.ip == fixedIp then 
			-- select the host with a given ip
			return host 
		else
			-- no fixed ip is provided, use arbitrary algorithm:
			-- the contact with highest last octet of ip becomes server
			local oct = tonumber( Localhost.getOctets( contact.ip )[ 4 ] )
			if oct > maxOct then 
				mastercontact = contact
				maxOct = oct
			end
			-- if equal ips, highest port number wins
			if oct == maxOct then 
				if contact.port > mastercontact.port then 
					mastercontact = contact
					maxOct = oct
				end
			end
		end
	end
	return mastercontact
end


-- Matcher ----------------------------------------------
local Matcher = {}
Matcher.__index = Matcher

function Matcher.create( nexus )
	local this = {}
	setmetatable( this, Matcher )

	this.nexus 			= nexus
	this.isProposing	= false
	this.callbacks 		= {}

	return this
end


function Matcher:start( profiles, callback )
	local me = self.nexus:me()
	if me == nil then return end
	
	me.proposal = profiles
	table.insert( self.callbacks, callback )
	self.nextProposeTime = socket.gettime()
	self.isProposing = true
end	

function Matcher:update( dt )
	if self.isProposing then 
		-- send out my proposal to all potential players once per sec
		if socket.gettime() >= self.nextProposeTime then 
			self.nextProposeTime = socket.gettime() + 1

			local cmd = Commands.newProposal( 
				self.nexus:me().proposal, 
				self.nexus.cmdsrv.ip, 
				self.nexus.cmdsrv.port 
			)
			self.nexus:broadcast( cmd, self.nexus.contacts )
		end

		-- always check if agreement to my proposal has already been achieved:
		-- all others must agree to the same config, my agreement is a given.
		local myContact = self.nexus:me()
		local myProposal = myContact.proposal
		local cntRequiredAgreements = table.length( myProposal )
		local cntAgreementsAchieved = 1

		local others = self.nexus:others()
		for ipPort, contact in pairs( others ) do 
			if table.containSameItems( contact.proposal, myProposal ) then 
				cntAgreementsAchieved = cntAgreementsAchieved + 1
			end
		end

		if cntAgreementsAchieved == cntRequiredAgreements then 
			pprint( "We have agreed to a common proposal!" )

			myContact.game = {}
			myContact.game.profiles = table.deepcopy( myProposal )

			-- all participants determine the gamemaster for this proposal
			-- independent of communication: highest ip/port is gamemaster.
			-- Set a flag in my proposal to know whether I am the gamemaster
			local gmc = determineGamemaster( self.nexus.contacts )
			myContact.game.gmcId = gmc:id()
			myContact.game.isGamemaster = ( myContact.game.gmcId == self.nexus:me():id() )

			pprint( "Starting a new game now!" )	
			if myContact.game.isGamemaster then 
				pprint( "I am the gamemaster: now waiting for clients to report readiness!" )
				-- special case: is gamemaster the only player? Do not wait eternally!
				if table.length( myContact.game.profiles ) == 1 then 
					pprint( "I am the only player - no need to wait. Executing callback..." )
					if #self.callbacks > 0 then 
						for i, callback in ipairs( self.callbacks ) do callback( myContact.game ) end
						self.callbacks = {}
					end
				else
					-- wait for cmds to come in from 
					-- other clients reporting readiness
				end
			else
				pprint( "I am not the gamemaster, execute callback now..." )
				if #self.callbacks > 0 then 
					for i, callback in ipairs( self.callbacks ) do callback( myContact.game ) end
					self.callbacks = {}
				end
			end
		end
	end
end


function Matcher:stop()
	self.isProposing = false

	-- cleanup
	if self.nexus:me().game then 
		for ipPort, contact in pairs( self.nexus.contacts ) do
			contact.proposal = nil
		end
	end		
end



function Matcher:readytoplay( callback )
	local game = self.nexus:me().game
	if game == nil then return false end 
	
	-- give some extra time before executing:
	-- race conditions between gamemaster / clients
	-- are possible otherwise.
	local fnCallback = function()
		timer.delay( .5, false, callback )
	end
	
	-- gamemaster waits for all clients to confirm
	-- their readiness. But after that, the gamemaster
	-- does not need to wait for its own "startToPlay" 
	-- event: it can excute the callback immediately 
	-- and never enter the "ReadyToPlay" state.
	if self.nexus:me().game.isGamemaster then 
		if callback then fnCallback() end 
	else 
		-- Only clients should wait for the gamemaster: 
		-- This callback is executed when "startToPlay"
		-- is sent by the gamemaster
		if callback then table.insert( self.callbacks, fnCallback ) end

		local cmd = Commands.newReadyToPlay( self.nexus.cmdsrv.ip, self.nexus.cmdsrv.port )
		local gmcId = self.nexus:me().game.gmcId
		local gmc = self.nexus.contacts[ gmcId ]
		self.nexus:send( cmd, gmc )
		pprint( ( "Sending 'readyToPlay' from %s to %s" ):format( cmd:get( "id" ), gmcId ) )
	end

	return true
end	


return Matcher

