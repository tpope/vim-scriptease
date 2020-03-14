" scriptease.vim - An amalgamation of crap for editing runtime files
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.0

if exists('g:loaded_scriptease') || &cp
  finish
endif
let g:loaded_scriptease = 1

" Section: Commands

command! -bang -range=-1 -nargs=? -complete=expression PP
      \ if empty(<q-args>) |
      \   let s:more = &more |
      \   try |
      \     set nomore |
      \     while 1 |
      \       let s:input = input('PP> ', '', 'expression') |
      \       if empty(s:input) |
      \         break |
      \       endif |
      \       echon "\n" |
      \       let v:errmsg = '' |
      \       try |
      \         call scriptease#pp_command(<bang>0, -1, eval(s:input)) |
      \       catch |
      \         echohl ErrorMsg |
      \         echo v:exception |
      \         echo v:throwpoint |
      \         echohl NONE |
      \       endtry |
      \     endwhile |
      \ finally |
      \   let &more = s:more |
      \ endtry |
      \ else |
      \   let v:errmsg = '' |
      \   call scriptease#pp_command(<bang>0, <count>, eval(<q-args>)) |
      \ endif

command! -bang -range=0      -nargs=? -complete=expression PPmsg
      \ if !empty(<q-args>) |
      \   let v:errmsg = '' |
      \   call scriptease#ppmsg_command(<bang>0, <count>, empty(<q-args>) ? expand('<sfile>') : eval(<q-args>)) |
      \ elseif &verbose >= <count> && !empty(expand('<sfile>')) |
      \  echomsg expand('<sfile>').', line '.expand('<slnum>') |
      \ endif

let s:addr_other = has('patch-8.1.560') ? ' -addr=other ' : ''
exe 'command! -range=-1 -nargs=1 -complete=command' s:addr_other 'Verbose'
      \ ':exe scriptease#verbose_command(<count> == -1 ? "" : <count>, <q-args>)'

command! -bar -count=0 Scriptnames
      \ call setqflist(scriptease#scriptnames_qflist()) |
      \ copen |
      \ <count>

command! -bar -bang Messages :execute scriptease#messages_command(<bang>0)

command! -bang -bar -range=-1 -nargs=* -complete=customlist,scriptease#complete Runtime
      \ :exe scriptease#runtime_command('<bang>', <f-args>)

command! -bang -bar -nargs=* -complete=customlist,scriptease#complete Disarm
      \ :exe scriptease#disarm_command(<bang>0, <f-args>)

command! -range=1 -nargs=? -complete=command Time :exe scriptease#time_command(<q-args>, <line2>)

command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Ve
      \ :execute scriptease#open_command(<count>,'edit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vedit
      \ :execute scriptease#open_command(<count>,'edit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vopen
      \ :execute scriptease#open_command(<count>,'edit<bang>',<q-args>,1)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vsplit
      \ :execute scriptease#open_command(<count>,'split',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vvsplit
      \ :execute scriptease#open_command(<count>,'vsplit',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vtabedit
      \ :execute scriptease#open_command(<count>,'tabedit',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vpedit
      \ :execute scriptease#open_command(<count>,'pedit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,scriptease#complete Vread
      \ :execute scriptease#open_command(<count>,'read',<q-args>,<bang>0)

command! -bang -nargs=+ -complete=mapping MapHelp
      \ :call scriptease#maphelp(<bang>0 ? 'Verbose ' : 'verbose ', <f-args>)

" Section: Maps

nnoremap <expr> <Plug>ScripteaseFilter scriptease#filterop()
xnoremap <expr> <Plug>ScripteaseFilter scriptease#filterop()
onoremap <SID>_ _
if empty(mapcheck('g=', 'n'))
  nmap g= <Plug>ScripteaseFilter
  nmap g== <Plug>ScripteaseFilter<SID>_
endif
if empty(mapcheck('g=', 'x'))
  xmap g= <Plug>ScripteaseFilter
endif
if empty(mapcheck('g!', 'n'))
  nmap g! <Plug>ScripteaseFilter
  nmap g!! <Plug>ScripteaseFilter<SID>_
endif
if empty(mapcheck('g!', 'x'))
  xmap g! <Plug>ScripteaseFilter
endif

nnoremap <silent> <Plug>ScripteaseSynnames :<C-U>exe scriptease#synnames_map(v:count)<CR>
if empty(mapcheck('zS', 'n'))
  nmap zS <Plug>ScripteaseSynnames
endif

" Section: Filetype

augroup scriptease
  autocmd!
  autocmd FileType help call scriptease#setup_help()
  autocmd FileType vim call scriptease#setup_vim()
  " Recent versions of vim.vim set iskeyword to include ":", which breaks among
  " other things tags. :(
  autocmd FileType vim
        \ if get(g:, 'scriptease_iskeyword', 1) |
        \   setlocal iskeyword-=: |
        \ endif
  autocmd Syntax vim
        \ if get(g:, 'scriptease_iskeyword', 1) |
        \   setlocal iskeyword-=: |
        \ endif
augroup END

" Section: Projectionist

function! s:projectionist_detect() abort
  let file = get(g:, 'projectionist_file', '')
  let path = substitute(scriptease#locate(file)[0], '[\/]after$', '', '')
  if !empty(path)
    let reload = ":Runtime ./{open}autoload,plugin{close}/**/*.vim"
    call projectionist#append(path, {
          \ "*": {"start": reload},
          \ "*.vim": {"start": reload},
          \ "plugin/*.vim":   {"command": "plugin", "alternate": "autoload/{}.vim"},
          \ "autoload/*.vim": {"command": "autoload", "alternate": "plugin/{}.vim"},
          \ "compiler/*.vim": {"command": "compiler"},
          \ "ftdetect/*.vim": {"command": "ftdetect"},
          \ "syntax/*.vim":   {"command": "syntax", "alternate": ["ftplugin/{}.vim", "indent/{}.vim"]},
          \ "ftplugin/*.vim": {"command": "ftplugin", "alternate": ["indent/{}.vim", "syntax/{}.vim"]},
          \ "indent/*.vim":   {"command": "indent", "alternate": ["syntax/{}.vim", "ftplugin/{}.vim"]},
          \ "after/*.vim":    {"command": "after"},
          \ "doc/*.txt":      {"command": "doc", "start": reload}})
  endif
endfunction

augroup scriptease_projectionist
  autocmd!
  autocmd User ProjectionistDetect call s:projectionist_detect()
augroup END

" vim:set et sw=2:
