# repfiles - a file manager for your repository 

repfilemanager is a filemanager based on git-repositorys. 
it will use the working directory (the directory micro was launched from) as root-directory.
if directory is root-directory of a git-repository it will reflect git-status of 
files and directorys. 

to open filemanager use `repfiles` or `Ctrl-r` as default.
you can bind in your bindings.json with command repfiles.start
like `"Ctrl-r": "lua:repfiles.start",`
see `help keybindings` for more info about keybindings

## usage

use `enter` to open file or expand/minimize directory


## filter

you can filter the output. press keys while cursor inside filemanager:

[i]: ignored in git-repository (.gitignore)
[h]: hidden files 
[b]: binary files