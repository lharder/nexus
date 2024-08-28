-- check for equality
local function contains( tab, fn )
	for key, item in pairs( tab ) do
		if item == fn then
			return true
		end
	end 
	return false
end

local function remove( tab, fn )
	local remain = {}
	for key, item in pairs( tab ) do
		if not item == fn then
			table.insert( remain, item )
		end
	end 
	return remain
end


-- Event -----------------------
-- simplified version WITHOUT change of script
-- context: seems to cause race conditions
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
	if contains( self.callbacks, fn ) then return end
	table.insert( self.callbacks, fn )
	return fn
end


function Event:unsubscribe( fn )
	self.callbacks = remove( self.callbacks, fn )
end


function Event:trigger( ... )
	for i, fn in ipairs( self.callbacks ) do 
		fn( ... )
	end
end


function Event:pause( fn )
	self.callbacks = remove( self.callbacks, fn )
	if not contains( self.paused, fn ) then 
		table.insert( self.paused, fn ) 
	end
end


function Event:unpause( fn )
	self.paused = remove( self.paused, fn )
	if not contains( self.callbacks, fn ) then 
		table.insert( self.callbacks, fn ) 
	end
end


return Event.create( "factorycreated" )

