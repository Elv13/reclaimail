set runtimepath^=~/.vim runtimepath+=~/.vim/after
set runtimepath+=$APPDIR/share/nvim/runtime/
let &packpath = &runtimepath

" Need to be done first, before "syntax on"
set notermguicolors

" Indentation
set shiftwidth=4

set nomagic

silent! unmap <Tab>
silent! unmap <S-Tab>
silent! unmap <C-Tab>
silent! unmap <C-s>
silent! unmap <A-Left>
silent! unmap <A-Right>

" Remove trailing spaces on save
autocmd BufWritePre * %s/\s\+$//e

" All the keymap and whatever is available using Lua

let local_config = $HOME . "/.config/nvim/lua/rc.lua"

if filereadable(local_config)
    lua dofile(os.getenv("HOME").."/.config/nvim/lua/rc.lua")
else
    " This should be part of the AppImage
    lua dofile("/etc/nvim/lua/rc.lua")
endif

" Add a Lua callback when the statusline gets updated
function! StatusUpdateCallback(m, w)
    let func = join(["lua status_update_callback('", a:m, "', '", a:w, "')"])
    return trim(execute(func, "silent"))
endfunction
function! TabUpdateCallback(m, n)
    let func = join(["lua tab_update_callback('", a:m, "', '", a:n, "')"])
    return trim(execute(func, "silent"))
endfunction

syntax on
filetype plugin indent on

setlocal spell spelllang=en_us
set mouse=a
set mousemodel=popup_setpos
set cursorline


" Remove the delay when presing escape
" https://www.johnhawthorn.com/2012/09/vi-escape-delays/
set timeoutlen=33 ttimeoutlen=33

set laststatus=2
set noshowmode

colorscheme elflord

set tabstop=4
set expandtab

" Make search case insensitive
set ignorecase


" Wrap the cursor at the end of the line
set whichwrap+=<,>,h,l,[,]

set backspace=indent,eol,start

start
