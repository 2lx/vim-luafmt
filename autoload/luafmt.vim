let s:save_cpo = &cpo
set cpo&vim

let s:on_windows = has('win32') || has('win64')
let s:dict_t = type({})
let s:list_t = type([])
if exists('v:true')
    let s:bool_t = type(v:true)
else
    let s:bool_t = -1
endif

function! s:has_vimproc() abort
    if !exists('s:exists_vimproc')
        try
            silent call vimproc#version()
            let s:exists_vimproc = 1
        catch
            let s:exists_vimproc = 0
        endtry
    endif
    return s:exists_vimproc
endfunction

function! s:system(str, ...) abort
    let command = a:str
    let input = a:0 >= 1 ? a:1 : ''

    if a:0 == 0 || a:1 ==# ''
        silent let output = s:has_vimproc() ?
                    \ vimproc#system(command) : system(command)
    elseif a:0 == 1
        silent let output = s:has_vimproc() ?
                    \ vimproc#system(command, input) : system(command, input)
    else
        " ignores 3rd argument unless you have vimproc.
        silent let output = s:has_vimproc() ?
                    \ vimproc#system(command, input, a:2) : system(command, input)
    endif

    return output
endfunction

function! s:success(result) abort
    let exit_success = (s:has_vimproc() ? vimproc#get_last_status() : v:shell_error) == 0
    return exit_success && a:result !~# '^YAML:\d\+:\d\+: error: unknown key '
endfunction

function! s:error_message(result) abort
    echoerr 'luafmt has failed to format.'
    if a:result =~# '^YAML:\d\+:\d\+: error: unknown key '
        echohl ErrorMsg
        for l in split(a:result, "\n")[0:1]
            echomsg l
        endfor
        echohl None
    endif
endfunction

function! luafmt#is_invalid() abort
    if !exists('s:command_available')
        if !executable(g:luafmt#command)
            return 1
        endif
        let s:command_available = 1
    endif

    return 0
endfunction

function! s:verify_command() abort
    let invalidity = luafmt#is_invalid()
    if invalidity == 1
        echoerr "luafmt is not found. check g:luafmt#command."
    endif
endfunction

function! s:shellescape(str) abort
    if s:on_windows && (&shell =~? 'cmd\.exe')
        " shellescape() surrounds input with single quote when 'shellslash' is on. But cmd.exe
        " requires double quotes. Temporarily set it to 0.
        let shellslash = &shellslash
        set noshellslash
        try
            return shellescape(a:str)
        finally
            let &shellslash = shellslash
        endtry
    endif
    return shellescape(a:str)
endfunction

function! s:getg(name, default) abort
    return get(g:, a:name, a:default)
endfunction

let g:luafmt#command = s:getg('luafmt#command', 'luafmt')
let g:luafmt#extra_args = s:getg('luafmt#extra_args', "")
if type(g:luafmt#extra_args) == type([])
    let g:luafmt#extra_args = join(g:luafmt#extra_args, " ")
endif

function! luafmt#format(line1, line2) abort
    let args = printf(' --line_range=%d:%d', a:line1, a:line2)
    let filename = expand('%')
    if filename !=# ''
        let args .= printf(' %s ', s:shellescape(escape(filename, " \t")))
    endif
    let args .= g:luafmt#extra_args
    let luafmt = printf('%s %s ', s:shellescape(g:luafmt#command), args)
    let source = join(getline(1, '$'), "\n")
    return s:system(luafmt, source)
endfunction

function! luafmt#trim_end_lines() abort
    let save_cursor = getpos(".")
    silent! %s#\($\n\s*\)\+\%$##
    call setpos('.', save_cursor)
endfunction

function! luafmt#replace(line1, line2, ...) abort
    call s:verify_command()
    
    write
    " undo granulation
    call feedkeys("i\<C-G>u\<Esc>", 'n')

    let pos_save = a:0 >= 1 ? a:1 : getpos('.')
    let formatted = luafmt#format(a:line1, a:line2)
    if !s:success(formatted)
        call s:error_message(formatted)
        return
    endif

    let winview = winsaveview()
    let splitted = split(formatted, '\n', 1)

    silent! undojoin
    if line('$') > len(splitted)
        execute len(splitted) .',$delete' '_'
    endif
    call setline(1, splitted)
    call winrestview(winview)
    call setpos('.', pos_save)

    call luafmt#trim_end_lines()
    write
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
