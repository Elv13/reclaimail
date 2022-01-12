set runtimepath^=~/.vim runtimepath+=~/.vim/after
set runtimepath+=$APPDIR/opt/neovim-static/share/nvim/runtime/
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

set mouse=a
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

hi TabLine      ctermfg=Black  ctermbg=Gray     cterm=NONE
hi TabLineFill  ctermfg=Black  ctermbg=Gray     cterm=NONE
hi TabLineSel   ctermfg=White  ctermbg=DarkBlue  cterm=NONE

hi MsgArea ctermbg=236 ctermfg=230
hi MoreMsg term=bold ctermfg=230 cterm=bold
hi ErrorMsg ctermfg=196 ctermbg=236 cterm=bold
hi WarningMsg ctermfg=214 ctermbg=236 cterm=bold

" Wrap the cursor at the end of the line
set whichwrap+=<,>,h,l,[,]

set backspace=indent,eol,start

" Map alt+arrow to navigate panes
"nnoremap <silent> <M-Right> <c-w>l
"nnoremap <silent> <M-Left> <c-w>h
"nnoremap <silent> <M-Up> <c-w>k
"nnoremap <silent> <M-Down> <c-w>j

"imap \e[a <S-Up>
"imap \e[b <S-Down>
"imap \e[c <S-Right>
"imap \e[d <S-Left>

" Color
highlight CursorLineNR cterm=bold ctermbg=234 ctermfg=75

highlight clear CursorLine
highlight CursorLine cterm=bold ctermbg=232 ctermfg=None

highlight Pmenu ctermbg=234 guibg=NONE ctermfg=white
highlight PmenuSel ctermbg=Red  ctermfg=White

function! SearchCount()
  "let keyString=@/
  "let pos=getpos('.')
  "try
  "   redir => nth
  "    silent exe '0,.s/' . keyString . '//ne'
  "  redir => cnt
  "    silent exe '%s/' . keyString . '//ne'
  "  redir END
  "  return matchstr( nth, '\d\+' ) . '/' . matchstr( cnt, '\d\+' )
  "finally
  "  call setpos('.', pos)
  "endtry
endfunction

start
