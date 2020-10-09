local util = {}

local iup = require "iuplua"
local bgfx = require "bgfx"
local math3d = require "math3d"
local adapter = require "mathadapter"


do
	local mesh_decode = {}
	local vb_header = "<" .. string.rep("f", 4+6+16)
--	local vb_data = { "!", "", nil, nil }
--	local ib_data = { "", nil, nil }

	local function read_mesh_header(group, data, offset)
		local tmp = { string.unpack(vb_header, data, offset) }
		group.sphere = { table.unpack(tmp,1,4) }
		group.aabb = { table.unpack(tmp,5,10) }
		group.obb = { table.unpack(tmp,11,26) }
		return tmp[27]
	end

	mesh_decode["VB \1"] = function(mesh, group, data, offset)
		offset = read_mesh_header(mesh, data, offset)
		local stride, numVertices
		mesh.vdecl, stride, offset = bgfx.vertex_layout(data, offset)
		numVertices, offset = string.unpack("<I2", data, offset)
		local size = stride * numVertices
		local vb_data = bgfx.memory_buffer(data, offset, size)
		group.vb = bgfx.create_vertex_buffer(vb_data, mesh.vdecl)
		return offset + size
	end

	mesh_decode["IB \0"] = function(mesh, group, data, offset)
		local numIndices
		numIndices, offset = string.unpack("<I4", data, offset)
		local size = numIndices * 2
		local ib_data = bgfx.memory_buffer(data, offset, size)
		group.ib = bgfx.create_index_buffer(ib_data)
		return offset + size
	end

	mesh_decode["IBC\0"] = function(mesh, group, data, offset)
		error "Unsupport Compressed IB"
	end

	mesh_decode["PRI\0"] = function(mesh, group, data, offset)
		local material, num
		material, num, offset = string.unpack("<s2I2", data, offset)	-- no used
		group.prim = {}
		for i=1,num do
			local p = {}
			p.name, p.startIndex, p.numIndices, p.startVertex, p.numVertices, offset = string.unpack("<s2I4I4I4I4", data, offset)
			offset = read_mesh_header(p, data, offset)
			table.insert(group.prim, p)
		end
		local tmp = {}
		for k,v in pairs(group) do
			group[k] = nil
			tmp[k] = v
		end
		table.insert(mesh.group, tmp)
		return offset
	end

	function util.meshLoad(filename)
		local f = assert(io.open(filename,"rb"))
		local data = f:read "a"
		f:close()
		local mesh = { group = {} }
		local offset = 1
		local group = {}
		while true do
			local tag = data:sub(offset, offset+3)
			if tag == "" then
				break
			end
			local decoder = mesh_decode[tag]
			if not decoder then
				error ("Invalid tag " .. tag)
			end
			offset = decoder(mesh, group, data, offset + 4)
		end

		return mesh
	end
end

function util.meshUnload(mesh)
	for _,group in ipairs(mesh.group) do
		bgfx.destroy(group.ib)
		bgfx.destroy(group.vb)
	end
end

function util.meshSubmit(mesh, id, prog)
	local g = mesh.group
	local n = #g
	for i=1,n do
		local group = g[i]
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)
		bgfx.submit(id, prog, 0, i ~= n and "" or "ivs")
	end
end

function util.meshSubmitState(mesh, state, mtx)
	bgfx.set_transform(mtx)
	bgfx.set_state(state.state)

	for _, texture in ipairs(state.textures) do
		bgfx.set_texture(texture.stage,texture.sampler,texture.texture,texture.flags)
	end

	local g = mesh.group
	local n = #g
	for i=1,n do
		local group = g[i]
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)
		bgfx.submit(state.viewId, state.program, 0, i ~= n and "" or "ivs")
	end
end


return util