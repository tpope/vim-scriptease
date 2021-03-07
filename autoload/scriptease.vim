" Location:     autoload/scriptease.vim

if exists('g:autoloaded_scriptease') || &cp
  finish
endif
let g:autoloaded_scriptease = 1

" Section: Utility

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

function! s:fcall(fn, path, ...) abort
  let ns = matchstr(a:path, '^\a\a\+\ze:')
  if len(ns) && exists('*' . ns . '#' . a:fn)
    return call(ns . '#' . a:fn, [a:path] + a:000)
  else
    return call(a:fn, [a:path] + a:000)
  endif
endfunction

function! s:glob(pattern) abort
  if v:version >= 704
    return s:fcall('glob', a:pattern, 0, 1)
  else
    return split(s:fcall('glob', a:pattern), "\n")
  endif
endfunction

function! s:globrtp(expr) abort
  if v:version >= 703
    return globpath(escape(&runtimepath, ' '), a:expr, 1)
  else
    return globpath(escape(&runtimepath, ' '), a:expr)
  endif
endfunction

function! s:isdirectory(path) abort
  return s:fcall('isdirectory', a:path)
endfunction

function! s:filereadable(path) abort
  return s:fcall('filereadable', a:path)
endfunction

function! s:readfile(path, ...) abort
  if a:0
    return s:fcall('readfile', a:path, '', a:1)
  else
    return s:fcall('readfile', a:path)
  endif
endfunction

" Section: Completion

function! scriptease#complete(A,L,P) abort
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
    for path in map(s:glob(glob), 'fnamemodify(v:val, ":p")')
      let matches = s:glob(path.sep.pattern)
      call map(matches,'s:isdirectory(v:val) ? v:val.sep : v:val')
      call map(matches,'fnamemodify(v:val, ":p")[strlen(path)+1:-1]')
      for match in matches
        let found[match] = 1
      endfor
    endfor
  endfor
  return sort(keys(found))
endfunction

" Section: :PP, :PPmsg

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
    if a:object =~# "[\001-\037\177']"
      let dump = '"'.s:gsub(a:object, "[\001-\037\177\"\\\\]", '\=get(s:escapes, submatch(0), printf("\\%03o", char2nr(submatch(0))))').'"'
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
    let keys = keys(a:object)
    if type(keys) != type([])
      return "test_null_dict()"
    endif
    call sort(keys)
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
    let dump = s:sub(s:sub(string(a:object), '^function\(''(\d+)''', 'function(''{\1}'''), ',.*\)$', ')')
  else
    let dump = string(a:object)
  endif
  return dump
endfunction

function! s:backslashdump(value, indent) abort
    let out = scriptease#dump(a:value, {'level': 0, 'width': &textwidth - &shiftwidth * 3 - a:indent})
    return s:gsub(out, '\n', "\n".repeat(' ', a:indent + &shiftwidth * 3).'\\')
endfunction

function! scriptease#pp_command(bang, lnum, value) abort
  if v:errmsg !=# '' && a:value is# 0
    return
  elseif a:lnum == -1
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

function! scriptease#ppmsg_command(bang, count, value) abort
  if v:errmsg !=# ''
    return
  elseif &verbose >= a:count
    for line in split(scriptease#dump(a:value, {'width': a:bang ? 0 : &columns-1}), "\n")
      echomsg line
    endfor
  endif
endfunction

" Section: g!

function! s:opfunc(t) abort
  silent exe "norm! `[" . get({'l': 'V', 'b': "\<C-V>"}, a:t[0], 'v') . "`]y"
  redraw
  return @@
endfunction

function! scriptease#filterop(...) abort
  if !a:0
    set opfunc=scriptease#filterop
    return 'g@'
  endif
  let saved = [&selection, &clipboard, @@]
  try
    set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
    let expr = s:opfunc(a:1)
    let @@ = matchstr(expr, '^\_s\+').scriptease#dump(eval(s:gsub(expr,'\n%(\s*\\)=',''))).matchstr(expr, '\_s\+$')
    if @@ !~# '^\n*$'
      normal! gvp
    endif
  catch /^.*/
    echohl ErrorMSG
    echo v:errmsg
    echohl NONE
  finally
    let [&selection, &clipboard, @@] = saved
  endtry
endfunction

" Section: :Verbose

function! scriptease#verbose_command(level, excmd) abort
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

" Section: :Scriptnames

function! scriptease#capture(excmd) abort
  try
    redir => out
    exe 'silent! '.a:excmd
  finally
    redir END
  endtry
  return out
endfunction

function! scriptease#scriptnames_qflist() abort
  let names = scriptease#capture('scriptnames')
  let virtual = get(g:, 'virtual_scriptnames', {})
  let list = []
  for line in split(names, "\n")
    if line =~# ':'
      let filename = expand(matchstr(line, ': \zs.*'))
      call add(list, {'text': matchstr(line, '\d\+'), 'filename': get(virtual, filename, filename)})
    endif
  endfor
  return list
endfunction

function! scriptease#scriptname(file) abort
  if a:file =~# '^\d\+$'
    return get(scriptease#scriptnames_qflist(), a:file-1, {'filename': a:file}).filename
  else
    return a:file
  endif
endfunction

function! scriptease#scriptid(filename) abort
  let filename = fnamemodify(expand(a:filename), ':p')
  for script in scriptease#scriptnames_qflist()
    if script.filename ==# filename
      return +script.text
    endif
  endfor
  return ''
endfunction

" Section: :Messages

function! scriptease#messages_command(bang, count, arg) abort
  let command = (a:count > -1 ? a:count : '') . 'messages'
  if !empty(a:arg)
    return command . ' ' . a:arg
  endif
  let qf = []
  let virtual = get(g:, 'virtual_scriptnames', {})
  for line in split(scriptease#capture(command), '\n\+')
    let lnum = matchstr(line, '\C^line\s\+\zs\d\+\ze:$')
    if lnum && len(qf) && qf[-1].text =~# ':$'
      let qf[-1].text = substitute(qf[-1].text, ':$', '[' . lnum . ']:', '')
    else
      call add(qf, {'text': line})
    endif
    let functions = matchstr(qf[-1].text, '\s\+\zs\S\+\]\ze:$')
    if empty(functions)
      continue
    endif
    let qf[-1].text = substitute(qf[-1].text, '\s\+\S\+:$', '', '')
    for funcline in split(functions, '\.\.')
      call add(qf, {'text': funcline})
      let lnum = matchstr(funcline, '\[\zs\d\+\ze\]$')
      let function = substitute(funcline, '\[\d\+\]$', '', '')
      if function =~# '[\\/.]' && s:filereadable(get(virtual, function, function))
        let qf[-1].filename = get(virtual, function, function)
        let qf[-1].lnum = lnum
        let qf[-1].text = ''
        continue
      elseif function =~# '^\d\+$'
        let function = '{' . function . '}'
      endif
      let list = &list
      try
        set nolist
        let output = split(scriptease#capture('verbose function '.function), "\n")
      finally
        let &list = list
      endtry
      let filename = expand(matchstr(get(output, 1, ''), 'from \zs.*'))
      let filename = get(virtual, filename, filename)
      if !s:filereadable(filename)
        continue
      endif
      let implementation = map(output[2:-2], 'v:val[len(matchstr(output[-1],"^ *")) : -1]')
      call map(implementation, 'v:val ==# " " ? "" : v:val')
      let body = []
      let offset = 0
      for line in s:readfile(filename)
        if line =~# '^\s*\\' && !empty(body)
          let body[-1][0] .= s:sub(line, '^\s*\\', '')
          let offset += 1
        else
          call extend(body, [[s:gsub(line, "\t", repeat(" ", &tabstop)), offset]])
        endif
      endfor
      for j in range(len(body)-len(implementation)-2)
        if function =~# '^{'
          let pattern = '.*\.'
        elseif function =~# '^<SNR>'
          let pattern = '\%(s:\|<SID>\)' . matchstr(function, '_\zs.*') . '\>'
        else
          let pattern = function . '\>'
        endif
        if body[j][0] =~# '\C^\s*fu\%[nction]!\=\s*'.pattern
              \ && (body[j + len(implementation) + 1][0] =~# '\C^\s*endf'
              \ && map(body[j+1 : j+len(implementation)], 'v:val[0]') ==# implementation
              \ || pattern !~# '\*')
          let qf[-1].filename = filename
          let qf[-1].lnum = j + body[j][1] + lnum + 1
          let qf[-1].valid = 1
          let found = 1
          break
        endif
      endfor
    endfor
  endfor
  call setqflist(qf)
  if exists(':chistory')
    call setqflist([], 'r', {'title': ':Messages'})
  endif
  copen
  $
  call search('^[^|]', 'bWc')
  return ''
endfunction

" Section: :Runtime

function! s:unlet_for(files) abort
  let guards = []
  for file in a:files
    if s:filereadable(file)
      let lines = s:readfile(file, 500)
      if len(lines)
        for i in range(len(lines)-1)
          let unlet = matchstr(lines[i], '^if .*\<exists *( *[''"]\%(\g:\)\=\zs[A-Za-z][0-9A-Za-z_#]*\ze[''"]')
          if unlet !=# '' && index(guards, unlet) == -1
            for j in range(0, 4)
              if get(lines, i+j, '') =~# '^\s*finish\>'
                call extend(guards, [unlet])
                break
              endif
            endfor
          endif
        endfor
      endif
    endif
  endfor
  if empty(guards)
    return ''
  else
    return 'unlet! '.join(map(guards, '"g:".v:val'), ' ')
  endif
endfunction

function! s:lencompare(a, b) abort
  return len(a:a) - len(a:b)
endfunction

function! scriptease#locate(path) abort
  let path = fnamemodify(a:path, ':p')
  let candidates = []
  for glob in split(&runtimepath, ',')
    let candidates += filter(s:glob(glob), 'path[0 : len(v:val)-1] ==# v:val && path[len(v:val)] =~# "[\\/]"')
  endfor
  if empty(candidates)
    return ['', '']
  endif
  let preferred = sort(candidates, s:function('s:lencompare'))[-1]
  return [preferred, path[strlen(preferred)+1 : -1]]
endfunction

function! scriptease#runtime_command(bang, ...) abort
  let unlets = []
  let do = []
  let predo = ''

  if a:0
    let files = a:000
  elseif &filetype ==# 'vim' || expand('%:e') ==# 'vim'
    let files = [scriptease#locate(expand('%:p'))[1]]
    if empty(files[0])
      let files = ['%']
    endif
    if &modified && (&autowrite || &autowriteall)
      let predo = 'silent wall|'
    endif
  else
    for ft in split(&filetype, '\.')
      for pattern in ['ftplugin/%s.vim', 'ftplugin/%s_*.vim', 'ftplugin/%s/*.vim', 'indent/%s.vim', 'syntax/%s.vim', 'syntax/%s/*.vim']
        call extend(unlets, split(s:globrtp(printf(pattern, ft)), "\n"))
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
    if request =~# '^\.\=[\\/]\|^\a\+:\|^[%#~]\|^\d\+$'
      let request = scriptease#scriptname(request)
      let unlets += request =~# '[[*?{]' ? s:glob(request) : [expand(request)]
      let do += map(copy(unlets), '"source ".escape(v:val, " \t|!")')
    else
      if get(do, 0, [''])[0] !~# '^runtime!'
        let do += ['runtime!']
      endif
      let unlets += split(s:globrtp(request), "\n")
      let do[-1] .= ' '.escape(request, " \t|!")
    endif
  endfor
  if empty(a:bang)
    call extend(do, ['filetype detect'])
  endif
  let run = s:unlet_for(unlets)
  if run !=# ''
    let run .= '|'
  endif
  let run .= join(do, '|')
  echo ':'.run
  return predo.run
endfunction

" Section: :Disarm

function! scriptease#disarm(file) abort
  let augroups = filter(s:readfile(a:file), 'v:val =~# "^\\s*aug\\%[roup]\\s"')
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

function! s:disable_maps_and_commands(file, buf) abort
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

function! scriptease#disarm_command(bang, ...) abort
  let files = []
  let unlets = []
  for request in a:000
    if request =~# '^\.\=[\\/]\|^\a\+:\|^[%#~]\|^\d\+$'
      let request = expand(scriptease#scriptname(request))
      if s:isdirectory(request)
        let request .= "/**/*.vim"
      endif
      let files += s:glob(request)
    else
      let files += split(s:globrtp(request), "\n")
    endif
  endfor
  for file in files
    let unlets += [scriptease#disarm(expand(file))]
  endfor
  echo join(files, ' ')
  return join(filter(unlets, 'v:val !=# ""'), '|')
endfunction

" Section: :Breakadd, :Breakdel

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

function! s:Complete_breakadd(A, L, P) abort
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

function! s:Complete_breakdel(A, L, P) abort
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

" Section: :Vopen, :Vedit, ...

function! s:previewwindow() abort
  for i in range(1, winnr('$'))
    if getwinvar(i, '&previewwindow') == 1
      return i
    endif
  endfor
  return -1
endfunction

function! s:runtime_globpath(file) abort
  return split(globpath(escape(&runtimepath, ' '), a:file), "\n")
endfunction

function! scriptease#open_command(count,cmd,file,lcd) abort
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
          \ '{"filename": v:val, "text": v:val[0 : -len(a:file)-2], "valid": 1}'))
    return precmd . 'll'.matchstr(a:cmd, '!$').' '.a:count . postcmd
  endif
endfunction

" Section: :Time

function! scriptease#time_command(cmd, count) abort
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

" Section: zS

function! scriptease#synnames(...) abort
  if a:0
    let [line, col] = [a:1, a:2]
  else
    let [line, col] = [line('.'), col('.')]
  endif
  return reverse(map(synstack(line, col), 'synIDattr(v:val,"name")'))
endfunction

function! scriptease#synnames_map(count) abort
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

" Section: K

function! scriptease#helptopic() abort
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

" Section: Settings

function! s:build_path() abort
  let old_path = substitute(&g:path, '\v^\.,/%(usr|emx)/include,,,?', '', '')
  let new_path = escape(&runtimepath, ' ')
  return !empty(old_path) ? old_path.','.new_path : new_path
endfunction

function! scriptease#includeexpr(file) abort
  if a:file =~# '^\.\=[A-Za-z_]\w*\%(#\w\+\)\+$'
    let f = substitute(a:file, '^\.', '', '')
    return 'autoload/'.tr(matchstr(f, '[^.]\+\ze#') . '.vim', '#', '/')
  endif
  return substitute(a:file, '\m\C<sfile>\(\%(:\w\)*\)', '\=expand("%:p".submatch(1))', 'g')
endfunction

function! scriptease#cfile() abort
  if matchend(getline('.'), &include) >= col('.')
    let cfile = matchstr(getline('.'), &include)
  else
    let cfile = expand('<cfile>')
  endif
  if empty(cfile)
    return "\<C-R>\<C-F>"
  elseif cfile =~# '^\.\=[A-Za-z_]\w*\%(#\w\+\)\+$'
    return '+djump\ ' . matchstr(cfile, '[^.]*') . ' ' . s:fnameescape(scriptease#includeexpr(cfile))
  else
    return s:fnameescape(scriptease#includeexpr(cfile))
  endif
endfunction

function! scriptease#setup_vim() abort
  let &l:path = s:build_path()
  setlocal suffixesadd=.vim keywordprg=:help
  setlocal includeexpr=scriptease#includeexpr(v:fname)
  setlocal include=^\\s*\\%(so\\%[urce]\\\|ru\\%[ntime]\\)[!\ ]\ *\\zs[^\\|]*
  setlocal define=^\\s*fu\\%[nction][!\ ]\\s*\\%(s:\\)\\=
  cnoremap <expr><buffer> <Plug><cfile> scriptease#cfile()

  let runtime = scriptease#locate(expand('%:p'))[1]
  let b:dispatch = ':Runtime ' . s:fnameescape(len(runtime) ? runtime : expand('%:p'))
  command! -bar -bang -buffer Console Runtime|PP
  command! -buffer -bar -nargs=? -complete=custom,s:Complete_breakadd Breakadd
        \ :exe s:break('add',<q-args>)
  command! -buffer -bar -nargs=? -complete=custom,s:Complete_breakdel Breakdel
        \ :exe s:break('del',<q-args>)

  nnoremap <silent><buffer> <Plug>ScripteaseHelp :<C-U>exe 'help '.scriptease#helptopic()<CR>
  let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') .
        \ '|setlocal path= suffixesadd= includeexpr= include= define= keywordprg=|sil! delcommand Breakadd|sil! delcommand Breakdel'
  if empty(mapcheck('K', 'n'))
    nmap <silent><buffer> K <Plug>ScripteaseHelp
    let b:undo_ftplugin .= '|sil! exe "nunmap <buffer> K"'
  endif
endfunction

function! scriptease#setup_help() abort
  let &l:path = s:build_path()
  command! -bar -bang -buffer Console PP
endfunction

" vim:set et sw=2:
