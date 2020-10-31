if exists('g:loaded_luafmt')
    finish
endif

command! -range=% -nargs=0 LuaFormat call luafmt#replace(<line1>, <line2>)

augroup plugin-luafmt-auto-format
    autocmd!
    autocmd FileType lua
        \     setlocal formatexpr=luafmt#replace(v:lnum,v:lnum+v:count-1) |
augroup END

let g:loaded_luafmt = 1
