" Completion {{{1

function! scriptease#complete(A,L,P)
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

function! scriptease#complete_breakadd(A, L, P)
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

function! scriptease#complete_breakdel(A, L, P)
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
