-- check for equality
local function contains( tab, cb )
	for key, item in pairs( tab ) do
		if item:equals( cb ) then
			return true
		end
	end 
	return false
end

local function remove( tab, cb )
	local remain = {}
	for key, item in pairs( tab ) do
		if not item:equals( cb ) then
			table.insert( remain, item )
		end
	end 
	return remain
end


-- EventCallback -------------------
local EventCallback = {}
EventCallback.__index = EventCallback

function EventCallback.create( fn )
	local this = {}
	setmetatable( this, EventCallback )

	this.fn = fn

	return this
end

function EventCallback:exec( ... )
	local ok, error = pcall( self.fn, ... )
	if not ok then pprint( "Error: " .. error ) end
end

function EventCallback:equals( cb )
	if cb == nil then return false end
	if( self.fn == cb.fn ) then return true end
	return false
end


-- Event -----------------------
local Event = {}
Event.__index = Event

function Event.create( key )
	local this = {}
	setmetatable( this, Event )

	this.key = key
	this.callbacks = {}
	this.paused = {}

	return this
end


function Event:subscribe( fn )
	local cb = EventCallback.create( fn )
	if contains( self.callbacks, cb ) then return end
	
	table.insert( self.callbacks, cb )
	return cb
end


function Event:unsubscribe( cb )
	self.callbacks = remove( self.callbacks, cb )
end


function Event:trigger( ... )
	for i, cb in ipairs( self.callbacks ) do 
		cb:exec( ... )
	end
end


function Event:pause( cb )
	self.callbacks = remove( self.callbacks, cb )
	if not contains( self.paused, cb ) then 
		table.insert( self.paused, cb ) 
	end
end


function Event:unpause( cb )
	self.paused = remove( self.paused, cb )
	if not contains( self.callbacks, cb ) then 
		table.insert( self.callbacks, cb ) 
	end
end


return Event

