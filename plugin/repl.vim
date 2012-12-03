" REPL plugin to interact with interpreters for various programming languages
" Author: Sergey Khorev <sergey.khorev@gmail.com>
" Last Change:	$HGLastChangedDate: 2012-12-03 11:45 +0400 $
"
" Prerequisites: you need to install AND build Vimproc (https://github.com/Shougo/vimproc)
"
" Commands:
" :Open<YourInterpreter> <ExtraArguments> - start session
" e.g.
"  :OpenGHCi to start GHCi 
"  :OpenGHCi! to forcefully start a new session in a new window

" :CloseRepl (local to the repl window) - disconnect REPL
" :CloseRepl! - disconnect and wipeout the buffer
" :SaveInput <filename> - save input lines, use ! to force overwrite
"
" Keybinding:
" global:
"  <Leader>e - in normal mode: send current line to the interpreter
"            - in visual mode: send selection
"
" Local to the REPL window (NORMAL MODE ONLY!)
"  <Return> - send current command to the interpreter
"  <C-J> - copy current command to the command prompt
"  <C-K> - recall previous command to the command prompt
"  <count>[[ - navigate to the start of the current or previous command
"  <count>]] - navigate to the start of the next command
"  <count>[] - go to the end of the previous command
"  <count>][ - go to the end of current or the next command
"
" Keybinding and syntax highlighting heavily use specific markers,
"   you tamper with the markers on your own risk
"
" Hints:
" You may edit and re-execute commands and the plugin should update output
"   using markers
" Also feel free to delete unneeded text, just try to keep the layout
" Session transcript can be saved with "1,$w YourFileName"
"
" Customisation:
" Define g:replUserDefaults and g:replUserTypes
"   using g:ReplDefaults and g:ReplTypes as samples
"   g:replUserDefaults provides default settings for all interpreters
"   g:replUserTypes provides specific overrides
" Feel free to send me settings for your favourite interpreter
"
" Fields:
"   command - command used to start interpreter
"   init    - commands to initialise the interpreter (e.g., set specific prompt)
"   prompt  - regular expression to help REPL identify the prompt
"   split   - split command to create REPL window
"   outmarker - marker to designate start of interpreter output
"   syntax  - Vim syntax highlighting for your interpreted language
"   scroll  - move cursor in the REPL window when new data are received
"   wrap    - not used for now
"   join    - string used to concatenate multiple lines (many interpreters
"               allow only one input line)

if exists('g:loaded_repl')
  finish
endif

let g:loaded_repl = 1

if v:version < 703
  echoerr "REPL: only Vim version 7.3 and newer is supported"
  finish
endif

let g:ReplDefaults = 
      \{'command' : '',
      \ 'init'    : '',
      \ 'prompt'  : '^[^>]*>',
      \ 'split'   : 'belowright vertical',
      \ 'outmarker': 'OUTPUT:',
      \ 'syntax'  : '',
      \ 'scroll'  : 1,
      \ 'wrap'    : 0,
      \ 'join'    : ' '}

let g:ReplTypes =
  \ {
  \  'Bash':
      \{'command' : 'bash -i',
      \ 'init'    : "PS1='\nbash> '",
      \ 'prompt'  : '\m\C^bash>',
      \ 'syntax'  : 'sh'}
  \, 'Chicken':
      \{'command' : 'csi -:c',
      \ 'init'    : '(repl-prompt (lambda () "\n\nchicken> "))',
      \ 'prompt'  : '\m\C^chicken>',
      \ 'syntax'  : 'scheme'}
  \, 'Cmd':
      \{'command' : 'cmd',
      \ 'init'    : 'prompt cmd$G$S',
      \ 'prompt'  : '\m\C^cmd>',
      \ 'syntax'  : 'dosbatch'}
  \, 'GHCi':
      \{'command' : 'ghci',
      \ 'init'    : ':set prompt "\nghci %s> "',
      \ 'prompt'  : '\m\C^ghci [^>]\{-}>',
      \ 'syntax'  : 'haskell'}
  \, 'Hugs':
      \{'command' : 'hugs -98 -p"\nhugs %s> "',
      \ 'init'    : '',
      \ 'prompt'  : '\m\C^hugs [^>]\{-}>',
      \ 'syntax'  : 'haskell'}
  \, 'Maxima':
      \{'command' : 'maxima',
      \ 'init'    : '',
      \ 'prompt'  : '\m\C^(%i\d\+)',
      \ 'syntax'  : 'maxima'}
  \, 'Ocaml':
      \{'command' : 'ocaml',
      \ 'init'    : 'Toploop.read_interactive_input := let old = !Toploop.read_interactive_input in fun prompt buffer len -> old "\nocaml> " buffer len ;;',
      \ 'prompt'  : '\m\C^ocaml>',
      \ 'syntax'  : 'ocaml'}
  \, 'Octave':
      \{'command' : 'octave -i',
      \ 'init'    : 'PS1("\noctave> ")',
      \ 'prompt'  : '\m\C^octave>',
      \ 'syntax'  : 'matlab'}
  \, 'Python':
      \{'command' : 'python -i',
      \ 'init'    : "import sys\nsys.ps1=\"\\npython> \"",
      \ 'prompt'  : '\m\C^python>',
      \ 'split'   : 'belowright',
      \ 'syntax'  : 'python'}
  \, 'R':
      \{'command' : 'R --no-save --ess',
      \ 'init'    : 'options(prompt="\nR> ", continue="")',
      \ 'prompt'  : '\m\C^R>',
      \ 'syntax'  : 'r'}
  \, 'Racket':
      \{'command' : 'racket',
      \ 'init'    : '(let ((c (current-prompt-read))) (current-prompt-read (lambda () (newline) (display "racket") (c))))',
      \ 'prompt'  : '\m\C^racket> ',
      \ 'syntax'  : 'scheme'}
  \, 'Reduce':
      \{'command' : 'reduce -w- -b',
      \ 'init'    : '',
      \ 'prompt'  : '\m\C^\d\+:',
      \ 'syntax'  : ''}
  \, 'Tcsh':
      \{'command' : 'tcsh -i',
      \ 'init'    : "set prompt=\"\\ntcsh> \"\nunset rprompt",
      \ 'prompt'  : '\m\C^tcsh>',
      \ 'syntax'  : 'tcsh'}
  \ }

" Not operational:
"  How can we change nested prompt or disable nested at all?
"  \, 'Guile':
"      \{'command' : 'guile --',
"      \ 'init'   : ',o prompt "\n\nguile> "',
"      \        'prompt'  : '\m\C^guile>',
"      \        'syntax'  : 'scheme'}
"  Need to disable DWIM somehow, also what is the point of using REPL if facts
"  need to be 'consult'ed anyway?
"  \, 'SWIprolog':
"      \{'command' : 'swipl -g "set_prolog_flag(color_term, false),set_stream(user_input, tty(true)),set_stream(user_output, tty(true))"',
"      \ 'init'   : "'$set_prompt'('\nswipl> ').",
"      \        'prompt'  : '\m\C^swipl>',
"      \        'syntax'  : 'prolog'}
"  gprolog - doesn't flush output
"  erl - any use?

function! s:ReplInit()
  if exists('g:replUserDefaults')
    call extend(g:replDefaults, g:replUserDefaults, 'force')
  endif
  if exists('g:replUserTypes')
    call extend(g:replTypes, g:replUserTypes, 'force')
  endif
  for l:t in keys(g:ReplTypes)
    exec 'command! -nargs=* -bang Open'.l:t.
          \     ' call repl#OpenRepl(<q-args>, "'.l:t.'", "<bang>" == "!")'
  endfor
endfunction " ReplInit

call s:ReplInit()
delfunction s:ReplInit

finish

Vimball contents:
plugin/repl.vim
autoload/repl.vim
syntax/repl.vim

" vim: set ts=8 sw=2 sts=2 et:
