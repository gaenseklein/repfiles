local micro = import("micro")
-- example for an icons-plugin
-- ~~~~~~~~~~~~~~~~
-- internal storage
-- ~~~~~~~~~~~~~~~~

local icons = {
	default ="",
	dir =    "🗀 ",  --some alternative icons: 📁🖿 🗀 
	dir_open="🗁 ", --some alternative icons: 📂🗁 
	ok = 	 "✓ ",
	not_ok = "✗ ",
	bin =    "🎛 ",-- 🎛
	txt =    "🗎 ",	
	audio =  "♪ ", --🔉🔊🕪 🕩 ♪🎵🎶
	video =  "📽 ", --🎥📹🎦📽 🎬📺
	image =  "🖼 ", --🖼 🖻 📷📸🖽 🖾
	config = "🗎 ", --🎚⚙🔨⚒🎛 🔧
	json =   "{}",
}

local binary_extensions = {
	image = {"jpg","jpeg","png","gif","webp","tiff","tif","bmp"},
	video = {"avi","mpg","mp4","mkv","ogv", "webm","mjpg","mov","flv","wmv"},
	audio = {"ogg","mp3","wav","au","midi","flac","wma","acc","aac"}
}
local txt_extensions = {
	json = {"json", "log"},
	config = {"env", "config","cfg"}	
}
-- ~~~~~~~~~~~~~~~~
-- helper functions
-- ~~~~~~~~~~~~~~~~
local function get_extension(orig_path)
	local path = string.lower(orig_path)
	local pos = nil 
	local x = #path
	while x >= 1 and pos == nil do
		if string.sub(path,x,x)=="." then 
			pos = x			
		end
		x = x - 1
	end
	if pos == nil then return "" end
	
	-- local pos = string.find(path, '.', 1, {literal=true})
	-- if pos == nil then return "" end
	-- local new_pos = string.find(path, '.', pos+1, {literal=true})
	-- while new_pos ~= nil do 
	-- 	pos = new_pos
	-- 	new_pos = string.find(path, '.', pos+1,{literal=true})
	-- end
	local ext = string.sub(path, pos+1)
	-- consoleLog({ext=ext,path=path, pos=pos+1})
	return ext
end

local function search_array(table, value)
	for i=1,#table do 
		if table[i]==value then return value end
	end
	return nil
end
local function get_icon_from_extension(extension, binary)
	local icon = ""
	if #extension < 1 then return "" end
	if binary then 		
		for key, value in pairs(binary_extensions) do 
			-- consoleLog({key = key, value = value, extension = extension},"key-value",4)			
			if search_array(value, extension) ~= nil then 
				return icons[key]
			end
		end
	else
		for key, value in pairs(txt_extensions) do 
			if search_array(value, extension) ~= nil then 
				return icons[key]
			end
		end
	end
	return icon
end

-- ~~~~~~~~~~~~~~~~
-- API
-- ~~~~~~~~~~~~~~~~

-- returns a table with all icons
local function Icons()
	return icons
end

-- expects string path (filepath)
-- expects boolean is_text
-- returns string with icon
local function GetIcon(path, is_text)
	local icon = ""
	local ext = get_extension(path)
	if is_text then 
		icon = get_icon_from_extension(ext, false)
		if icon == "" then icon = icons.txt	end
	else 
		-- consoleLog({ext=ext,path=path})
		icon = get_icon_from_extension(ext, true)		
		if icon == "" then icon = icons.bin end
	end		
	return icon
end

return {Icons = Icons, GetIcon = GetIcon}

-- --debug function to transform table/object into a string
-- function dump(o, depth)
-- 	if o == nil then return "nil" end
--    if type(o) == 'table' then
--       local s = '{ '
--       for k,v in pairs(o) do
--          if type(k) ~= 'number' then k = '"'..k..'"' end
--          if depth > 0 then s = s .. '['..k..'] = ' .. dump(v, depth - 1) .. ',\n'
--          else s = s .. '['..k..'] = ' .. '[table]'  .. ',\n'end
--       end
--       return s .. '} \n'
--    elseif type(o) == "boolean" then
--    	  return boolstring(o)   
--    else
--       return tostring(o)
--    end
-- end
-- -- debug function to get a javascript-like console.log to inspect tables
-- -- expects: o: object like a table you want to debug
-- -- pre: text to put in front 
-- -- depth: depth to print the table/tree, defaults to 1
-- -- without depth  we are always in risk of a stack-overflow in circle-tables
-- function consoleLog(o, pre, depth)
-- 	local d = depth
-- 	if depth == nil then d = 1 end
-- 	local text = dump(o, d)
-- 	local begin = pre
-- 	if pre == nil then begin = "" end	
-- 	micro.TermError(begin, d, text)
-- end
-- 
-- return {Icons = Icons, GetIcon = GetIcon}