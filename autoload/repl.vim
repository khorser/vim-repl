"y REPL plugin to interact with interpreters for various programming languages
" Author: Sergey Khorev <sergey.khorev@gmail.com>
" Last Change:	$HGLastChangedDate$

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
  let save = getpos('.')[1:2]
  let prev = [1, 1]
  call cursor(prev)
  let text = []
  while 1
    let pos = s:StartOfNextPrompt(1)
    if pos == prev || pos == [0, 0]
      break
    endif
    let prev = pos
    let lp = s:GetCurrentLinesAndPos()
    if !empty(lp)
      if b:replinfo.join != "\n"
        call add(text, join(lp.lines, b:replinfo.join))
      else
        call extend(text, lp.lines, len(text))
      endif
    endif
  endwhile
  call writefile(text, a:fname)
  call cursor(save)
endfunction

" NAVIGATION
function! s:EndOfCurrOrPrevPrompt(move)
  let pos = getpos('.')[1:2]
  let curr = s:EndOfCurrPrompt(a:move)
  if curr[0] == pos[0] && curr[1] >= pos[1] " cursor is still in prompt area
    " match only above current prompt
    let pos = searchpos(b:replinfo.prompt.'\m\%<'.(curr[0]-1).'l\s*\zs',
      \ (a:move ? '' : 'n').'bcW')
  endif
  return pos
endfunction

function! s:EndOfCurrPrompt(move)
  let pos = match(getline('.'), b:replinfo.prompt.'\m\s*\zs')
  if pos > -1
    let result = [line('.'), pos + 1]
    if a:move
      call cursor(result[0], result[1])
    endif
    return result
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
  let pos = searchpos('\m^'.b:replinfo.outmarker, 'nW')
  if !pos[0]
    let line = line('$')
  else
    let line = pos[0] - 1
  endif
  call cursor(line, len(getline(line)))
endfunction

function! s:GoToEndOfPrevCommand()
  let curr = s:EndOfCurrPrompt(0)
  " match only above current prompt
  let pos = searchpos(b:replinfo.prompt.'\m\%<'.(curr[0]-1).'l\s*\zs', 'bcW')
  if pos != [0, 0]
    call s:GoToEndOfNextOrCurrentCommand()
  endif
endfunction

function! s:StartOfNextPromptOrOutput(move)
  let pos = searchpos('\m'.b:replinfo.prompt.'\m\|^'
    \ .b:replinfo.outmarker, (a:move ? '' : 'n').'W')
  return pos
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
  let start = s:EndOfCurrPrompt(1)
  let end = s:StartOfNextPromptOrOutput(0)
  if end == [0, 0]
    let end = [line('$'), len(getline('$'))]
  else
    let end[0] -= 1
  endif
  let result = {'line1' : start[0], 'line2' : end[0], 'lines' : []}
  if start != [0, 0]
    let lines = getline(start[0], end[0])
    let lines[0] = lines[0][start[1] - 1 : ] "column index is 1-based
    let result.lines = lines
  endif
  return result
endfunction

function! s:Execute()
  let current = s:GetCurrentLinesAndPos()
  if empty(current)
    return
  endif
  if !empty(current.lines)
    let b:replinfo.curpos = current.line2
    let next = s:StartOfNextPrompt(0)
    if next != [0, 0]
      " delete previous output
      let from = current.line2 + 1
      let to = next[0] - 1
      exec 'silent' from ','  to 'delete _'
    endif
    call s:SendToRepl(current.lines, 0, 0, 1, bufnr(''))
  endif
endfunction

function! s:CopyCurrent()
  let current = s:GetCurrentLinesAndPos()
  if empty(current)
    return
  endif
  let lines = current.lines
  if current.line2 < line('$') && !empty(lines)
    let lines[0] = getline('$') . lines[0]
    call setline(line('$'), lines)
    call cursor(line('$'), len(getline('$')))
  endif
endfunction

let s:replbufs = {}

function! s:IsBufferValid(buf)
  if bufexists(a:buf)
    let info = getbufvar(a:buf, 'replinfo')
    return !empty(info) && info.proc.is_valid
          \ && !info.proc.stdin.eof && !info.proc.stdout.eof
  endif
  return 0
endfunction

function! s:CleanupDeadBuffers()
  for t in keys(s:replbufs)
    call filter(s:replbufs[t], 's:IsBufferValid(v:val)')
  endfor
  call filter(s:replbufs, '!empty(v:val)')
endfunction

function! s:FindReplBufferWithType(type)
  call s:CleanupDeadBuffers()
  let b = 0
  if exists('b:replbuf') && bufexists(b:replbuf)
      \&& getbufvar(b:replbuf, 'replinfo').type == a:type
    let b = b:replbuf
  " check other buffers on the same tab first?
  elseif exists('s:replbufs["'.a:type.'"]')
    let b = s:replbufs[a:type][0]
  endif
  return b
endfunction " FindReplBufferWithType

function! s:NewReplBuffer(args, type)
  call s:CleanupDeadBuffers()
  " populate REPL info using default entry as a prototype
  let replinfo = deepcopy(g:ReplDefaults)
  call extend(replinfo, g:ReplTypes[a:type], 'force')
  call extend(replinfo,
    \ {'curpos'     : 1,
    \'markerpending': 0,
    \'echo'         : [],
    \'type'         : a:type,
    \'promptspending' : 1})

  try
    let replinfo.proc = vimproc#popen2(replinfo.command . ' ' . a:args)
  catch
    echohl ErrorMsg | echomsg "Error creating process:" v:exception | echohl None
    " rethrow?
    return 0
  endtry

  exec replinfo.split 'new'
  let b:replinfo = replinfo

  let buf = bufnr('')
  call s:SendToRepl(b:replinfo.init, 0, 0, 0, buf)

  if exists('s:replbufs["'.a:type.'"]')
    let bufs = s:replbufs[a:type]
  else
    let bufs = []
  endif
  call add(bufs, buf)
  let s:replbufs[a:type] = bufs

  call s:SetupBuffer()

  wincmd W
  return buf
endfunction " NewReplBuffer

function! s:CloseRepl(buffer, wipe)
  let info = getbufvar(a:buffer, 'replinfo')
  if info.proc.is_valid
    call info.proc.kill(15)
  endif
  if a:wipe
    exec a:buffer 'bwipe'
  endif
  call s:CleanupDeadBuffers()
endfunction

function! repl#OpenRepl(args, type, new)
  call s:ReplInit2()
  if a:new
    let b = 0
  else
    let b = s:FindReplBufferWithType(a:type)
    if b > 0 && bufwinnr(b) == -1 " window not visible
      exec getbufvar(b, 'replinfo').split 'sbuffer' b
      wincmd W
    endif
  endif
  if !b
    let b = s:NewReplBuffer(a:args, a:type)
  endif
  if b > 0
    let b:replbuf = b
  endif
endfunction " OpenRepl

function! s:IsBufferWindowVisible(buf)
  let src = bufwinnr('')
  let win = bufwinnr(a:buf)
  let result = 0
  if win > -1
    try
      " check if we are able to switch to the buffer window and back
      exec win 'wincmd w'
      exec src 'wincmd w'
      let result = 1
    catch
      let result = 0
    endtry
  endif
  return result
endfunction

function! s:ReadFromRepl()
  for t in keys(s:replbufs)
    for b in s:replbufs[t]
      if s:IsBufferValid(b) && s:IsBufferWindowVisible(b)
        let info = getbufvar(b, 'replinfo')
        let proc = info.proc
        let text = proc.stdout.read()
        call s:WriteToBuffer(b, text)
      endif
    endfor
  endfor
endfunction

function! s:GetEcho()
  if empty(b:replinfo.echo)
    return ['']
  elseif !b:replinfo.condensedout
    return [remove(b:replinfo.echo, 0)]
  else
    let echo = b:replinfo.echo
    let b:replinfo.echo = []
    return echo
  endif
endfunction

" Manipulate text to imitate command line experience
function! s:EnrichText(text)
  "echom string(a:text)
  let prompt = b:replinfo.prompt
  if b:replinfo.markerpending
    call extend(a:text, add(s:GetEcho(), b:replinfo.outmarker), 0)
    let b:replinfo.markerpending = 0
  endif
  let promptIdx = match(a:text, prompt)
  let a:text[0] = getline(b:replinfo.curpos) . a:text[0]
  "echom string(a:text)
  while promptIdx > -1
    let line = a:text[promptIdx]
    let promptEnd = match(line, prompt . '\m\zs')
    let echo = s:GetEcho()
    let a:text[promptIdx] = line[: promptEnd] . echo[0]
    let rest = line[promptEnd+1 :] " rest of the output after the prompt
    call extend(a:text, echo[1:], promptIdx+1)
    "echom b:replinfo.promptspending
    if b:replinfo.promptspending > 1 && b:replinfo.condensedout
        \ && echo == ['']
      " suppress spurious prompts and preceeding empty lines
      " assuming the interpreter will print prompt for every
      " input line, otherwise the final prompt might not appear
      if promptIdx > 0 && a:text[promptIdx-1] =~ '\m^\s*$'
        call remove(a:text, promptIdx-1)
        let promptIdx -= 1
      endif
      let a:text[promptIdx] = rest
      let promptIdx -= 1
    else
      if promptIdx == len(a:text)-1
        let b:replinfo.markerpending = 1
      else
        call extend(a:text, [b:replinfo.outmarker, rest], promptIdx+1)
        let promptIdx += 2
      endif
    endif
    let b:replinfo.promptspending -= 1
    let promptIdx = match(a:text, prompt, promptIdx + 1)
  endwhile
endfunction

function! s:WriteToBuffer(buf, text)
  if empty(a:text)
    return
  endif

  let src = bufwinnr('')
  exec bufwinnr(a:buf) 'wincmd w'
  let text = split(a:text, '\m[\r]\?\n', 1)
  if b:replinfo.curpos < 1
    let b:replinfo.curpos = line('$')
  endif

  call s:EnrichText(text)
  call setline(b:replinfo.curpos, text[0])
  call append(b:replinfo.curpos, text[1:])

  let b:replinfo.curpos += len(text) - 1
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
  exec src 'wincmd w'
endfunction "WriteToBuffer

function! s:FindReplBuffer(bufOrType)
  if type(a:bufOrType) == type(0)
    return a:bufOrType
  elseif !empty(a:bufOrType)
    return s:FindReplBufferWithType(a:bufOrType)
  endif
  let b = 0
  if exists('b:replinfo')
    let b = bufnr('')
  elseif exists('b:replbuf')
    let b = b:replbuf
  else " try to find some REPL buffer
    let b = 0
    for t in keys(s:replbufs)
      for bf in s:replbufs[t]
        if bufexists(bf)
          let b = bf
          break
        endif
      endfor
      if b > 0
        break
      endif
    endfor
  endif
  return b
endfunction " FindReplBuffer

function! s:SendToRepl(text, echo, append, user, bufOrType)
  call s:CleanupDeadBuffers()
  if empty(a:text)
    return
  endif

  let b = s:FindReplBuffer(a:bufOrType)
  if !s:IsBufferValid(b)
    echoerr 'REPL is not connected'
    return
  endif
  let info = getbufvar(b, 'replinfo')
  if type(a:text) == type('')
    let text = [a:text]
  elseif type(a:text) == type([])
    if info.join != "\n"
      let text = [join(a:text, info.join)]
    else
      let text = a:text
    endif
  else
    let text = [string(a:text)]
  endif
  if a:echo
    call extend(info.echo, text, len(info.echo))
  endif
  if a:user
    let info.promptspending += len(text)
  endif
  let proc = info.proc
  if proc.is_valid && !proc.stdin.eof
    if a:append
      let info.curpos = -1
    endif
    return map(text, 'proc.stdin.write(v:val) + proc.stdin.write("\n")')
  endif
endfunction " SendToRepl

function! repl#GetSelection()
  let savereg = ['r', getreg('r'), getregtype('r')]
  silent exe 'normal! gv"ry'
  let text = split(getreg('r'), '\n')
  call call('setreg', savereg)
  return text
endfunction

function! repl#SendText(bufOrType, text) range
  call s:SendToRepl(a:text, 1, 1, 1, a:bufOrType)
endfunction

" vim: set ts=8 sw=2 sts=2 et:
