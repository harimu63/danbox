module("luci.controller.danbox", package.seeall)

local fs   = require "nixio.fs"
local sys  = require "luci.sys"
local util = require "luci.util"
local http = require "luci.http"
local uci  = require "luci.model.uci".cursor()

local APP_LOG  = "/var/log/danbox-app.log"
local CORE_LOG = "/var/log/danbox-core.log"

function index()
	if not fs.access("/etc/config/danbox") then
		return
	end

	entry({"admin", "services", "danbox"}, firstchild(), _("DanBox"), 60).dependent = false

	entry({"admin", "services", "danbox", "status"}, template("danbox/status"), _("App Config"), 1)
	entry({"admin", "services", "danbox", "editor"}, template("danbox/editor"), _("Editor"), 2)
	entry({"admin", "services", "danbox", "log"},    template("danbox/log"),    _("Log"),    3)

	entry({"admin", "services", "danbox", "ctl"},          call("action_ctl")).leaf = true
	entry({"admin", "services", "danbox", "status_json"},  call("action_status_json")).leaf = true
	entry({"admin", "services", "danbox", "config_get"},   call("action_config_get")).leaf = true
	entry({"admin", "services", "danbox", "config_save"},  call("action_config_save")).leaf = true
	entry({"admin", "services", "danbox", "file_list"},    call("action_file_list")).leaf = true
	entry({"admin", "services", "danbox", "file_get"},     call("action_file_get")).leaf = true
	entry({"admin", "services", "danbox", "file_save"},    call("action_file_save")).leaf = true
	entry({"admin", "services", "danbox", "file_delete"},  call("action_file_delete")).leaf = true
	entry({"admin", "services", "danbox", "file_download"},call("action_file_download")).leaf = true
	entry({"admin", "services", "danbox", "log_data"},     call("action_log_data")).leaf = true
end

-- ---------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------

local function get_cfg()
	return {
		enabled        = uci:get("danbox", "config", "enabled") or "0",
		bin_path       = uci:get("danbox", "config", "bin_path") or "/usr/bin/sing-box",
		config_dir     = uci:get("danbox", "config", "config_dir") or "/etc/sing-box",
		config_file    = uci:get("danbox", "config", "config_file") or "config.json",
		start_delay    = uci:get("danbox", "config", "start_delay") or "0",
		test_config    = uci:get("danbox", "config", "test_config") or "1",
		tproxy_port    = uci:get("danbox", "config", "tproxy_port") or "9898",
		fwmark         = uci:get("danbox", "config", "fwmark") or "0x1",
		self_mark      = uci:get("danbox", "config", "self_mark") or "0xff",
		rtable         = uci:get("danbox", "config", "rtable") or "100",
		dashboard_port = uci:get("danbox", "config", "dashboard_port") or "9090",
	}
end

-- restrict all editor/file-manager access to inside config_dir, no traversal
local function safe_path(rel)
	local cfg = get_cfg()
	local base = fs.realpath(cfg.config_dir) or cfg.config_dir
	rel = (rel or ""):gsub("%.%.", ""):gsub("^/+", "")
	local full = base .. "/" .. rel
	local real = fs.realpath(full) or full
	if real:sub(1, #base) ~= base then
		return nil
	end
	return real
end

local function stat_entry(path)
	local out = sys.exec("stat -c '%s|%Y|%A' " .. util.shellquote(path) .. " 2>/dev/null") or ""
	local size, mtime, perm = out:match("^(%d+)|(%d+)|(%S+)")
	return tonumber(size) or 0, tonumber(mtime) or 0, perm or "?"
end

-- ---------------------------------------------------------------------
-- status + service control
-- ---------------------------------------------------------------------

function action_status_json()
	local cfg = get_cfg()
	local running = (sys.call("pgrep -f '" .. cfg.bin_path .. " run' >/dev/null 2>&1") == 0)
	local ver = sys.exec("'" .. cfg.bin_path .. "' version 2>/dev/null | head -n1") or ""

	http.prepare_content("application/json")
	http.write_json({
		running     = running,
		version     = ver:gsub("%s+$", ""),
		enabled     = cfg.enabled == "1",
		config_path = cfg.config_dir .. "/" .. cfg.config_file,
	})
end

function action_ctl()
	local action = http.formvalue("action")
	local allowed = { start = true, stop = true, restart = true, reload = true }

	http.prepare_content("application/json")
	if not allowed[action] then
		http.write_json({ ok = false, msg = "invalid action" })
		return
	end

	local ok = sys.call("/etc/init.d/danbox " .. action .. " >/dev/null 2>&1") == 0
	http.write_json({ ok = ok })
end

-- ---------------------------------------------------------------------
-- app config
-- ---------------------------------------------------------------------

function action_config_get()
	http.prepare_content("application/json")
	http.write_json(get_cfg())
end

function action_config_save()
	local enabled        = http.formvalue("enabled") == "1" and "1" or "0"
	local bin_path       = http.formvalue("bin_path") or "/usr/bin/sing-box"
	local config_dir     = http.formvalue("config_dir") or "/etc/sing-box"
	local config_file    = http.formvalue("config_file") or "config.json"
	local start_delay    = tostring(tonumber(http.formvalue("start_delay")) or 0)
	local test_config    = http.formvalue("test_config") == "1" and "1" or "0"
	local tproxy_port    = http.formvalue("tproxy_port") or "9898"
	local fwmark         = http.formvalue("fwmark") or "0x1"
	local self_mark      = http.formvalue("self_mark") or "0xff"
	local rtable         = http.formvalue("rtable") or "100"
	local dashboard_port = http.formvalue("dashboard_port") or "9090"

	uci:set("danbox", "config", "danbox")
	uci:set("danbox", "config", "enabled", enabled)
	uci:set("danbox", "config", "bin_path", bin_path)
	uci:set("danbox", "config", "config_dir", config_dir)
	uci:set("danbox", "config", "config_file", config_file)
	uci:set("danbox", "config", "start_delay", start_delay)
	uci:set("danbox", "config", "test_config", test_config)
	uci:set("danbox", "config", "tproxy_port", tproxy_port)
	uci:set("danbox", "config", "fwmark", fwmark)
	uci:set("danbox", "config", "self_mark", self_mark)
	uci:set("danbox", "config", "rtable", rtable)
	uci:set("danbox", "config", "dashboard_port", dashboard_port)
	uci:commit("danbox")

	http.prepare_content("application/json")
	http.write_json({ ok = true })
end

-- ---------------------------------------------------------------------
-- editor / file manager (sandboxed to config_dir, supports subfolders)
-- ---------------------------------------------------------------------

function action_file_list()
	local cfg = get_cfg()
	local rel = http.formvalue("path") or ""
	local full = safe_path(rel)

	http.prepare_content("application/json")
	if not full or not fs.access(full) then
		http.write_json({ ok = false, msg = "path not found" })
		return
	end

	local list = {}
	local dir = fs.dir(full)
	if dir then
		for f in dir do
			if f ~= "." and f ~= ".." then
				local entry_path = full .. "/" .. f
				local st = fs.stat(entry_path)
				local size, mtime, perm = stat_entry(entry_path)
				table.insert(list, {
					name   = f,
					is_dir = st and st.type == "dir" or false,
					size   = size,
					mtime  = mtime,
					perm   = perm,
				})
			end
		end
	end
	table.sort(list, function(a, b)
		if a.is_dir ~= b.is_dir then return a.is_dir end
		return a.name < b.name
	end)

	http.write_json({ ok = true, base = cfg.config_dir, path = rel, files = list })
end

function action_file_get()
	local path = safe_path(http.formvalue("name"))
	http.prepare_content("application/json")
	if not path or not fs.access(path) then
		http.write_json({ ok = false, msg = "not found" })
		return
	end
	http.write_json({ ok = true, content = fs.readfile(path) or "" })
end

function action_file_save()
	local path = safe_path(http.formvalue("name"))
	local content = http.formvalue("content") or ""

	http.prepare_content("application/json")
	if not path then
		http.write_json({ ok = false, msg = "invalid path" })
		return
	end
	local ok = fs.writefile(path, content)
	http.write_json({ ok = ok and true or false })
end

function action_file_delete()
	local path = safe_path(http.formvalue("name"))
	http.prepare_content("application/json")
	if not path or not fs.access(path) then
		http.write_json({ ok = false, msg = "not found" })
		return
	end
	local st = fs.stat(path)
	local ok
	if st and st.type == "dir" then
		ok = sys.call("rm -rf " .. util.shellquote(path)) == 0
	else
		ok = fs.remove(path)
	end
	http.write_json({ ok = ok and true or false })
end

function action_file_download()
	local path = safe_path(http.formvalue("name"))
	if not path or not fs.access(path) then
		http.status(404, "Not Found")
		return
	end
	local filename = path:match("([^/]+)$") or "file"
	http.header("Content-Disposition", 'attachment; filename="' .. filename .. '"')
	http.prepare_content("application/octet-stream")
	http.write(fs.readfile(path) or "")
end

-- ---------------------------------------------------------------------
-- log (dedicated file, reset every time danbox is Started)
-- ---------------------------------------------------------------------

function action_log_data()
	local t = http.formvalue("type") or "app"
	local path = (t == "core") and CORE_LOG or APP_LOG
	local out = sys.exec("tail -n 400 " .. util.shellquote(path) .. " 2>/dev/null") or ""
	http.prepare_content("application/json")
	http.write_json({ log = out, type = t })
end
