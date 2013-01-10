" REPL plugin to interact with interpreters for various programming languages
" Author: Sergey Khorev <sergey.khorev@gmail.com>
" Last Change:	$HGLastChangedDate: 2012-12-30 23:15 +0400 $
" Home Page:  http://www.vim.org/scripts/script.php?script_id=4336
"             https://bitbucket.org/khorser/vim-repl
"             https://github.com/khorser/vim-repl
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
" Functions:
" The following function can be used to define your own mappings or
" autocommands:
" repl#SendText(bufOrType, text)
"   bufOrType: buffer number or its type ('' means currently active buffer)
"   text: a list of strings to join and send to REPL
"   NOTE: the function will not open a REPL window
"
" e.g. to show the type of the expression in the current line in GHCi
"   (in real life you probably would want to use ghc-mod)
"   nmap <leader>t :call repl#SendText('GHCi', [':t', getline('.')])<cr>
"
" show information about visual selection:
"   vmap <leader>i :call repl#SendText('GHCi', insert(repl#GetSelection(), ':i'))<cr>
"
" Hints:
" You may edit and re-execute commands and the plugin should update output
"   using markers
" Also feel free to delete unneeded text, just try to keep the layout
" The full transcript of the session (except deleted lines) can be saved with
"     "1,$w YourFileName"
"
" Autocommands can be used to add settings specific to particular interpreters
" like:
"   autocmd FileType repl :if expand('<afile>')=~#'^\d\+GHCi$' | <setup GHCi mappings> | endif
"
"
" Customisation:
" Define g:ReplUserDefaults and g:ReplUserTypes
"   using g:ReplDefaults and g:ReplTypes as samples
"   g:ReplUserDefaults provides default settings for all interpreters
"   g:ReplUserTypes provides specific overrides
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
"   condensedout  - suppress empty prompts, usually used with join="\n"
"   promptlines   - the number of lines in prompt (2 if the prompt contains
"                     EOL embedded), used with condensetoutput=1

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
      \ 'promptlines' : 2,
      \ 'condensedout' : 0,
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
  \, 'OCaml':
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
      \ 'condensedout' : 1,
      \ 'syntax'  : 'python',
      \ 'join'    : "\n"}
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
  
function! s:ReplInit()
  if exists('g:ReplUserDefaults')
    call extend(g:ReplDefaults, g:ReplUserDefaults, 'force')
  endif
  if exists('g:ReplUserTypes')
    call extend(g:ReplTypes, g:ReplUserTypes, 'force')
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
