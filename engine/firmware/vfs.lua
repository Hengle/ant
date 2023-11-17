local fastio = require "fastio"

local function sha1(str)
	return fastio.str2sha1(str)
end

local vfs = {} ; vfs.__index = vfs

local uncomplete = {}

local function readroot(self)
	do
		local f <close> = io.open(self.sandbox_path .. "root_" .. self.slot, "rb")
		if f then
			return f:read "a"
		end
	end
	do
		local f <close> = io.open(self.bundle_path .. "root", "rb")
		if f then
			return f:read "a"
		end
	end
end

local function updateroot(self, hash)
	local f <close> = assert(io.open(self.sandbox_path .. "root_" .. self.slot, "wb"))
	f:write(hash)
end

function vfs:init(hash)
	if hash then
		updateroot(self, hash)
		local res = self.resource
		self:changeroot(hash)
		return res
	end
	if self.root ~= nil then
		return
	end
	hash = readroot(self)
	if hash then
		self:changeroot(hash)
	else
		error("No history root")
	end
end

function vfs.new(config)
	local repo = {
		slot = config.slot,
		bundle_path = config.bundle_path,
		sandbox_path = config.sandbox_path,
		resource = {},
		cache_hash = {},
		cache_dir = {},
		cache_file = {},
		root = nil,
	}
	setmetatable(repo, vfs)
	return repo
end

local function dir_object(self, hash)
	local dir = self.cache_hash[hash]
	if dir then
		return dir
	end
	local f = self:readfile(hash)
	if f then
		dir = {}
		for line in f:lines() do
			local type, name, hash = line:match "^([dfr]) (%S*) (%S*)$"
			if type then
				dir[name] = {
					type = type,
					hash = hash,
				}
			end
		end
		f:close()
		self.cache_hash[hash] = dir
		return dir
	end
end

local function get_cachepath(setting, name)
	name = name:lower()
	local filename = name:match "[/]?([^/]*)$"
	local ext = filename:match "[^/]%.([%w*?_%-]*)$"
	local hash = sha1(name)
	return ("/res/%s/%s/%s_%s/"):format(setting, ext, filename, hash)
end

local ListSuccess <const> = 1
local ListFailed <const> = 2
local ListNeedGet <const> = 3
local ListNeedResource <const> = 4

local fetch_file

local function fetch_resource(self, fullpath)
	local h = self.resource[fullpath]
	if h then
		return ListSuccess, h
	end
	local cachepath = get_cachepath(self.setting, fullpath)
	if cachepath then
		local r, h = fetch_file(self, self.root, cachepath)
		if r ~= ListFailed then
			return r, h
		end
	end
	return ListNeedResource, fullpath
end

function fetch_file(self, hash, fullpath)
	local dir = dir_object(self, hash)
	if not dir then
		return ListNeedGet, hash
	end

	local path, name = fullpath:match "^/([^/]+)(/.*)$"
	local subpath = dir[path]
	if subpath then
		if name == "/" then
			if subpath.type == 'r' then
				return fetch_resource(self, subpath.hash)
			else
				return ListSuccess, subpath.hash
			end
		else
			if subpath.type == 'd' then
				return fetch_file(self, subpath.hash, name)
			elseif subpath.type == 'r' then
				local r, h = fetch_resource(self, subpath.hash)
				if r ~= ListSuccess then
					return r, h
				end
				return fetch_file(self, h, name)
			end
		end
	end
	-- invalid repo, root change
	return ListFailed
end

function vfs:list(path)
	local hash = self.cache_dir[path]
	if not hash then
		local r
		r, hash = fetch_file(self, self.root, path)
		if r ~= ListSuccess then
			return nil, r, hash
		end
		self.cache_dir[path] = hash
	end
	local dir = dir_object(self, hash)
	if not dir then
		return nil, ListNeedGet, hash
	end
	return dir
end

function vfs:changeroot(hash)
	self.root = hash
	self.resource = {}
	self.cache_dir = { ["/"] = hash }
	self.cache_file = {}
end

function vfs:resource_setting(setting)
	self.setting = setting
end

function vfs:add_resource(name, hash)
	self.resource[name] = hash
end

function vfs:readfile(name)
	do
		local realpath = self.cache_file[name]
		if realpath then
			local f = assert(io.open(realpath, "rb"))
			return f, realpath
		end
	end
	do
		local realpath = self.sandbox_path .. name
		local f = io.open(realpath, "rb")
		if f then
			self.cache_file[name] = realpath
			return f, realpath
		end
	end
	do
		local realpath = self.bundle_path .. name
		local f = io.open(realpath, "rb")
		if f then
			self.cache_file[name] = realpath
			return f, realpath
		end
	end
end

local function writefile(filename, data)
	local temp = filename .. ".download"
	local f = io.open(temp, "wb")
	if not f then
		print("Can't write to", temp)
		return
	end
	f:write(data)
	f:close()
	if not os.rename(temp, filename) then
		os.remove(filename)
		if not os.rename(temp, filename) then
			print("Can't rename", filename)
			return false
		end
	end
	return true
end

-- REMARK: Main thread may reading the file while writing, if file server update file.
-- It's rare because the file name is sha1 of file content. We don't need update the file.
-- Client may not request the file already exist.
function vfs:write_blob(hash, data)
	local hashpath = self.sandbox_path .. hash
	if writefile(hashpath, data) then
		return true
	end
end

function vfs:write_file(hash, size)
	uncomplete[hash] = { size = tonumber(size), offset = 0 }
end

function vfs:write_slice(hash, offset, data)
	offset = tonumber(offset)
	local hashpath = self.sandbox_path .. hash
	local tempname = hashpath .. ".download"
	local f = io.open(tempname, "ab")
	if not f then
		print("Can't write to", tempname)
		return
	end
	local pos = f:seek "end"
	if pos ~= offset then
		f:close()
		f = io.open(tempname, "r+b")
		if not f then
			print("Can't modify", tempname)
			return
		end
		f:seek("set", offset)
	end
	f:write(data)
	f:close()
	local filedesc = uncomplete[hash]
	if filedesc then
		local last_offset = filedesc.offset
		if offset ~= last_offset then
			print("Invalid offset", hash, offset, last_offset)
		end
		filedesc.offset = last_offset + #data
		if filedesc.offset == filedesc.size then
			-- complete
			uncomplete[hash] = nil
			if not os.rename(tempname, hashpath) then
				-- may exist
				os.remove(hashpath)
				if not os.rename(tempname, hashpath) then
					print("Can't rename", hashpath)
				end
			end
			return true
		end
	else
		print("Offset without header", hash, offset)
	end
end

return vfs
