" `repl` plugin: syntax highlightling for REPL buffer
" Author: Sergey Khorev <sergey.khorev@gmail.com>
" Last Change:	$HGLastChangedDate$

if exists('b:current_syntax')
  finish
endif

if !empty(b:replinfo.syntax)
  exec 'syn include @replNested syntax/'.b:replinfo.syntax.'.vim'
  unlet b:current_syntax
endif

" folding?
exec 'syn region replLine matchgroup=replPrompt start=!'.b:replinfo.prompt.
  \'! end=!^'.b:replinfo.outmarker.'$\|'.b:replinfo.prompt.'$!me=s-1 contains=@replNested'
exec 'syn match replOutputMarker !^'.b:replinfo.outmarker.'$!'

hi def link replPrompt Question
hi def link replOutputMarker Title

let b:current_syntax = 'repl'

" vim: set ts=8 sts=2 sw=2:
