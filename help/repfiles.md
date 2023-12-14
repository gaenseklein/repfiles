# repfiles - a filemanager for your repository 

repfiles is a filemanager based on git-repositorys. 
it will use the working directory (the directory micro was launched from) as root-directory.
if directory is root-directory of a git-repository it will reflect git-status of 
files and directorys. 

to open filemanager use `repfiles` or `Ctrl-r` as default.
you can bind in your bindings.json with command repfiles.start
like `"Ctrl-r": "lua:repfiles.start",`

see `help keybindings` for more info about keybindings

## usage

- use `enter` to open file or expand/minimize directory
- use `tab` to open file in a separate view
- use arrow-keys to navigate inside filetree (left: go up dir/minimize dir, right: expand dir)

## filter

you can filter the output. press keys while cursor inside filemanager:

- [i]: ignored in git-repository (.gitignore)
- [h]: hidden files 
- [b]: binary files

## other actions

some other actions you can do while inside filemanager:
- [t]: show filters
- [g]: reflect git-state of files and folders (mark as new/changed)
- [a]: add new file
- [A]: add new directory
- [d]: duplicate file (only while on files)

## options

some options to alter the default behaviour of repfiles:

- show_ignored: defaults the .gitignore filter - default true
- show_hidden: defaults the hidden files filter - default true
- auto_close_after_open: closes the filemanager after opening file - default true
- show_filter_block: shows filter configuration under fileview - default true
- filefonts: use different icons for files (like for mp3, jpg...) - default true
- nerdfonts: use nerdfonts¹ icons to differentiate files. only active with filefonts true. default false

to change this options you can either edit your settings.json or from inside micro-command-line - for example `> set repfiles.show_ignored false` to not show ignored files by git as default

### ¹ nerdfonts
to make use of nerdfonts you have to manualy install a [nerd font](https://www.nerdfonts.com/) or compatible font. 
if nerdfonts is active it uses the filemanager2-icon.lua to get the right icon for the file

## theming

if you want different icons you can use icon.lua to either change some icons or write your own 
icon-plugin. if you do so the filefonts-option has to be active. 

### every icon.lua returns two functions:
- Icons() -> returns a table with {name:icon}
- GetIcon(path, is_text) -> returns the icon fit for the path given. the is_text boolean is set to true to files known to be text-files

note: if repfiles.nerdfonts is true it will use filemanager2-icon.lua instead of icon.lua
filemanager2-icon.lua is a script taken from [filemanager2 plugin](https://codeberg.org/micro-plugins/filemanager2)
to use nerdfont-icons. therefore it needs a nerd font installed. 
