package.cpath = "bin/?.dll"

local iup = require "iuplua"
local bgfx = require "bgfx"
local util = require "util"
local math3d = require "math3d"

local ctx = {
	canvas = iup.canvas {},
}

local dlg = iup.dialog {
	ctx.canvas,
	title = "40-TestSVLX",
	size = "HALFxHALF",
}

local time = 0
local function mainloop()
	math3d.reset()
	bgfx.touch(0)
	time = time + 0.01
	bgfx.set_uniform(ctx.u_time, math3d.vector {time,0,0,0})
	local mtx = math3d.matrix { r = { 0, time, 0} }
	bgfx.set_transform(mtx)
	bgfx.set_state(ctx.state)
	util.meshSubmit(ctx.mesh, 0, ctx.prog)
	bgfx.frame()
end

function ctx.init()
	bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

	ctx.prog = util.programLoad("vs_mesh", "fs_mesh")
	ctx.mesh = util.meshLoad "meshes/3d_pmi/3d_pmi.mesh"
	ctx.u_time = bgfx.create_uniform("u_time", "v4")
	ctx.state = bgfx.make_state {
		WRITE_MASK = "RGBAZ",
		DEPTH_TEST = "LESS",
		CULL = "CCW",
		MSAA = true,
	}

	print("test")
end

function ctx.resize(w,h)
	ctx.width = w
	ctx.height = h
	bgfx.reset(w,h, "v")

	local viewmat = math3d.lookat( {0,1,-2.5}, {0,1,0} )
	local projmat = math3d.projmat { fov = 60, aspect = w/h , n = 0.1, f = 100 }

	bgfx.set_view_transform(0, viewmat, projmat)
	bgfx.set_view_rect(0, 0, 0, ctx.width, ctx.height)
end

util.init(ctx)
dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
util.run(mainloop)

--  bgfx.destroy(ctx.u_time)
--  bgfx.destroy(ctx.prog)
--  util.meshUnload(ctx.mesh)
