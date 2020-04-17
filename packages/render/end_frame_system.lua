local ecs = ...
local world = ecs.world

local math3d 	= require "math3d"

local stat = {
	frame_num 	= 0,
	bgfx_frames = -1,
}

local end_frame_sys = ecs.system "end_frame_system"

function end_frame_sys:end_frame()
	stat.frame_num = stat.frame_num + 1
	math3d.reset()
end
