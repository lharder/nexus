
Commands = {}
Commands.CREATE 	= 1
Commands.DELETE 	= 2
Commands.UPDATE	 	= 3
Commands.ANIMATE 	= 4
Commands.SOUND 		= 5
Commands.MESSAGE 	= 6

-- Create -----------------------------
local CmdCreate = {} 
CmdCreate.__index = CmdCreate

function Commands.newCreate( gid, factUrl, pos, rot, params, scale ) 
	local this = {}
	this = setmetatable( this, CmdCreate )
	
	this.type = Commands.CREATE
	this.attrs = {}

	this.attrs.gid = gid
	this.attrs.factUrl = factUrl
	this.attrs.pos = pos
	this.attrs.rot = rot
	this.attrs.scale = scale
	this.attrs.params = params

	return this
end


-- Delete -----------------------------
local CmdDelete = {}
CmdDelete.__index = CmdDelete

function Commands.newDelete( gid, recursive ) 
	local this = {}
	this = setmetatable( this, CmdDelete )
	
	this.type = Commands.DELETE
	this.attrs = {}
	
	this.attrs.gid = gid
	this.attrs.recursive = recursive

	return this
end


-- Update -----------------------------
local CmdUdate = {}
CmdUdate.__index = CmdUdate

function Commands.newUpdate( gid, pos, degrees, dir, speed ) 
	local this = {}
	this = setmetatable( this, CmdUdate )
	
	this.type = Commands.UPDATE
	this.attrs = {}

	this.attrs.gid = gid
	this.attrs.pos = pos
	this.attrs.degrees = degrees
	this.attrs.dir = dir
	this.attrs.speed = speed
	
	return this
end


-- Update -----------------------------
local CmdAnim = {} 
CmdAnim.__index = CmdAnim

function Commands.newAnimate( gid, sprite, anim ) 
	local this = {}
	this = setmetatable( this, CmdAnim )

	this.type = Commands.ANIMATE
	this.attrs = {}

	this.attrs.gid = gid
	this.attrs.sprite = sprite
	this.attrs.anim = anim

	return this
end


-- Update -----------------------------
local CmdSound = {} 
CmdSound.__index = CmdSound

function Commands.newSound( gid, soundcomp, doPlay, props ) 
	local this = {}
	this = setmetatable( this, CmdSound )

	this.type = Commands.SOUND
	this.attrs = {}

	this.attrs.gid = gid
	this.attrs.sound = soundcomp
	this.attrs.doplay = doplay
	this.attrs.props = props

	return this
end


-- Custom -----------------------------
local CmdMessage = {} 
CmdMessage.__index = CmdMessage

function Commands.newMessage( gid, message_id, message ) 
	local this = {}
	this = setmetatable( this, CmdMessage )

	this.type = Commands.MESSAGE
	this.attrs = {}
	
	this.attrs.gid = gid
	this.attrs.message_id = message_id
	this.attrs.message = message

	return this
end



return Commands

