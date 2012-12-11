" scriptease.vim - An amalgamation of crap for editing runtime files
" Maintainer:   Tim Pope <http://tpo.pe/>

if exists('g:loaded_scriptease') || &cp
  finish
endif
let g:loaded_scriptease = 1

" Utility {{{1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '<SNR>\d\+_'),''))
endfunction

function! s:sub(str,pat,rep) abort
  return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfunction

function! s:gsub(str,pat,rep) abort
  return substitute(a:str,'\v\C'.a:pat,a:rep,'g')
endfunction

function! s:shellesc(arg) abort
  if a:arg =~ '^[A-Za-z0-9_/.-]\+$'
    return a:arg
  elseif &shell =~# 'cmd' && a:arg !~# '"'
    return '"'.a:arg.'"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! s:fnameescape(file) abort
  if exists('*fnameescape')
    return fnameescape(a:file)
  else
    return escape(a:file," \t\n*?[{`$\\%#'\"|!<")
  endif
endfunction

function! s:shellslash(path) abort
  if exists('+shellslash') && !&shellslash
    return s:gsub(a:path,'\\','/')
  else
    return a:path
  endif
endfunction

" }}}1
" Completion {{{1

function! s:Complete(A,L,P)
  let sep = !exists("+shellslash") || &shellslash ? '/' : '\'
  let cheats = {
        \ 'a': 'autoload',
        \ 'd': 'doc',
        \ 'f': 'ftplugin',
        \ 'i': 'indent',
        \ 'p': 'plugin',
        \ 's': 'syntax'}
  if a:A =~# '^\w[\\/]' && has_key(cheats,a:A[0])
    let request = cheats[a:A[0]].a:A[1:-1]
  else
    let request = a:A
  endif
  let pattern = substitute(request,'/\|\'.sep,'*'.sep,'g').'*'
  let found = {}
  for path in split(&runtimepath, ',')
    let path = expand(path, ':p')
    let matches = split(glob(path.sep.pattern),"\n")
    call map(matches,'isdirectory(v:val) ? v:val.sep : v:val')
    call map(matches,'expand(v:val, ":p")[strlen(path)+1:-1]')
    for match in matches
      let found[match] = 1
    endfor
  endfor
  return sort(keys(found))
endfunction

" }}}1
" :PP, :PPmsg {{{1

let s:escapes = {
      \ "\b": '\b',
      \ "\e": '\e',
      \ "\f": '\f',
      \ "\n": '\n',
      \ "\r": '\r',
      \ "\t": '\t',
      \ "\"": '\"',
      \ "\\": '\\'}

function! scriptease#dump(object, ...) abort
  let opt = extend({'width': 0, 'level': 0, 'indent': 1, 'tail': 0, 'seen': []}, a:0 ? copy(a:1) : {})
  let opt.seen = copy(opt.seen)
  let childopt = copy(opt)
  let childopt.tail += 1
  let childopt.level += 1
  for i in range(len(opt.seen))
    if a:object is opt.seen[i]
      return type(a:object) == type([]) ? '[...]' : '{...}'
    endif
  endfor
  if type(a:object) ==# type('')
    if a:object =~# "[\001-\037\"]"
      let dump = '"'.s:gsub(a:object, "[\001-\037\"\\\\]", '\=get(s:escapes, submatch(0), printf("\\%03o", char2nr(submatch(0))))').'"'
    else
      let dump = string(a:object)
    endif
  elseif type(a:object) ==# type([])
    let childopt.seen += [a:object]
    let dump = '['.join(map(copy(a:object), 'scriptease#dump(v:val, {"seen": childopt.seen, "level": childopt.level})'), ', ').']'
    if opt.width && opt.level + len(s:gsub(dump, '.', '.')) > opt.width
      let space = repeat(' ', opt.level)
      let dump = "[".join(map(copy(a:object), 'scriptease#dump(v:val, childopt)'), ",\n ".space).']'
    endif
  elseif type(a:object) ==# type({})
    let childopt.seen += [a:object]
    let keys = sort(keys(a:object))
    let dump = '{'.join(map(copy(keys), 'scriptease#dump(v:val) . ": " . scriptease#dump(a:object[v:val], {"seen": childopt.seen, "level": childopt.level})'), ', ').'}'
    if opt.width && opt.level + len(s:gsub(dump, '.', '.')) > opt.width
      let space = repeat(' ', opt.level)
      let lines = []
      let last = get(keys, -1, '')
      for k in keys
        let prefix = scriptease#dump(k) . ':'
        let suffix = scriptease#dump(a:object[k]) . ','
        if len(space . prefix . ' ' . suffix) >= opt.width - (k ==# last ? opt.tail : '')
          call extend(lines, [prefix, scriptease#dump(a:object[k], childopt) . ','])
        else
          call extend(lines, [prefix . ' ' . suffix])
        endif
      endfor
      let dump = s:sub("{".join(lines, "\n " . space), ',$', '}')
    endif
  elseif type(a:object) ==# type(function('tr'))
    let dump = s:sub(string(a:object), '^function\(''(\d+)''\)$', 'function(''{\1}'')')
  else
    let dump = string(a:object)
  endif
  return dump
endfunction

function! s:backslashdump(value, indent)
    let out = scriptease#dump(a:value, {'level': 0, 'width': &textwidth - &shiftwidth * 3 - a:indent})
    return s:gsub(out, '\n', "\n".repeat(' ', a:indent + &shiftwidth * 3).'\\')
endfunction

function! s:dump(bang, lnum, value) abort
  if v:errmsg !=# ''
    return
  elseif a:lnum == 999998
    echo scriptease#dump(a:value, {'width': a:bang ? 0 : &columns-1})
  else
    exe a:lnum
    let indent = indent(prevnonblank('.'))
    if a:bang
      let out = scriptease#dump(a:value)
    else
      let out = s:backslashdump(a:value, indent)
    endif
    put =repeat(' ', indent).'PP '.out
    '[
  endif
endfunction

function! s:dumpmsg(bang, count, value) abort
  if v:errmsg !=# ''
    return
  elseif &verbose >= a:count
    for line in split(scriptease#dump(a:value, {'width': a:bang ? 0 : &columns-1}), "\n")
      echomsg line
    endfor
  endif
endfunction

command! -bang -range=999998 -nargs=1 -complete=expression PP
      \ :let v:errmsg = ''|call s:dump(<bang>0, <count>, eval(<q-args>))
command! -bang -range=0      -nargs=1 -complete=expression PPmsg
      \ :let v:errmsg = ''|call s:dumpmsg(<bang>0, <count>, eval(<q-args>))

" }}}1
" :Verbose {{{1

command! -range=999998 -nargs=1 -complete=command Verbose
      \ :exe s:Verbose(<count> == 999998 ? '' : <count>, <q-args>)

function! s:Verbose(level, excmd)
  let temp = tempname()
  let verbosefile = &verbosefile
  call writefile([':'.a:level.'Verbose '.a:excmd], temp, 'b')
  return
        \ 'try|' .
        \ 'let &verbosefile = '.string(temp).'|' .
        \ a:level.'verbose exe '.string(a:excmd).'|' .
        \ 'finally|' .
        \ 'let &verbosefile = '.string(verbosefile).'|' .
        \ 'endtry|' .
        \ 'pedit '.temp.'|wincmd P'
endfunction

" }}}1
" :Scriptnames {{{1

function! scriptease#capture(excmd) abort
  try
    redir => out
    exe 'silent! '.a:excmd
  finally
    redir END
  endtry
  return out
endfunction

function! s:names() abort
  let names = scriptease#capture('scriptnames')
  let list = []
  for line in split(names, "\n")
    if line =~# ':'
      call add(list, {'text': matchstr(line, '\d\+'), 'filename': expand(matchstr(line, ': \zs.*'))})
    endif
  endfor
  return list
endfunction

function! scriptease#scriptname(file) abort
  if a:file =~# '^\d\+$'
    return get(s:names(), a:file-1, {'filename': a:file}).filename
  else
    return a:file
  endif
endfunction

command! -bar Scriptnames call setqflist(s:names())|copen

" }}}1
" :Runtime {{{1

function! s:unlet_for(files) abort
  let guards = []
  for file in a:files
    if filereadable(file)
      let lines = readfile(file, 100)
      for i in range(len(lines)-1)
        let unlet = matchstr(lines[i], '^if exists([''"]\%(\g:\)\=\zs\w\+\ze[''"]')
        if unlet !=# '' && lines[i+1] =~# '^ *finish\>' && index(guards, unlet) == -1
          call extend(guards, [unlet])
        endif
      endfor
    endif
  endfor
  if empty(guards)
    return ''
  else
    return 'unlet! '.join(guards, ' ')
  endif
endfunction

function! s:lencompare(a, b)
  return len(a:b) - len(a:b)
endfunction

function! s:findinrtp(path)
  let path = fnamemodify(a:path, ':p')
  let candidates = filter(split(&runtimepath, ','), 'path[0 : len(v:val)-1] ==# v:val && path[len(v:val)] =~# "[\\/]"')
  if empty(candidates)
    return ''
  endif
  let preferred = sort(candidates, s:function('s:lencompare'))[-1]
  return path[strlen(preferred)+1 : -1]
endfunction

function! s:runtime(bang, ...) abort
  let unlets = []
  let do = []
  let predo = ''

  if a:0
    let files = a:000
  elseif &filetype ==# 'vim' || expand('%:e') ==# 'vim'
    let files = [s:findinrtp(expand('%:p'))]
    if empty(files[0])
      let files = ['%']
    endif
    if &modified
      let predo = 'silent write|'
    endif
  else
    for ft in split(&filetype, '\.')
      for pattern in ['ftplugin/%s.vim', 'ftplugin/%s_*.vim', 'ftplugin/%s/*.vim', 'indent/%s.vim', 'syntax/%s.vim', 'syntax/%s/*.vim']
        call extend(unlets, split(globpath(&rtp, printf(pattern, ft)), "\n"))
      endfor
    endfor
    let run = s:unlet_for(unlets)
    if run !=# ''
      let run .= '|'
    endif
    let run .= 'filetype detect'
    echo ':'.run
    return run
  endif

  for request in files
    if request =~# '^\.\=[\\/]\|^\w:[\\/]\|^[%#~]\|^\d\+$'
      let request = scriptease#scriptname(request)
      let unlets += split(glob(request), "\n")
      let do += ['source '.escape(request, " \t|!")]
    else
      if get(do, 0, [''])[0] !~# '^runtime!'
        let do += ['runtime!']
      endif
      let unlets += split(globpath(&rtp, request, 1), "\n")
      let do[-1] .= ' '.escape(request, " \t|!")
    endif
  endfor
  call extend(do, ['filetype detect'])
  let run = s:unlet_for(unlets)
  if run !=# ''
    let run .= '|'
  endif
  let run .= join(do, '|')
  echo ':'.run
  return predo.run
endfunction

command! -bang -bar -nargs=* -complete=customlist,s:Complete Runtime
      \ :exe s:runtime('<bang>', <f-args>)

" }}}1
" :Vopen, :Vedit, ... {{{1

function! s:runtime_findfile(file,count)
  let file = findfile(a:file, escape(&rtp, ' '), a:count)
  if type(file) == type([])
    return map(file, 'fnamemodify(v:val, ":p")')
  elseif file ==# ''
    return ''
  else
    return fnamemodify(file,':p')
  endif
endfunction

function! s:find(count,cmd,file,lcd)
  let file = s:runtime_findfile(a:file,a:count)
  if file ==# ''
    return "echoerr 'E345: Can''t find file \"".a:file."\" in runtimepath'"
  elseif a:cmd ==# 'read'
    return a:cmd.' '.s:fnameescape(file)
  elseif a:lcd
    let path = file[0:-strlen(a:file)-2]
    return a:cmd.' '.s:fnameescape(file) . '|lcd '.s:fnameescape(path)
  else
    if a:cmd !~# '^edit'
      exe a:cmd
    endif
    call setloclist(0, map(s:runtime_findfile(a:file, -1),
          \ '{"filename": v:val, "text": v:val[0 : -len(a:file)-2]}'))
    return 'll'.matchstr(a:cmd, '!$').' '.a:count
  endif
endfunction

command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Ve
      \ :execute s:find(<count>,'edit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vedit
      \ :execute s:find(<count>,'edit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vopen
      \ :execute s:find(<count>,'edit<bang>',<q-args>,1)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vsplit
      \ :execute s:find(<count>,'split',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vvsplit
      \ :execute s:find(<count>,'vsplit',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vtabedit
      \ :execute s:find(<count>,'tabedit',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vpedit
      \ :execute s:find(<count>,'pedit',<q-args>,<bang>0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vread
      \ :execute s:find(<count>,'read',<q-args>,<bang>0)

" }}}1
" zS {{{1

function! scriptease#synnames(...) abort
  if a:0
    let [line, col] = [a:1, a:2]
  else
    let [line, col] = [line('.'), col('.')]
  endif
  return reverse(map(synstack(line, col), 'synIDattr(v:val,"name")'))
endfunction

function! s:zS(count)
  if a:count
    let name = get(scriptease#synnames(), a:count-1, '')
    if name !=# ''
      return 'syntax list '.name
    endif
  else
    echo join(scriptease#synnames(), ' ')
  endif
  return ''
endfunction

nnoremap <silent> <Plug>ScripteaseSynnames :<C-U>exe <SID>zS(v:count)<CR>
nmap zS <Plug>ScripteaseSynnames

" }}}1
" K {{{1

augroup scriptease_help
  autocmd!
  autocmd FileType vim nmap <silent><buffer> K :exe 'help '.<SID>helptopic()<CR>
augroup END

function! s:helptopic()
  let col = col('.') - 1
  while col && getline('.')[col] =~# '\k'
    let col -= 1
  endwhile
  let pre = col == 0 ? '' : getline('.')[0 : col]
  let col = col('.') - 1
  while col && getline('.')[col] =~# '\k'
    let col += 1
  endwhile
  let post = getline('.')[col : -1]
  let syn = get(scriptease#synnames(), 0, '')
  let cword = expand('<cword>')
  if syn ==# 'vimFuncName'
    return cword.'()'
  elseif syn ==# 'vimOption'
    return "'".cword."'"
  elseif pre =~# '^\s*:\=$'
    return ':'.cword
  elseif pre =~# '\<v:$'
    return 'v:'.cword
  elseif cword ==# 'v' && post =~# ':\w\+'
    return 'v'.matchstr(post, ':\w\+')
  else
    return cword
  endif
endfunction

" }}}1
" Settings {{{1

function! s:setup() abort
  let &l:path = escape(&runtimepath, ' ')
  setlocal suffixesadd=.vim keywordprg=:help
endfunction

augroup scriptease
  autocmd!
  autocmd FileType vim call s:setup()
  " Recent versions of vim.vim set iskeyword to include ":", which breaks among
  " other things tags. :(
  autocmd Syntax vim setlocal iskeyword-=:
augroup END

" }}}1

" vim:set et sw=2:
