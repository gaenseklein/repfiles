VERSION = "1.0.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local buffer = import("micro/buffer")

-- internal vars we need
local inside_git = false
-- local gitignore = "" -- we dont need it, we use git status --porcelain instead
local show_ignored = true
local show_hidden = true
local show_binarys = true
local allfiles = {}
-- prefix symbols: 
-- status like symbols - if you change them you have to alter syntax.yaml too
local pre_changed = "★" --"🕫"
local pre_dir = "🗀"
local pre_new = "☆"
local pre_ignored = "⌂"
-- just for the beauty of it
local pre_file = " "
local pre_link = "⤷" -- link from "parent folder" to visualise relationship
--local pre_text = "🗏" -- future: to distinguish between binary and text files
--local pre_bin = "" -- 

-- the filetree
local filetree = {
	name = 'root',
	dirs = {},
	files = {},
	entry_on_line = {},
	fullpath = ''
}
-- the panes - fileview is where we show the tree, target_pane is where we open files to
local fileview = nil
local target_pane = nil

-- parse_path: gets a path and puts it into the tree, building up missing directorys on the way
-- expects string path to insert and boolean isfile to mark if we put in a dir or a file
-- as we dont have a way to distinguish it from here on
function parse_path(path, isfile)    
    local startpos = 1
    local endpos = string.find(path, "/", startpos)
    local actfolder = filetree
    local add_count = 0
    -- build up missing directorys
    while endpos ~= nil do
        local folder = string.sub(path, startpos, endpos-1)
        if actfolder.dirs[folder] ~= nil then 
            actfolder = actfolder.dirs[folder]
        else 
        	--local fp = actfolder.fullpath .. "/" .. folder
        	--if actfolder.name == "root" then fp = folder end
        	-- best way seems to be to put a / at end of dirs fullpath
        	local hide = (string.sub(folder,1,1)=='.') -- is it hidden? on unix hidden starts with a .
            actfolder.dirs[folder] = {
                fullpath = actfolder.fullpath  .. folder .. "/",
                parent = actfolder,
                expanded = false,
                changed = false,
                hidden = hide,
                isnew = false,
                ignored = false,                
                dirs = {},
                files = {}
            }
            actfolder = actfolder.dirs[folder]
            add_count = add_count + 1 -- just for debugging
        end
        startpos = endpos + 1
        endpos = string.find(path, "/", startpos)
    end        
    local filename = string.sub(path, startpos) -- filename is now the last part after last /
    local hide = (string.sub(filename,1,1)=='.') -- again check for hidden
  	--local fp =  actfolder.fullpath .. '/' .. filename
  	--if actfolder.name == "root" then fp = filename end
  	-- same as above: dirs have a / at the end
    if isfile and #filename > 0 and actfolder.files[filename] == nil then    
    	--micro.TermError('added file',0, 'fname: '..filename .. ' length '..#filename .. ' path ' .. actfolder.fullpath .. filename)
    	-- adding a file to the tree    	
	    actfolder.files[filename] = {
	        fullpath = actfolder.fullpath .. filename,
	        file = true,
	        parent = actfolder,
	        name = filename,
	        changed = false,
	        isnew = false,	        
	        ignored = false,
	        hidden = hide
	    }
	    -- save to allfiles to get access to all files by path directly
	    -- storing some information inside to not double check later on	    
	    local fp = actfolder.files[filename].fullpath
	    allfiles[fp] = {binary=false, text=false}
		-- return the file
		return actfolder.files[filename]
	end
	if not isfile and  #filename > 0 and actfolder.dirs[filename] == nil then 
  		--micro.TermError('added directorys', add_count, 'dname: '..filename .. ' length '..#filename)
		-- adding a dir to the tree
			actfolder.dirs[filename] = {
				   fullpath = actfolder.fullpath .. filename .. '/',
	                parent = actfolder,
	                expanded = false,
	                changed = false,
	                isnew = false,
	                ignored = false,
	                hidden = hide,
	                dirs = {},
	                files = {}
			}
			-- return the directory
			return actfolder.dirs[filename]
	end
end

-- walk_to_file expects a path and returns entry in filetree or nil
function walk_to_file(filepath)
	local startpos = 1
	local endpos = string.find(filepath, "/", startpos)
	local actfolder = filetree
	while endpos ~= nil do
		local folder = string.sub(filepath, startpos, endpos-1)
		actfolder = actfolder.dirs[folder]
		if actfolder == nil then return nil end
		startpos = endpos + 1
		endpos = string.find(filepath, "/", startpos)
	end
	local filename = string.sub(filepath, startpos)
	-- as names and dirs cannot share filename its either a dir or a file:
	if actfolder.dirs[filename] ~= nil then return actfolder.dirs[filename] end
	return actfolder.files[filename] -- returns nil if no file exists
end

-- if we found a changed file or directory we have to mark upwards till root as changed
local function mark_dirs_as_changed(file, isnew)
	local actdir = file.parent
	while actdir.parent ~= nil do
		if isnew then 
			actdir.isnew = true
		else
			actdir.changed = true
		end
		actdir = actdir.parent
	end
end

-- mark a path as changed
local function mark_as_changed(filepath, isnew)	
	local file = walk_to_file(filepath)	
	if file == nil then 
		--micro.TermError('file not found',0,'>>'..filepath..'<<')
		return nil 
	end
	if isnew then 
		file.isnew = true
		--micro.TermError('new file',127,file.fullpath)
	else 
		file.changed = true
		--micro.TermError('changed file',127,file.fullpath)
	end
	if file.parent.name ~= "root" then 
		mark_dirs_as_changed(file, isnew)
	end
end


-- use git diff to change colors and stuff
function respect_git_diff()
	if not inside_git then 
	--	micro.TermError("not inside git",172,'...')
		return nil 
	end
	local gitdiff = shell.RunCommand('git status --porcelain')
	local startpos = 1
	local endpos = string.find(gitdiff, '\n',startpos)
	local count = 0
	while endpos ~= nil and count < 100 do
		local line = string.sub(gitdiff, startpos, endpos-1)
		local ending= string.sub(line,-1)
		local isfile = true
		if ending == "/" then 
			isfile = false
			line = string.sub(gitdiff, startpos, endpos-2) 		
		end
		
		local fname = string.sub(line, 4)
		local begin = string.sub(line,1,3)
		local isnew = (begin=="?? ")
		--micro.TermError('>'..begin..'<', count, '>>'..fname..'<<')
		parse_path(fname, isfile)
		mark_as_changed(fname, isnew)
		--if not isfile then mark_as_changed_downwards(fname, isnew) end
		startpos = endpos + 1
		endpos = string.find(gitdiff, '\n', startpos)
		count = count + 1
	end
	--load gitignore - we dont need it manualy, git status --porcelain does the job
	--gitignore = shell.RunCommand('cat .gitignore') -- dont needed anymore
	--we should always mark .git as ignored
	if filetree.dirs['.git'] ~= nil then 
		filetree.dirs['.git'].ignored = true
	end
	mark_ignored(filetree)
	
end

-- if we open a file inside the tree we would have to expand upwards
-- only possible if done programmaticaly, not by userinteraction
-- so not used till now
function expand_upwards(dir)
	local actdir = dir
	while actdir.parent ~= nil do
		actdir.expanded = true
		actdir = actdir.parent
	end
end

-- if a dir is ignored all its children are ignored as well
-- ignore_downwards does that
local function ignore_downwards(dir)
	local actdir = dir
	if actdir == nil then return nil end
	actdir.ignored = true
	for k, v in pairs(actdir.dirs) do 
		ignore_downwards(v)
	end
	for k, v in pairs(actdir.files) do
		v.ignored = true
	end
end

-- check if path is ignored by git
local function check_ignore(path)
	local res = shell.RunCommand('git check-ignore '.. path)
	if res == nil or #res == 0 then
		return false
	else
		return true
	end
end

-- walk through the filetree downwards starting by "folder" 
-- checking if dir or file is ignored
function mark_ignored(folder)
	if folder == nil then return nil end
	for k,v in pairs(folder.dirs) do 
		if check_ignore(v.fullpath) then 
			v.ignored = true
			ignore_downwards(v)
		else
			mark_ignored(v)
		end
	end
	for k,v in pairs(folder.files) do
		v.ignored = check_ignore(v.fullpath)
	end
end

-- checks for files in a path (has to be a dir)
-- inserting them into filetree
function add_files_to_tree(path)
	local cmd = 'find ./' .. path .. ' -maxdepth 1 -type f'
	local all_files = shell.RunCommand(cmd)
	if all_files == nil or #all_files < 3 then return nil end
	--micro.TermError(cmd,#all_files,all_files)
	local startpos = 1
	local endpos = string.find(all_files,'\n',startpos)
	local counter = 0
	while endpos ~= nil and counter < 20 do 
		local fpath = string.sub(all_files, startpos+2, endpos-1)
		--micro.TermError(fpath, counter, 'what is going on?' .. startpos ..':'..endpos)
		parse_path(fpath, true)
		startpos = endpos + 1
		endpos = string.find(all_files,'\n', startpos)
		counter = counter + 1
	end
end

-- checks for subdirs in a path (has to be a dir)
-- inserting them into filetree
function add_directorys_to_tree(path)
	local all_dirs = shell.RunCommand('find ./'.. path ..' -maxdepth 1 -type d')	
	if all_dirs == nil or #all_dirs < 5 then return nil end
	local startpos = 1 --string.find(all_dirs, '\n./')
	local endpos = string.find(all_dirs, '\n', startpos)
	local counter = 0
	while endpos ~= nil and counter < 10 do
		local dpath = string.sub(all_dirs, startpos+2, endpos-1)
		--micro.TermError(dpath, counter, 'what is going on?' .. startpos ..':'..endpos .. ' length '.. #dpath)
		if dpath ~= nil and #dpath > 0 then 
			--micro.TermError(dpath, counter, 'parsing path')
			parse_path(dpath, false)
		end
		startpos = endpos + 1
		endpos = string.find(all_dirs,'\n',startpos)
		counter = counter + 1
	end
end

-- build tree builds a part of the tree
-- as we dont want to build the whole tree at once for performance reason
-- we only check a path (has to be dir) for its files and subdirectorys, 
-- adding them to the tree
-- to build root-directory pass an empty string
function build_tree(path)
	-- first try: all in once (hooray, dont open micro in home or your terminal will run forever)
	--local all_files = shell.RunCommand('find . -type f')
	-- second try: maybe partially like with maxdepth?
	--local all_files = shell.RunCommand('find . -type f -maxdepth 2') --even with maxdepth its not a good solution
	--add_files_to_tree(all_files, '')	--if we only put files inside we are missing empty dirs 
	-- solution: splitting files and sub-dirs to add, only for given path
	-- on expanding a dir in fileview we simply build the missing part for the tree
	add_files_to_tree(path)
	add_directorys_to_tree(path)
	respect_git_diff()
	sort_tree(filetree)
	mark_bin_or_text()
end

-- lua does not support ordered lists/arrays so we have to build a table-array with the keys sorted
-- we store them in sort_dirs and sort_files in each dir-entry of filetree
function sort_tree(folder)
	folder.sort_dirs = {}
	for k, v in pairs(folder.dirs) do
		sort_tree(v)
		table.insert(folder.sort_dirs, k)
	end
	table.sort(folder.sort_dirs)
	folder.sort_files = {}
	for k,v in pairs(folder.files) do
		table.insert(folder.sort_files, k)
	end
	table.sort(folder.sort_files)
end

-- mark if file is binary or text
function mark_bin_or_text()
	--local fulltext = ""
	for filename,file in pairs(allfiles) do
		if not file.text and not file.binary then 
			--fulltext = fulltext .. "'" .. filename .. "'\\\n"
			local test = shell.RunCommand('file -i '..filename)
			if string.find(test,'charset=binary') == nil then 
				file.text = true 
			else 
				file.binary = true
			end 
		end
	end
	--local cmd = "echo ".. fulltext .. ' | grep executable'
	--micro.TermError('command',345,cmd)
	--local bins = shell.RunCommand(cmd)
	--micro.TermError('executed. result',#bins,bins)
end

-- display the tree:

local print_line_nr = 1 --line in which to print
-- display the tree
-- expects optional cursorline: move cursor to cursorline - used when expanding a dir 
-- in fileview to not jump away from it
function display_tree(cursorline)
	print_line_nr = 1
	filetree.entry_on_line = {}
	fileview.Buf.EventHandler:Remove(fileview.Buf:Start(), fileview.Buf:End())
	
	print_folder(filetree, 0)
	if cursorline ~= nil then
		-- Go to line
		micro.CurPane():GotoCmd({cursorline})
	end
end

-- print the line into fileview-buffer
-- just because i am lazy and print_line is shorter then fileview.Buf....
function print_line(linenr, linetext)
	fileview.Buf.EventHandler:Insert(buffer.Loc(0,linenr), linetext .. '\n')
end

-- print the directory:
function print_folder(folder, depth)
	-- first we walk through the subdirectorys:
	for k,foldername in pairs(folder.sort_dirs) do
		local actdir = folder.dirs[foldername]
		-- check if actdir is ignored/hidden - if ignored/hidden and option is set then dont bother
		if (not actdir.ignored or show_ignored) and (not actdir.hidden or show_hidden) then 			
			-- we pretend directorys with a + if its closed, else with a - 
			local pre = "+"
			if actdir.expanded then 
				pre = "-"	
			end
			-- we put a little space in front, depending on the depth in the tree
			local space = string.rep(" ", depth*2)
			-- we put pre_link in front, but not for files/dirs in root
			if actdir.parent.name ~= "root" then space = space .. pre_link end
			-- check if we have to put changed in front
			local begin = " "
			if actdir.changed then begin = pre_changed end
			if actdir.isnew then begin = pre_new end
			if actdir.ignored then begin = pre_ignored end
			-- form a line for the directory entry
			local line = begin .. space .. pre_dir .. pre .. foldername 
			-- print it 
			print_line(print_line_nr, line)
			-- save acces to directory in line-nr array to get access later via buffer.y
			filetree.entry_on_line[print_line_nr] = actdir
			-- as we have printed a line we should increment line-nr
			print_line_nr = print_line_nr + 1
			-- if the actual directory is expanded we should print its content before continuing with the files
			if actdir.expanded then 
				print_folder(actdir, depth + 1)
			end
		end
	end
	-- secondly we walk through the files
	for k, filename in pairs(folder.sort_files) do		
		if filename == nil  or #filename < 2 then
			micro.TermError("filename is nil", 0, '>>' .. #filename .. '<<')
		end
		local actfile = folder.files[filename]
		--check if we have to print file - if its ignored/hidden and option is set we dont bother
		if (not actfile.ignored or show_ignored) and (not actfile.hidden or show_hidden) and (not allfiles[actfile.fullpath].binary or show_binarys) then 
			-- put indent space in front to mark its parent
			local space = string.rep(" ", depth*2)
			if actfile.parent.name ~= "root" then space = space .. pre_link end
			-- put begin in front
			local begin = " "
			if actfile.changed then begin = pre_changed end
			if actfile.isnew then begin = pre_new end
			if actfile.ignored then begin = pre_ignored end		
			--micro.TermError("something is nil", 0, filename .. space .. pre_file .. filename)
			-- form the line
			local line = begin .. space .. pre_file .. filename			
			print_line(print_line_nr, line)
			filetree.entry_on_line[print_line_nr]=actfile
			-- we printed a line so increment line_nr
			print_line_nr = print_line_nr + 1
		end
	end
end

function open_tree_view()
	local actview = micro.CurPane()
	if target_pane == nil or actview ~= fileview then
		target_pane = actview
	end
	--local splitid = actview.Buf.tab
	--micro.TermError('splitid',450,'splitid'..splitid)
	-- Open a new Vsplit (on the very left)
	micro.CurPane():VSplitIndex(buffer.NewBuffer("", "pfileview"), false)
	-- Save the new view so we can access it later
	fileview = micro.CurPane()

	-- Set the width of fileview to 30% & lock it
    fileview:ResizePane(30)
	-- Set the type to unsavable
    -- fileview.Buf.Type = buffer.BTLog
    fileview.Buf.Type.Scratch = true
    --fileview.Buf.Type.Readonly = true

	-- Set the various display settings, but only on our view (by using SetLocalOption instead of SetOption)
	-- NOTE: Micro requires the true/false to be a string
	-- Softwrap long strings (the file/dir paths)
    fileview.Buf:SetOptionNative("softwrap", true)
    -- No line numbering
    fileview.Buf:SetOptionNative("ruler", false)
    -- Is this needed with new non-savable settings from being "vtLog"?
    fileview.Buf:SetOptionNative("autosave", false)
    -- Don't show the statusline to differentiate the view from normal views
    fileview.Buf:SetOptionNative("statusformatr", " [i]:ignored [h]:hidden [b]:binarys")
    fileview.Buf:SetOptionNative("statusformatl", "files")
    fileview.Buf:SetOptionNative("scrollbar", false)
    fileview.Buf:SetOptionNative("filetype","projectfiledisplay")
end

-- close_tree will close the tree plugin view and release memory.
local function close_tree()
	if fileview ~= nil then
		fileview:Quit()
		fileview = nil
		--clear_messenger()
	end
end

-- toggle_tree will toggle the tree view visible (create) and hide (delete).
function toggle_tree(open_again)
	if fileview == nil then
		open_tree_view()
	else
		close_tree()
		if open_again then open_tree_view() end
	end
end

-- open file 
local function open_file(entry)
	if entry == nil or entry.fullpath == nil then 
		return nil 
	end
	if allfiles[entry.fullpath] ~= nil and allfiles[entry.fullpath].binary then 
		micro.InfoBar():Error('cannot open binary file ', entry.fullpath)
		return nil
	end
	target_buff = buffer.NewBufferFromFile(entry.fullpath)
	if target_pane == nil then 
		target_pane = micro.CurPane():VSplitIndex(target_buff, true)	
	else 
		target_pane:OpenBuffer(target_buff)
		micro.CurPane():NextSplit()
	end
end

local function handle_click()
	local y = fileview.Cursor.Loc.Y + 1
	local act_entry = filetree.entry_on_line[y]
	local msg = 'not found'
	if act_entry ~= nil then msg = act_entry.fullpath end
	if act_entry ~= nil and act_entry.hidden then msg = msg ..' hidden' end
	if act_entry ~= nil and act_entry.file then msg = msg ..' file' else 
	msg=msg..' dir'..#act_entry.dirs ..',' .. #act_entry.files .. '|'..act_entry.parent.fullpath
	end
	if act_entry ~= nil and act_entry.expanded then msg = msg ..' expanded' end
	micro.InfoBar():Message('act entry ', msg, ' line', y)
	if act_entry == nil then return nil end
	if act_entry.file then 
		open_file(act_entry)
	else
		-- read and update tree if not filled yet 		
		act_entry.expanded = not act_entry.expanded
		if act_entry.expanded then 
			--micro.TermError(act_entry.fullpath, y, 'hmmm')
			
			build_tree(act_entry.fullpath)
		end
		display_tree(""..y)
	end	
end

function start(bp, args)
	toggle_tree(true)
	build_tree('')
	display_tree()	
end

function init()
	local test_git = shell.RunCommand('git rev-parse --is-inside-work-tree')
	inside_git = (string.sub(test_git,1,4) == 'true')
	--micro.TermError("inside_git",0,'>>'..test_git..'<<')
	config.MakeCommand("repfiles", start, config.NoComplete)	
	config.AddRuntimeFile("repfiles", config.RTSyntax, "syntax.yaml")
	config.RegisterCommonOption("repfiles", "show_ignored", true)
	config.RegisterCommonOption("repfiles", "show_hidden", true)
	show_ignored = config.GetGlobalOption("repfiles.show_ignored")	
	show_hidden = config.GetGlobalOption("repfiles.show_ignored")
	config.TryBindKey("Ctrl-r", "lua:repfiles.start", false)
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- little helpers
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- close_tree will close the tree plugin view and release memory.
local function close_tree()
	if fileview ~= nil then
		fileview:Quit()
		fileview = nil
		filetree.dirs = {}
		filetree.files = {}
		--clear_messenger()
	end
end



-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- All the events for certain Micro keys go below here
-- Other than things we flat-out fail
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


-- Close current
function preQuit(view)
	if view == fileview then
		-- A fake quit function
		close_tree()
		-- Don't actually "quit", otherwise it closes everything without saving for some reason
		return false
	end
end
-- Close all
function preQuitAll(view)
	close_tree()
end


-- handle normal keystrokes on fileview pane:
function preRune(view, r)
	if view ~= fileview then 
		return true 
	end
	if r=='i' then 
		show_ignored = not show_ignored
		display_tree()
	end
	if r=='h' then 
		show_hidden = not show_hidden
		display_tree()
	end
	if r=='b' then 
		show_binarys = not show_binarys
		display_tree()
	end
	if r=='g' then
		inside_git = not inside_git
	end

	return false
end

-- handle enter on search result
function preInsertNewline(view)
    if view == fileview then
    	handle_click()
        return false
    end
    return true
end

function onEscape(view)
	if view == fileview then 
		close_tree()
	end
end