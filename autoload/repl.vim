"y REPL plugin to interact with interpreters for various programming languages
" Author: Sergey Khorev <sergey.khorev@gmail.com>
" Last Change:	$HGLastChangedDate: 2012-12-22 07:47 +0400 $

let s:ReplFullyInitialized = 0

function! s:ReplInit2()
  if s:ReplFullyInitialized
    return
  endif
  try
    call vimproc#version()
  catch
    echoerr 'Error running vimproc:' v:exception '. Please check it has been built and installed'
    return
  endtry

  let s:ReplFullyInitialized = 1
  augroup REPL
    " TODO setup more autocommand for async updates, CursorMoved?
    autocmd CursorHold,InsertLeave * call <SID>ReadFromRepl()
  augroup END

  vnoremap <silent> <Plug>EvalSelection :call repl#SendText('', repl#GetSelection())<cr>
  nnoremap <silent> <Plug>EvalLine :call repl#SendText('', getline('.'))<cr>

  if !hasmapto('<Plug>EvalSelection')
    vmap <unique> <silent> <Leader>e <Plug>EvalSelection
  endif
  if !hasmapto('<Plug>EvalLine')
    nmap <unique> <silent> <Leader>e <Plug>EvalLine
  endif
endfunction

function! s:SetupBuffer()
  setlocal bufhidden=hide buftype=nofile noswapfile
  "setlocal nobuflisted
  exec 'silent file' bufnr('').b:replinfo.type
  setlocal filetype=repl

  nmap <buffer> <silent> <Return> :call <SID>Execute()<cr>
  nmap <buffer> <silent> <C-J> :call <SID>CopyCurrent()<cr>
  " start of the current or prev command
  nmap <buffer> <silent> [[ :<C-U>call <SID>EndOfCurrOrPrevPromptMap()<cr>
  " start of the next command
  nmap <buffer> <silent> ]] :<C-U>call <SID>EndOfNextPromptMap()<cr>
  " end of prev command
  nmap <buffer> <silent> [] :<C-U>call <SID>GoToEndOfPrevCommandMap()<cr>
  " end of curr or next command
  nmap <buffer> <silent> ][ :<C-U>call <SID>GoToEndOfNextOrCurrentCommandMap()<cr>

  nmap <buffer> <silent> <C-K> []<C-J>]]

  command! -bang -buffer CloseRepl
    \ :call <SID>CloseRepl(bufnr(''), '<bang>' == '!')
  command! -bang -buffer -nargs=1 -complete=file SaveInput
    \ :call <SID>SaveInput(<f-args>, '<bang>' == '!')

  "autocmd BufDelete,BufWipeout <buffer> :call CloseRepl(expand('<abuf>'))
endfunction

function! s:SaveInput(fname, force)
  if filereadable(a:fname) " file exists
    if !filewritable(a:fname)
      echoerr 'File' a:fname 'is not writable'
      return
    elseif filewritable(a:fname) == 1 && !a:force
      echoerr 'Use ! to overwrite' a:fname
      return
    endif
  endif
  let l:save = getpos('.')[1:2]
  let l:prev = [1, 1]
  call cursor(l:prev)
  let l:text = []
  while 1
    let l:pos = s:StartOfNextPrompt(1)
    if l:pos == l:prev || l:pos == [0, 0]
      break
    endif
    let l:prev = l:pos
    let l:lp = s:GetCurrentLinesAndPos()
    if !empty(l:lp)
      call add(l:text, join(l:lp.lines, b:replinfo.join))
    endif
  endwhile
  call writefile(l:text, a:fname)
  call cursor(l:save)
endfunction

" NAVIGATION
function! s:EndOfCurrOrPrevPrompt(move)
  let l:pos = getpos('.')[1:2]
  let l:curr = s:EndOfCurrPrompt(a:move)
  if l:curr[0] == l:pos[0] && l:curr[1] >= l:pos[1] " cursor is still in prompt area
    " match only above current prompt
    let l:pos = searchpos(b:replinfo.prompt.'\m\%<'.(l:curr[0]-1).'l\s*\zs',
      \ (a:move ? '' : 'n').'bcW')
  endif
  return l:pos
endfunction

function! s:EndOfCurrPrompt(move)
  let l:pos = match(getline('.'), b:replinfo.prompt.'\m\s*\zs')
  if l:pos > -1
    let l:result = [line('.'), l:pos + 1]
    if a:move
      call cursor(l:result[0], l:result[1])
    endif
    return l:result
  endif
  return searchpos(b:replinfo.prompt.'\m\s*\zs', (a:move ? '' : 'n').'bcW')
endfunction

function! s:StartOfNextPrompt(move)
  return searchpos(b:replinfo.prompt, (a:move ? '' : 'n').'W')
endfunction

function! s:EndOfNextPrompt(move)
  return searchpos(b:replinfo.prompt.'\m\s*\zs', (a:move ? '' : 'n').'W')
endfunction

function! s:GoToEndOfNextOrCurrentCommand()
  let l:pos = searchpos('\m^'.b:replinfo.outmarker, 'nW')
  if !l:pos[0]
    let l:line = line('$')
  else
    let l:line = l:pos[0] - 1
  endif
  call cursor(l:line, len(getline(l:line)))
endfunction

function! s:GoToEndOfPrevCommand()
  let l:curr = s:EndOfCurrPrompt(0)
  " match only above current prompt
  let l:pos = searchpos(b:replinfo.prompt.'\m\%<'.(l:curr[0]-1).'l\s*\zs', 'bcW')
  if l:pos != [0, 0]
    call s:GoToEndOfNextOrCurrentCommand()
  endif
endfunction

function! s:StartOfNextPromptOrOutput(move)
  let l:pos = searchpos('\m'.b:replinfo.prompt.'\m\|^'
    \ .b:replinfo.outmarker, (a:move ? '' : 'n').'W')
  return l:pos
endfunction

function! s:EndOfCurrOrPrevPromptMap()
  for i in range(v:count1)
    call s:EndOfCurrOrPrevPrompt(1)
  endfor
endfunction

function! s:EndOfNextPromptMap()
  for i in range(v:count1)
    call s:EndOfNextPrompt(1)
  endfor
endfunction

function! s:GoToEndOfPrevCommandMap()
  for i in range(v:count1)
    call s:GoToEndOfPrevCommand()
  endfor
endfunction

function! s:GoToEndOfNextOrCurrentCommandMap()
  for i in range(v:count1)
    call s:GoToEndOfNextOrCurrentCommand()
  endfor
endfunction

function! s:GetCurrentLinesAndPos()
  if match(getline('.'), b:replinfo.prompt.'\m\s*$') > -1 " empty input line
    return {}
  endif
  let l:start = s:EndOfCurrPrompt(1)
  let l:end = s:StartOfNextPromptOrOutput(0)
  if l:end == [0, 0]
    let l:end = [line('$'), len(getline('$'))]
  else
    let l:end[0] -= 1
  endif
  let l:result = {'line1' : l:start[0], 'line2' : l:end[0], 'lines' : []}
  if l:start != [0, 0]
    let l:lines = getline(l:start[0], l:end[0])
    let l:lines[0] = l:lines[0][l:start[1] - 1 : ] "column index is 1-based
    let l:result.lines = l:lines
  endif
  return l:result
endfunction

function! s:Execute()
  let l:current = s:GetCurrentLinesAndPos()
  if empty(l:current)
    return
  endif
  if !empty(l:current.lines)
    let b:replinfo.curpos = l:current.line2
    let l:next = s:StartOfNextPrompt(0)
    if l:next != [0, 0]
      " delete previous output
      let l:from = l:current.line2 + 1
      let l:to = l:next[0] - 1
      exec 'silent' l:from ','  l:to 'delete _'
    endif
    call s:SendToRepl(join(l:current.lines, b:replinfo.join), 0, 0, bufnr(''))
  endif
endfunction

function! s:CopyCurrent()
  let l:current = s:GetCurrentLinesAndPos()
  if empty(l:current)
    return
  endif
  let l:lines = l:current.lines
  if l:current.line2 < line('$') && !empty(l:lines)
    let l:lines[0] = getline('$') . l:lines[0]
    call setline(line('$'), l:lines)
    call cursor(line('$'), len(getline('$')))
  endif
endfunction

let s:replbufs = {}

function! s:IsBufferValid(buf)
  if bufexists(a:buf)
    let l:info = getbufvar(a:buf, 'replinfo')
    return !empty(l:info) && l:info.proc.is_valid
          \ && !l:info.proc.stdin.eof && !l:info.proc.stdout.eof
  endif
  return 0
endfunction

function! s:CleanupDeadBuffers()
  for l:t in keys(s:replbufs)
    call filter(s:replbufs[l:t], 's:IsBufferValid(v:val)')
  endfor
  call filter(s:replbufs, '!empty(v:val)')
endfunction

function! s:FindReplBufferWithType(type)
  call s:CleanupDeadBuffers()
  let l:b = 0
  if exists('b:replbuf') && bufexists(b:replbuf)
      \&& getbufvar(b:replbuf, 'replinfo').type == a:type
    let l:b = b:replbuf
  " check other buffers on the same tab first?
  elseif exists('s:replbufs["'.a:type.'"]')
    let l:b = s:replbufs[a:type][0]
  endif
  return l:b
endfunction " FindReplBufferWithType

function! s:NewReplBuffer(args, type)
  call s:CleanupDeadBuffers()
  " populate REPL info using default entry as a prototype
  let l:replinfo = deepcopy(g:ReplDefaults)
  call extend(l:replinfo, g:ReplTypes[a:type], 'force')
  call extend(l:replinfo, {'curpos': 1, 'markerpending': 0, 'echo': [], 'type': a:type})

  try
    let l:replinfo.proc = vimproc#popen2(l:replinfo.command . ' ' . a:args)
  catch
    echohl ErrorMsg | echomsg "Error creating process:" v:exception | echohl None
    " rethrow?
    return 0
  endtry

  exec l:replinfo.split 'new'
  let b:replinfo = l:replinfo

  let l:buf = bufnr('')
  call s:SendToRepl(b:replinfo.init, 0, 0, l:buf)

  if exists('s:replbufs["'.a:type.'"]')
    let l:bufs = s:replbufs[a:type]
  else
    let l:bufs = []
  endif
  call add(l:bufs, l:buf)
  let s:replbufs[a:type] = l:bufs

  call s:SetupBuffer()

  wincmd W
  return l:buf
endfunction " NewReplBuffer

function! s:CloseRepl(buffer, wipe)
  let l:info = getbufvar(a:buffer, 'replinfo')
  if l:info.proc.is_valid
    call l:info.proc.kill(15)
  endif
  if a:wipe
    exec a:buffer 'bwipe'
  endif
  call s:CleanupDeadBuffers()
endfunction

function! repl#OpenRepl(args, type, new)
  call s:ReplInit2()
  if a:new
    let l:b = 0
  else
    let l:b = s:FindReplBufferWithType(a:type)
    if l:b > 0 && bufwinnr(l:b) == -1 " window not visible
      exec getbufvar(l:b, 'replinfo').split 'sbuffer' l:b
      wincmd W
    endif
  endif
  if !l:b
    let l:b = s:NewReplBuffer(a:args, a:type)
  endif
  if l:b > 0
    let b:replbuf = l:b
  endif
endfunction " OpenRepl

function! s:IsBufferWindowVisible(buf)
  let l:src = bufwinnr('')
  let l:win = bufwinnr(a:buf)
  let l:result = 0
  if l:win > -1
    try
      " check if we are able to switch to the buffer window and back
      exec l:win 'wincmd w'
      exec l:src 'wincmd w'
      let l:result = 1
    catch
      let l:result = 0
    endtry
  endif
  return l:result
endfunction

function! s:ReadFromRepl()
  for l:t in keys(s:replbufs)
    for l:b in s:replbufs[l:t]
      if s:IsBufferValid(l:b) && s:IsBufferWindowVisible(l:b)
        let l:info = getbufvar(l:b, 'replinfo')
        let l:proc = l:info.proc
        let l:text = l:proc.stdout.read()
        call s:WriteToBuffer(l:b, l:text)
      endif
    endfor
  endfor
endfunction

" Manipulate text to imitate command line experience
function! s:EnrichText(text)
  let l:prompt = b:replinfo.prompt
  if b:replinfo.markerpending
    if !empty(b:replinfo.echo)
      let l:echo = remove(b:replinfo.echo, 0)
    else
      let l:echo = ''
    endif
    call extend(a:text, [l:echo, b:replinfo.outmarker], 0)
    let b:replinfo.markerpending = 0
  endif
  let l:promptPos = match(a:text, l:prompt)
  let a:text[0] = getline(b:replinfo.curpos) . a:text[0]
  while l:promptPos > -1
    let l:line = a:text[l:promptPos]
    let l:promptEnd = match(l:line, l:prompt . '\m\zs')
    if !empty(b:replinfo.echo)
      let l:echo = remove(b:replinfo.echo, 0)
    else
      let l:echo = ''
    endif
    let a:text[l:promptPos] = l:line[: l:promptEnd] . l:echo
    if l:promptPos == len(a:text) - 1
      let b:replinfo.markerpending = 1
    else " more text after the prompt
      call extend(a:text,
            \ [b:replinfo.outmarker, strpart(l:line, l:promptEnd+1)],
            \ l:promptPos+1)
    endif
    let l:promptPos = match(a:text, l:prompt, l:promptPos + 1)
  endwhile
endfunction

function! s:WriteToBuffer(buf, text)
  if empty(a:text)
    return
  endif

  let l:src = bufwinnr('')
  exec bufwinnr(a:buf) 'wincmd w'
  let l:text = split(a:text, '\m[\r]\?\n', 1)
  if b:replinfo.curpos < 1
    let b:replinfo.curpos = line('$')
  endif

  call s:EnrichText(l:text)
  call setline(b:replinfo.curpos, l:text[0])
  call append(b:replinfo.curpos, l:text[1:])

  let b:replinfo.curpos += len(l:text) - 1
  if b:replinfo.scroll
    call cursor(b:replinfo.curpos, len(getline(b:replinfo.curpos)))
  endif

  " if the last output line is our prompt
  if b:replinfo.markerpending && b:replinfo.curpos < line('$')
    " delete the prompt if the line is not the last one
    exec 'silent' b:replinfo.curpos 'delete _'
    call s:EndOfCurrOrPrevPrompt(1) " return to the command
    call s:GoToEndOfNextOrCurrentCommand()
  endif
  exec l:src 'wincmd w'
endfunction "WriteToBuffer

function! s:FindReplBuffer(bufOrType)
  if type(a:bufOrType) == type(0)
    return a:bufOrType
  elseif !empty(a:bufOrType)
    return s:FindReplBufferWithType(a:bufOrType)
  endif
  let l:b = 0
  if exists('b:replinfo')
    let l:b = bufnr('')
  elseif exists('b:replbuf')
    let l:b = b:replbuf
  else " try to find some REPL buffer
    let l:b = 0
    for l:t in keys(s:replbufs)
      for l:bf in s:replbufs[l:t]
        if bufexists(l:bf)
          let l:b = l:bf
          break
        endif
      endfor
      if l:b > 0
        break
      endif
    endfor
  endif
  return l:b
endfunction " FindReplBuffer

function! s:SendToRepl(text, echo, append, bufOrType)
  call s:CleanupDeadBuffers()
  if empty(a:text)
    return
  endif
  let l:b = s:FindReplBuffer(a:bufOrType)
  if !s:IsBufferValid(l:b)
    echoerr 'REPL is not connected'
    return
  endif
  let l:info = getbufvar(l:b, 'replinfo')
  if type(a:text) == type('')
    let l:text = a:text
  elseif type(a:text) == type([])
    let l:text = join(a:text, l:info.join)
  else
    let l:text = string(a:text)
  endif
  if a:echo
    call add(l:info.echo, l:text)
  endif
  let l:proc = l:info.proc
  if l:proc.is_valid && !l:proc.stdin.eof
    if a:append
      let l:info.curpos = -1
    endif
    return l:proc.stdin.write(l:text) + l:proc.stdin.write("\n")
  endif
endfunction " SendToRepl

function! repl#GetSelection()
  let l:savereg = ['r', getreg('r'), getregtype('r')]
  normal! gv"ry
  let l:text = split(getreg('r'), '\n')
  call call('setreg', l:savereg)
  return l:text
endfunction

function! repl#SendText(bufOrType, text) range
  call s:SendToRepl(a:text, 1, 1, a:bufOrType)
endfunction

" vim: set ts=8 sw=2 sts=2 et:
