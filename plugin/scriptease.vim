" scriptease.vim - An amalgamation of crap for editing runtime files
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.0

if exists('g:loaded_scriptease') || &cp
  finish
endif
let g:loaded_scriptease = 1

" Utility {{{1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
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
  for glob in split(&runtimepath, ',')
    for path in map(split(glob(glob), "\n"), 'fnamemodify(v:val, ":p")')
      let matches = split(glob(path.sep.pattern),"\n")
      call map(matches,'isdirectory(v:val) ? v:val.sep : v:val')
      call map(matches,'fnamemodify(v:val, ":p")[strlen(path)+1:-1]')
      for match in matches
        let found[match] = 1
      endfor
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
    if a:object =~# "[\001-\037']"
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

command! -bang -range=999998 -nargs=? -complete=expression PP
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
      \         call s:dump(<bang>0, 999998, eval(s:input)) |
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
      \   call s:dump(<bang>0, <count>, eval(<q-args>)) |
      \ endif

command! -bang -range=0      -nargs=? -complete=expression PPmsg
      \ if !empty(<q-args>) |
      \   let v:errmsg = '' |
      \   call s:dumpmsg(<bang>0, <count>, empty(<q-args>) ? expand('<sfile>') : eval(<q-args>)) |
      \ elseif &verbose >= <count> && !empty(expand('<sfile>')) |
      \  echomsg expand('<sfile>').', line '.expand('<slnum>') |
      \ endif

" }}}1
" g! {{{1

function! s:opfunc(type) abort
  let sel_save = &selection
  let cb_save = &clipboard
  let reg_save = @@
  try
    set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
    if a:type =~ '^\d\+$'
      silent exe 'normal! ^v'.a:type.'$hy'
    elseif a:type =~# '^.$'
      silent exe "normal! `<" . a:type . "`>y"
    elseif a:type ==# 'line'
      silent exe "normal! '[V']y"
    elseif a:type ==# 'block'
      silent exe "normal! `[\<C-V>`]y"
    else
      silent exe "normal! `[v`]y"
    endif
    redraw
    return @@
  finally
    let @@ = reg_save
    let &selection = sel_save
    let &clipboard = cb_save
  endtry
endfunction

function! s:filterop(type) abort
  let reg_save = @@
  try
    let expr = s:opfunc(a:type)
    let @@ = matchstr(expr, '^\_s\+').scriptease#dump(eval(s:gsub(expr,'\n%(\s*\\)=',''))).matchstr(expr, '\_s\+$')
    if @@ !~# '^\n*$'
      normal! gvp
    endif
  catch /^.*/
    echohl ErrorMSG
    echo v:errmsg
    echohl NONE
  finally
    let @@ = reg_save
  endtry
endfunction

nnoremap <silent> <Plug>ScripteaseFilter :<C-U>set opfunc=<SID>filterop<CR>g@
xnoremap <silent> <Plug>ScripteaseFilter :<C-U>call <SID>filterop(visualmode())<CR>
nmap g! <Plug>ScripteaseFilter
nmap g!! <Plug>ScripteaseFilter_
xmap g! <Plug>ScripteaseFilter

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
        \ 'silent '.a:level.'verbose exe '.string(a:excmd).'|' .
        \ 'finally|' .
        \ 'let &verbosefile = '.string(verbosefile).'|' .
        \ 'endtry|' .
        \ 'pedit '.temp.'|wincmd P|nnoremap <buffer> q :bd<CR>'
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

function! scriptease#scriptid(filename) abort
  let filename = fnamemodify(expand(a:filename), ':p')
  for script in s:names()
    if script.filename ==# filename
      return +script.text
    endif
  endfor
  return ''
endfunction

command! -bar Scriptnames call setqflist(s:names())|copen

" }}}1
" :Runtime {{{1

function! s:unlet_for(files) abort
  let guards = []
  for file in a:files
    if filereadable(file)
      let lines = readfile(file)
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
    return 'unlet! '.join(map(guards, '"g:".v:val'), ' ')
  endif
endfunction

function! s:lencompare(a, b)
  return len(a:a) - len(a:b)
endfunction

function! s:findinrtp(path)
  let path = fnamemodify(a:path, ':p')
  let candidates = []
  for glob in split(&runtimepath, ',')
    let candidates += filter(split(glob(glob), "\n"), 'path[0 : len(v:val)-1] ==# v:val && path[len(v:val)] =~# "[\\/]"')
  endfor
  if empty(candidates)
    return ['', '']
  endif
  let preferred = sort(candidates, s:function('s:lencompare'))[-1]
  return [preferred, path[strlen(preferred)+1 : -1]]
endfunction

function! s:runtime(bang, ...) abort
  let unlets = []
  let do = []
  let predo = ''

  if a:0
    let files = a:000
  elseif &filetype ==# 'vim' || expand('%:e') ==# 'vim'
    let files = [s:findinrtp(expand('%:p'))[1]]
    if empty(files[0])
      let files = ['%']
    endif
    if &modified && (&autowrite || &autowriteall)
      let predo = 'silent wall|'
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
" :Disarm {{{1

function! scriptease#disarm(file)
  let augroups = filter(readfile(a:file), 'v:val =~# "^\\s*aug\\%[roup]\\s"')
  call filter(augroups, 'v:val !~# "^\\s*aug\\%[roup]\\s\\+END"')
  for augroup in augroups
    exe augroup
    autocmd!
    augroup END
    exe s:sub(augroup, 'aug\%[roup]', '&!')
  endfor
  call s:disable_maps_and_commands(a:file, 0)
  let tabnr = tabpagenr()
  let winnr = winnr()
  let altwinnr = winnr('#')
  tabdo windo call s:disable_maps_and_commands(a:file, 1)
  exe 'tabnext '.tabnr
  exe altwinnr.'wincmd w'
  exe winnr.'wincmd w'
  return s:unlet_for([a:file])
endfunction

function! s:disable_maps_and_commands(file, buf)
  let last_set = "\tLast set from " . fnamemodify(a:file, ':~')
  for line in split(scriptease#capture('verbose command'), "\n")
    if line ==# last_set
      if last[2] ==# (a:buf ? 'b' : ' ')
        exe 'delcommand '.matchstr(last[4:-1], '^\w\+')
      endif
    else
      let last = line
    endif
  endfor
  for line in split(scriptease#capture('verbose map').scriptease#capture('verbose map!'), "\n")
    if line ==# last_set
      let map = matchstr(last, '^.\s\+\zs\S\+')
      let rest = matchstr(last, '^.\s\+\S\+\s\+\zs[&* ][ @].*')
      if rest[1] ==# (a:buf ? '@' : ' ')
        let cmd = last =~# '^!' ? 'unmap! ' : last[0].'unmap '
        exe cmd.(a:buf ? '<buffer>' : '').map
      endif
    else
      let last = line
    endif
  endfor
endfunction

function! s:disarm(...) abort
  let files = []
  let unlets = []
  for request in a:000
    if request =~# '^\.\=[\\/]\|^\w:[\\/]\|^[%#~]\|^\d\+$'
      let request = expand(scriptease#scriptname(request))
      if isdirectory(request)
        let request .= "/**/*.vim"
      endif
      let files += split(glob(request), "\n")
    else
      let files += split(globpath(&rtp, request, 1), "\n")
    endif
  endfor
  for file in files
    let unlets += [scriptease#disarm(expand(file))]
  endfor
  echo join(files, ' ')
  return join(filter(unlets, 'v:val !=# ""'), '|')
endfunction

command! -bang -bar -nargs=* -complete=customlist,s:Complete Disarm
      \ :exe s:disarm(<f-args>)

" }}}1
" :Breakadd, :Breakdel {{{1

augroup scriptease_breakadd
  autocmd!
  autocmd FileType vim command!
        \   -buffer -bar -nargs=? -complete=custom,s:Complete_breakadd Breakadd
        \ :exe s:break('add',<q-args>)
  autocmd FileType vim command!
        \   -buffer -bar -nargs=? -complete=custom,s:Complete_breakdel Breakdel
        \ :exe s:break('del',<q-args>)
augroup END

function! s:breaksnr(arg) abort
  let id = scriptease#scriptid('%')
  if id
    return s:gsub(a:arg, '^func.*\zs%(<s:|\<SID\>)', '<SNR>'.id.'_')
  else
    return a:arg
  endif
endfunction

function! s:break(type, arg) abort
  if a:arg ==# 'here' || a:arg ==# ''
    let lnum = searchpair('^\s*fu\%[nction]\>.*(', '', '^\s*endf\%[unction]\>', 'Wbn')
    if lnum && lnum < line('.')
      let function = matchstr(getline(lnum), '^\s*\w\+!\=\s*\zs[^( ]*')
      if function =~# '^s:\|^<SID>'
        let id = scriptease#scriptid('%')
        if id
          let function = s:sub(function, '^s:|^\<SID\>', '<SNR>'.id.'_')
        else
          return 'echoerr "Could not determine script id"'
        endif
      endif
      if function =~# '\.'
        return 'echoerr "Dictionary functions not supported"'
      endif
      return 'break'.a:type.' func '.(line('.')==lnum ? '' : line('.')-lnum).' '.function
    else
      return 'break'.a:type.' here'
    endif
  endif
  return 'break'.a:type.' '.s:breaksnr(a:arg)
endfunction

function! s:Complete_breakadd(A, L, P)
  let functions = join(sort(map(split(scriptease#capture('function'), "\n"), 'matchstr(v:val, " \\zs[^(]*")')), "\n")
  if a:L =~# '^\w\+\s\+\w*$'
    return "here\nfile\nfunc"
  elseif a:L =~# '^\w\+\s\+func\s*\d*\s\+s:'
    let id = scriptease#scriptid('%')
    return s:gsub(functions,'\<SNR\>'.id.'_', 's:')
  elseif a:L =~# '^\w\+\s\+func '
    return functions
  elseif a:L =~# '^\w\+\s\+file '
    return glob(a:A."*")
  else
    return ''
  endif
endfunction

function! s:Complete_breakdel(A, L, P)
  let args = matchstr(a:L, '\s\zs\S.*')
  let list = split(scriptease#capture('breaklist'), "\n")
  call map(list, 's:sub(v:val, ''^\s*\d+\s*(\w+) (.*)  line (\d+)$'', ''\1 \3 \2'')')
  if a:L =~# '^\w\+\s\+\w*$'
    return "*\nhere\nfile\nfunc"
  elseif a:L =~# '^\w\+\s\+func\s'
    return join(map(filter(list, 'v:val =~# "^func"'), 'v:val[5 : -1]'), "\n")
  elseif a:L =~# '^\w\+\s\+file\s'
    return join(map(filter(list, 'v:val =~# "^file"'), 'v:val[5 : -1]'), "\n")
  else
    return ''
  endif
endfunction

" }}}1
" :Vopen, :Vedit, ... {{{1

function! s:previewwindow()
  for i in range(1, winnr('$'))
    if getwinvar(i, '&previewwindow') == 1
      return i
    endif
  endfor
  return -1
endfunction

function! s:runtime_globpath(file)
  return split(globpath(escape(&runtimepath, ' '), a:file), "\n")
endfunction

function! s:find(count,cmd,file,lcd)
  let found = s:runtime_globpath(a:file)
  let file = get(found, a:count - 1, '')
  if file ==# ''
    return "echoerr 'E345: Can''t find file \"".a:file."\" in runtimepath'"
  elseif a:cmd ==# 'read'
    return a:cmd.' '.s:fnameescape(file)
  elseif a:lcd
    let path = file[0:-strlen(a:file)-2]
    return a:cmd.' '.s:fnameescape(file) . '|lcd '.s:fnameescape(path)
  else
    let window = 0
    let precmd = ''
    let postcmd = ''
    if a:cmd =~# '^pedit'
      try
        exe 'silent ' . a:cmd
      catch /^Vim\%((\a\+)\)\=:E32/
      endtry
      let window = s:previewwindow()
      let precmd = printf('%d wincmd w|', window)
      let postcmd = '|wincmd w'
    elseif a:cmd !~# '^edit'
      exe a:cmd
    endif
    call setloclist(window, map(found,
          \ '{"filename": v:val, "text": v:val[0 : -len(a:file)-2]}'))
    return precmd . 'll'.matchstr(a:cmd, '!$').' '.a:count . postcmd
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
      \ :execute s:find(<count>,'pedit<bang>',<q-args>,0)
command! -bar -bang -range=1 -nargs=1 -complete=customlist,s:Complete Vread
      \ :execute s:find(<count>,'read',<q-args>,<bang>0)

" }}}1
" :Time {{{1

command! -count=1 -nargs=? -complete=command Time :exe s:time(<q-args>, <count>)

function! s:time(cmd, count)
  let time = reltime()
  try
    if a:count > 1
      let i = 0
      while i < a:count
        execute a:cmd
        let i += 1
      endwhile
    else
      execute a:cmd
    endif
  finally
    redraw
    echomsg matchstr(reltimestr(reltime(time)), '.*\..\{,3\}') . ' seconds to run :'.a:cmd
  endtry
  return ''
endfunction

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
  autocmd FileType vim nnoremap <silent><buffer> K :exe 'help '.<SID>helptopic()<CR>
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
  elseif syn ==# 'vimUserAttrbKey'
    return ':command-'.cword
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
  setlocal suffixesadd=.vim keywordprg=:help
  let b:dispatch = ':Runtime'
  command! -bar -bang -buffer Console Runtime|PP
endfunction

augroup scriptease
  autocmd!
  autocmd FileType vim,help let &l:path = escape(&runtimepath, ' ')
  autocmd FileType help command! -bar -bang -buffer Console PP
  autocmd FileType vim call s:setup()
  " Recent versions of vim.vim set iskeyword to include ":", which breaks among
  " other things tags. :(
  autocmd FileType vim setlocal iskeyword-=:
  autocmd Syntax vim setlocal iskeyword-=:
augroup END

" }}}1
" Projectionist {{{1

function! s:projectionist_detect() abort
  let file = get(g:, 'projectionist_file', '')
  let path = s:sub(s:findinrtp(file)[0], '[\/]after$', '')
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

" }}}1

" vim:set et sw=2:
