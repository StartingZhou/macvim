" Vim script language tests
" Author:	Servatius Brandt <Servatius.Brandt@fujitsu-siemens.com>
" Last Change:	2020 Jun 07

"-------------------------------------------------------------------------------
" Test environment							    {{{1
"-------------------------------------------------------------------------------


" Adding new tests easily.						    {{{2
"
" Writing new tests is eased considerably with the following functions and
" abbreviations (see "Commands for recording the execution path", "Automatic
" argument generation").
"
" To get the abbreviations, execute the command
"
"    :let test49_set_env = 1 | source test49.vim
"
" To get them always (from src/testdir), put a line
"
"    au! BufRead test49.vim let test49_set_env = 1 | source test49.vim
"
" into the local .vimrc file in the src/testdir directory.
"
if exists("test49_set_env") && test49_set_env

    " Automatic argument generation for the test environment commands.

    function! Xsum()
	let addend = substitute(getline("."), '^.*"\s*X:\s*\|^.*', '', "")
	" Evaluate arithmetic expression.
	if addend != ""
	    exec "let g:Xsum = g:Xsum + " . addend
	endif
    endfunction

    function! Xcheck()
	let g:Xsum=0
	?XpathINIT?,.call Xsum()
	exec "norm A "
	return g:Xsum
    endfunction

    iab Xcheck Xcheck<Space><C-R>=Xcheck()<CR><C-O>x

    function! Xcomment(num)
	let str = ""
	let tabwidth = &sts ? &sts : &ts
	let tabs = (48+tabwidth - a:num - virtcol(".")) / tabwidth
	while tabs > 0
	    let str = str . "\t"
	    let tabs = tabs - 1
	endwhile
	let str = str . '" X:'
	return str
    endfunction

    function! Xloop()
	let back = line(".") . "|norm" . virtcol(".") . "|"
	norm 0
	let last = search('X\(loop\|path\)INIT\|Xloop\>', "bW")
	exec back
	let theline = getline(last)
	if theline =~ 'X\(loop\|path\)INIT'
	    let num = 1
	else
	    let num = 2 * substitute(theline, '.*Xloop\s*\(\d\+\).*', '\1', "")
	endif
	?X\(loop\|path\)INIT?
	    \s/\(XloopINIT!\=\s*\d\+\s\+\)\@<=\(\d\+\)/\=2*submatch(2)/
	exec back
	exec "norm a "
	return num . Xcomment(strlen(num))
    endfunction

    iab Xloop Xloop<Space><C-R>=Xloop()<CR><C-O>x

    function! Xpath(loopinit)
	let back = line(".") . "|norm" . virtcol(".") . "|"
	norm 0
	let last = search('XpathINIT\|Xpath\>\|XloopINIT', "bW")
	exec back
	let theline = getline(last)
	if theline =~ 'XpathINIT'
	    let num = 1
	elseif theline =~ 'Xpath\>'
	    let num = 2 * substitute(theline, '.*Xpath\s*\(\d\+\).*', '\1', "")
	else
	    let pattern = '.*XloopINIT!\=\s*\(\d\+\)\s*\(\d\+\).*'
	    let num = substitute(theline, pattern, '\1', "")
	    let factor = substitute(theline, pattern, '\2', "")
	    " The "<C-O>x" from the "Xpath" iab and the character triggering its
	    " expansion are in the input buffer.  Save and clear typeahead so
	    " that it is not read away by the call to "input()" below.  Restore
	    " afterwards.
	    call inputsave()
	    let loops = input("Number of iterations in previous loop? ")
	    call inputrestore()
	    while (loops > 0)
		let num = num * factor
		let loops = loops - 1
	    endwhile
	endif
	exec "norm a "
	if a:loopinit
	    return num . " 1"
	endif
	return num . Xcomment(strlen(num))
    endfunction

    iab Xpath Xpath<Space><C-R>=Xpath(0)<CR><C-O>x
    iab XloopINIT XloopINIT<Space><C-R>=Xpath(1)<CR><C-O>x

    " Also useful (see ExtraVim below):
    aug ExtraVim
	au!
	au  BufEnter <sfile> syn region ExtraVim
		    \ start=+^if\s\+ExtraVim(.*)+ end=+^endif+
		    \ transparent keepend
	au  BufEnter <sfile> syn match ExtraComment /^"/
		    \ contained containedin=ExtraVim
	au  BufEnter <sfile> hi link ExtraComment vimComment
    aug END

    aug Xpath
	au  BufEnter <sfile> syn keyword Xpath
		    \ XpathINIT Xpath XloopINIT Xloop XloopNEXT Xcheck Xout
	au  BufEnter <sfile> hi link Xpath Special
    aug END

    do BufEnter <sfile>

    " Do not execute the tests when sourcing this file for getting the functions
    " and abbreviations above, which are intended for easily adding new test
    " cases; they are not needed for test execution.  Unlet the variable
    " controlling this so that an explicit ":source" command for this file will
    " execute the tests.
    unlet test49_set_env
    finish

endif


" Commands for recording the execution path.				    {{{2
"
" The Xpath/Xloop commands can be used for computing the eXecution path by
" adding (different) powers of 2 from those script lines, for which the
" execution should be checked.  Xloop provides different addends for each
" execution of a loop.  Permitted values are 2^0 to 2^30, so that 31 execution
" points (multiply counted inside loops) can be tested.
"
" Note that the arguments of the following commands can be generated
" automatically, see below.
"
" Usage:								    {{{3
"
"   - Use XpathINIT at the beginning of the test.
"
"   - Use Xpath to check if a line is executed.
"     Argument: power of 2 (decimal).
"
"   - To check multiple execution of loops use Xloop for automatically
"     computing Xpath values:
"
"	- Use XloopINIT before the loop.
"	  Two arguments:
"		- the first Xpath value (power of 2) to be used (Xnext),
"		- factor for computing a new Xnext value when reexecuting a loop
"		  (by a ":continue" or ":endwhile"); this should be 2^n where
"		  n is the number of Xloop commands inside the loop.
"	  If XloopINIT! is used, the first execution of XloopNEXT is
"	  a no-operation.
"
"       - Use Xloop inside the loop:
"	  One argument:
"		The argument and the Xnext value are multiplied to build the
"		next Xpath value.  No new Xnext value is prepared.  The argument
"		should be 2^(n-1) for the nth Xloop command inside the loop.
"		If the loop has only one Xloop command, the argument can be
"		omitted (default: 1).
"
"	- Use XloopNEXT before ":continue" and ":endwhile".  This computes a new
"	  Xnext value for the next execution of the loop by multiplying the old
"	  one with the factor specified in the XloopINIT command.  No Argument.
"	  Alternatively, when XloopINIT! is used, a single XloopNEXT at the
"	  beginning of the loop can be used.
"
"     Nested loops are not supported.
"
"   - Use Xcheck at end of each test.  It prints the test number, the expected
"     execution path value, the test result ("OK" or "FAIL"), and, if the tests
"     fails, the actual execution path.
"     One argument:
"	    Expected Xpath/Xloop sum for the correct execution path.
"	    In order that this value can be computed automatically, do the
"	    following: For each line in the test with an Xpath and Xloop
"	    command, add a comment starting with "X:" and specifying an
"	    expression that evaluates to the value contributed by this line to
"	    the correct execution path.  (For copying an Xpath argument of at
"	    least two digits into the comment, press <C-P>.)  At the end of the
"	    test, just type "Xcheck" and press <Esc>.
"
"   - In order to add additional information to the test output file, use the
"     Xout command.  Argument(s) like ":echo".
"
" Automatic argument generation:					    {{{3
"
"   The arguments of the Xpath, XloopINIT, Xloop, and Xcheck commands can be
"   generated automatically, so that new tests can easily be written without
"   mental arithmetic.  The Xcheck argument is computed from the "X:" comments
"   of the preceding Xpath and Xloop commands.  See the commands and
"   abbreviations at the beginning of this file.
"
" Implementation:							    {{{3
"     XpathINIT, Xpath, XloopINIT, Xloop, XloopNEXT, Xcheck, Xout.
"
" The variants for existing g:ExtraVimResult are needed when executing a script
" in an extra Vim process, see ExtraVim below.

" EXTRA_VIM_START - do not change or remove this line.

com!		    XpathINIT	let g:Xpath = 0

if exists("g:ExtraVimResult")
    com! -count -bar    Xpath	exec "!echo <count> >>" . g:ExtraVimResult
else
    com! -count -bar    Xpath	let g:Xpath = g:Xpath + <count>
endif

com! -count -nargs=1 -bang
		  \ XloopINIT	let g:Xnext = <count> |
				    \ let g:Xfactor = <args> |
				    \ let g:Xskip = strlen("<bang>")

if exists("g:ExtraVimResult")
    com! -count=1 -bar  Xloop	exec "!echo " . (g:Xnext * <count>) . " >>" .
				    \ g:ExtraVimResult
else
    com! -count=1 -bar  Xloop	let g:Xpath = g:Xpath + g:Xnext * <count>
endif

com!		    XloopNEXT	let g:Xnext = g:Xnext *
				    \ (g:Xskip ? 1 : g:Xfactor) |
				    \ let g:Xskip = 0

let @r = ""
let Xtest = 1
com! -count	    Xcheck	let Xresult = "*** Test " .
				    \ (Xtest<10?"  ":Xtest<100?" ":"") .
				    \ Xtest . ": " . (
				    \ (Xpath==<count>) ? "OK (".Xpath.")" :
					\ "FAIL (".Xpath." instead of <count>)"
				    \ ) |
				    \ let @R = Xresult . "\n" |
				    \ echo Xresult |
				    \ let Xtest = Xtest + 1

if exists("g:ExtraVimResult")
    com! -nargs=+    Xoutq	exec "!echo @R:'" .
				    \ substitute(substitute(<q-args>,
				    \ "'", '&\\&&', "g"), "\n", "@NL@", "g")
				    \ . "' >>" . g:ExtraVimResult
else
    com! -nargs=+    Xoutq	let @R = "--- Test " .
				    \ (g:Xtest<10?"  ":g:Xtest<100?" ":"") .
				    \ g:Xtest . ": " . substitute(<q-args>,
				    \ "\n", "&\t      ", "g") . "\n"
endif
com! -nargs=+	    Xout	exec 'Xoutq' <args>

" Switch off storing of lines for undoing changes.  Speeds things up a little.
set undolevels=-1

" EXTRA_VIM_STOP - do not change or remove this line.


" ExtraVim() - Run a script file in an extra Vim process.		    {{{2
"
" This is useful for testing immediate abortion of the script processing due to
" an error in a command dynamically enclosed by a :try/:tryend region or when an
" exception is thrown but not caught or when an interrupt occurs.  It can also
" be used for testing :finish.
"
" An interrupt location can be specified by an "INTERRUPT" comment.  A number
" telling how often this location is reached (in a loop or in several function
" calls) should be specified as argument.  When missing, once per script
" invocation or function call is assumed.  INTERRUPT locations are tested by
" setting a breakpoint in that line and using the ">quit" debug command when
" the breakpoint is reached.  A function for which an INTERRUPT location is
" specified must be defined before calling it (or executing it as a script by
" using ExecAsScript below).
"
" This function is only called in normal modus ("g:ExtraVimResult" undefined).
"
" Tests to be executed as an extra script should be written as follows:
"
"	column 1			column 1
"	|				|
"	v				v
"
"	XpathINIT			XpathINIT
"	if ExtraVim()			if ExtraVim()
"	    ...				"   ...
"	    ...				"   ...
"	endif				endif
"	Xcheck <number>			Xcheck <number>
"
" Double quotes in column 1 are removed before the script is executed.
" They should be used if the test has unbalanced conditionals (:if/:endif,
" :while:/endwhile, :try/:endtry) or for a line with a syntax error.  The
" extra script may use Xpath, XloopINIT, Xloop, XloopNEXT, and Xout as usual.
"
" A file name may be specified as argument.  All messages of the extra Vim
" process are then redirected to the file.  An existing file is overwritten.
"
let ExtraVimCount = 0
let ExtraVimBase = expand("<sfile>")
let ExtraVimTestEnv = ""
"
function ExtraVim(...)
    " Count how often this function is called.
    let g:ExtraVimCount = g:ExtraVimCount + 1

    " Disable folds to prevent that the ranges in the ":write" commands below
    " are extended up to the end of a closed fold.  This also speeds things up
    " considerably.
    set nofoldenable

    " Open a buffer for this test script and copy the test environment to
    " a temporary file.  Take account of parts relevant for the extra script
    " execution only.
    let current_buffnr = bufnr("%")
    execute "view +1" g:ExtraVimBase
    if g:ExtraVimCount == 1
	let g:ExtraVimTestEnv = tempname()
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w"
		    \ g:ExtraVimTestEnv "|']+"
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w >>"
		    \ g:ExtraVimTestEnv "|']+"
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w >>"
		    \ g:ExtraVimTestEnv "|']+"
	execute "/E" . "XTRA_VIM_START/+,/E" . "XTRA_VIM_STOP/-w >>"
		    \ g:ExtraVimTestEnv "|']+"
    endif

    " Start the extra Vim script with a ":source" command for the test
    " environment.  The source line number where the extra script will be
    " appended, needs to be passed as variable "ExtraVimBegin" to the script.
    let extra_script = tempname()
    exec "!echo 'source " . g:ExtraVimTestEnv . "' >" . extra_script
    let extra_begin = 1

    " Starting behind the test environment, skip over the first g:ExtraVimCount
    " occurrences of "if ExtraVim()" and copy the following lines up to the
    " matching "endif" to the extra Vim script.
    execute "/E" . "ND_OF_TEST_ENVIRONMENT/"
    exec 'norm ' . g:ExtraVimCount . '/^\s*if\s\+ExtraVim(.*)/+' . "\n"
    execute ".,/^endif/-write >>" . extra_script

    " Open a buffer for the extra Vim script, delete all ^", and write the
    " script if was actually modified.
    execute "edit +" . (extra_begin + 1) extra_script
    ,$s/^"//e
    update

    " Count the INTERRUPTs and build the breakpoint and quit commands.
    let breakpoints = ""
    let debug_quits = ""
    let in_func = 0
    exec extra_begin
    while search(
	    \ '"\s*INTERRUPT\h\@!\|^\s*fu\%[nction]\>!\=\s*\%(\u\|s:\)\w*\s*(\|'
	    \ . '^\s*\\\|^\s*endf\%[unction]\>\|'
	    \ . '\%(^\s*fu\%[nction]!\=\s*\)\@<!\%(\u\|s:\)\w*\s*(\|'
	    \ . 'ExecAsScript\s\+\%(\u\|s:\)\w*',
	    \ "W") > 0
	let theline = getline(".")
	if theline =~ '^\s*fu'
	    " Function definition.
	    let in_func = 1
	    let func_start = line(".")
	    let func_name = substitute(theline,
		\ '^\s*fu\%[nction]!\=\s*\(\%(\u\|s:\)\w*\).*', '\1', "")
	elseif theline =~ '^\s*endf'
	    " End of function definition.
	    let in_func = 0
	else
	    let finding = substitute(theline, '.*\(\%' . col(".") . 'c.*\)',
		\ '\1', "")
	    if finding =~ '^"\s*INTERRUPT\h\@!'
		" Interrupt comment.  Compose as many quit commands as
		" specified.
		let cnt = substitute(finding,
		    \ '^"\s*INTERRUPT\s*\(\d*\).*$', '\1', "")
		let quits = ""
		while cnt > 0
		    " Use "\r" rather than "\n" to separate the quit commands.
		    " "\r" is not interpreted as command separator by the ":!"
		    " command below but works to separate commands in the
		    " external vim.
		    let quits = quits . "q\r"
		    let cnt = cnt - 1
		endwhile
		if in_func
		    " Add the function breakpoint and note the number of quits
		    " to be used, if specified, or one for every call else.
		    let breakpoints = breakpoints . " -c 'breakadd func " .
			\ (line(".") - func_start) . " " .
			\ func_name . "'"
		    if quits != ""
			let debug_quits = debug_quits . quits
		    elseif !exists("quits{func_name}")
			let quits{func_name} = "q\r"
		    else
			let quits{func_name} = quits{func_name} . "q\r"
		    endif
		else
		    " Add the file breakpoint and the quits to be used for it.
		    let breakpoints = breakpoints . " -c 'breakadd file " .
			\ line(".") . " " . extra_script . "'"
		    if quits == ""
			let quits = "q\r"
		    endif
		    let debug_quits = debug_quits . quits
		endif
	    else
		" Add the quits to be used for calling the function or executing
		" it as script file.
		if finding =~ '^ExecAsScript'
		    " Sourcing function as script.
		    let finding = substitute(finding,
			\ '^ExecAsScript\s\+\(\%(\u\|s:\)\w*\).*', '\1', "")
		else
		    " Function call.
		    let finding = substitute(finding,
			\ '^\(\%(\u\|s:\)\w*\).*', '\1', "")
		endif
		if exists("quits{finding}")
		    let debug_quits = debug_quits . quits{finding}
		endif
	    endif
	endif
    endwhile

    " Close the buffer for the script and create an (empty) resultfile.
    bwipeout
    let resultfile = tempname()
    exec "!>" . resultfile

    " Run the script in an extra vim.  Switch to extra modus by passing the
    " resultfile in ExtraVimResult.  Redirect messages to the file specified as
    " argument if any.  Use ":debuggreedy" so that the commands provided on the
    " pipe are consumed at the debug prompt.  Use "-N" to enable command-line
    " continuation ("C" in 'cpo').  Add "nviminfo" to 'viminfo' to avoid
    " messing up the user's viminfo file.
    let redirect = a:0 ?
	\ " -c 'au VimLeave * redir END' -c 'redir\\! >" . a:1 . "'" : ""
    exec "!echo '" . debug_quits . "q' | " .. v:progpath .. " -u NONE -N -Xes" . redirect .
	\ " -c 'debuggreedy|set viminfo+=nviminfo'" .
	\ " -c 'let ExtraVimBegin = " . extra_begin . "'" .
	\ " -c 'let ExtraVimResult = \"" . resultfile . "\"'" . breakpoints .
	\ " -S " . extra_script

    " Build the resulting sum for resultfile and add it to g:Xpath.  Add Xout
    " information provided by the extra Vim process to the test output.
    let sum = 0
    exec "edit" resultfile
    let line = 1
    while line <= line("$")
	let theline = getline(line)
	if theline =~ '^@R:'
	    exec 'Xout "' . substitute(substitute(
		\ escape(escape(theline, '"'), '\"'),
		\ '^@R:', '', ""), '@NL@', "\n", "g") . '"'
	else
	    let sum = sum + getline(line)
	endif
	let line = line + 1
    endwhile
    bwipeout
    let g:Xpath = g:Xpath + sum

    " Delete the extra script and the resultfile.
    call delete(extra_script)
    call delete(resultfile)

    " Switch back to the buffer that was active when this function was entered.
    exec "buffer" current_buffnr

    " Return 0.  This protects extra scripts from being run in the main Vim
    " process.
    return 0
endfunction


" ExtraVimThrowpoint() - Relative throwpoint in ExtraVim script		    {{{2
"
" Evaluates v:throwpoint and returns the throwpoint relative to the beginning of
" an ExtraVim script as passed by ExtraVim() in ExtraVimBegin.
"
" EXTRA_VIM_START - do not change or remove this line.
function ExtraVimThrowpoint()
    if !exists("g:ExtraVimBegin")
	Xout "ExtraVimThrowpoint() used outside ExtraVim() script."
	return v:throwpoint
    endif

    if v:throwpoint =~ '^function\>'
	return v:throwpoint
    endif

    return "line " .
	\ (substitute(v:throwpoint, '.*, line ', '', "") - g:ExtraVimBegin) .
	\ " of ExtraVim() script"
endfunction
" EXTRA_VIM_STOP - do not change or remove this line.


" MakeScript() - Make a script file from a function.			    {{{2
"
" Create a script that consists of the body of the function a:funcname.
" Replace any ":return" by a ":finish", any argument variable by a global
" variable, and every ":call" by a ":source" for the next following argument
" in the variable argument list.  This function is useful if similar tests are
" to be made for a ":return" from a function call or a ":finish" in a script
" file.
"
" In order to execute a function specifying an INTERRUPT location (see ExtraVim)
" as a script file, use ExecAsScript below.
"
" EXTRA_VIM_START - do not change or remove this line.
function MakeScript(funcname, ...)
    let script = tempname()
    execute "redir! >" . script
    execute "function" a:funcname
    redir END
    execute "edit" script
    " Delete the "function" and the "endfunction" lines.  Do not include the
    " word "function" in the pattern since it might be translated if LANG is
    " set.  When MakeScript() is being debugged, this deletes also the debugging
    " output of its line 3 and 4.
    exec '1,/.*' . a:funcname . '(.*)/d'
    /^\d*\s*endfunction\>/,$d
    %s/^\d*//e
    %s/return/finish/e
    %s/\<a:\(\h\w*\)/g:\1/ge
    normal gg0
    let cnt = 0
    while search('\<call\s*\%(\u\|s:\)\w*\s*(.*)', 'W') > 0
	let cnt = cnt + 1
	s/\<call\s*\%(\u\|s:\)\w*\s*(.*)/\='source ' . a:{cnt}/
    endwhile
    g/^\s*$/d
    write
    bwipeout
    return script
endfunction
" EXTRA_VIM_STOP - do not change or remove this line.


" ExecAsScript - Source a temporary script made from a function.	    {{{2
"
" Make a temporary script file from the function a:funcname, ":source" it, and
" delete it afterwards.
"
" When inside ":if ExtraVim()", add a file breakpoint for each INTERRUPT
" location specified in the function.
"
" EXTRA_VIM_START - do not change or remove this line.
function ExecAsScript(funcname)
    " Make a script from the function passed as argument.
    let script = MakeScript(a:funcname)

    " When running in an extra Vim process, add a file breakpoint for each
    " function breakpoint set when the extra Vim process was invoked by
    " ExtraVim().
    if exists("g:ExtraVimResult")
	let bplist = tempname()
	execute "redir! >" . bplist
	breaklist
	redir END
	execute "edit" bplist
	" Get the line number from the function breakpoint.  Works also when
	" LANG is set.
	execute 'v/^\s*\d\+\s\+func\s\+' . a:funcname . '\s.*/d'
	%s/^\s*\d\+\s\+func\s\+\%(\u\|s:\)\w*\s\D*\(\d*\).*/\1/e
	let cnt = 0
	while cnt < line("$")
	    let cnt = cnt + 1
	    if getline(cnt) != ""
		execute "breakadd file" getline(cnt) script
	    endif
	endwhile
	bwipeout!
	call delete(bplist)
    endif

    " Source and delete the script.
    exec "source" script
    call delete(script)
endfunction

com! -nargs=1 -bar ExecAsScript call ExecAsScript(<f-args>)
" EXTRA_VIM_STOP - do not change or remove this line.


" END_OF_TEST_ENVIRONMENT - do not change or remove this line.

function! MESSAGES(...)
    try
	exec "edit" g:msgfile
    catch /^Vim(edit):/
	return 0
    endtry

    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    let match = 1
    norm gg

    let num = a:0 / 2
    let cnt = 1
    while cnt <= num
	let enr = a:{2*cnt - 1}
	let emsg= a:{2*cnt}
	let cnt = cnt + 1

	if enr == ""
	    Xout "TODO: Add message number for:" emsg
	elseif enr == "INT"
	    let enr = ""
	endif
	if enr == "" && !english
	    continue
	endif
	let pattern = (enr != "") ? enr . ':.*' : ''
	if english
	    let pattern = pattern . emsg
	endif
	if !search(pattern, "W")
	    let match = 0
	    Xout "No match for:" pattern
	endif
	norm $
    endwhile

    bwipeout!
    return match
endfunction

" Leave MESSAGES() for the next tests.

" Tests 1 to 50, 52 to 57, 87 were moved to test_vimscript.vim
" Tests 25, 26, 32, 33, 41-48, 51, 69-75 were moved to test_trycatch.vim
let Xtest = 59

"-------------------------------------------------------------------------------
"
" Test 59:  v:exception and v:throwpoint when discarding exceptions	    {{{1
"
"	    When a :catch clause is left by a ":break" etc or an error or
"	    interrupt exception, v:exception and v:throwpoint are reset.  They
"	    are not affected by an exception that is discarded before being
"	    caught.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    XloopINIT! 1 2

    let sfile = expand("<sfile>")

    function! LineNumber()
	return substitute(substitute(v:throwpoint, g:sfile, '', ""),
	    \ '\D*\(\d*\).*', '\1', "")
    endfunction

    command! -nargs=1 SetLineNumber
	\ try | throw "line" | catch /.*/ | let <args> =  LineNumber() | endtry

    " Check v:exception/v:throwpoint against second/fourth parameter if
    " specified, check for being empty else.
    function! CHECK(n, ...)
	XloopNEXT
	let exception = a:0 != 0 ? a:1 : ""	" second parameter (optional)
	let emsg      = a:0 != 0 ? a:2 : ""	" third parameter (optional)
	let line      = a:0 != 0 ? a:3 : 0	" fourth parameter (optional)
	let error = 0
	if emsg != ""
	    " exception is the error number, emsg the English error message text
	    if exception !~ '^E\d\+$'
		Xout "TODO: Add message number for:" emsg
	    elseif v:lang == "C" || v:lang =~ '^[Ee]n'
		if exception == "E492" && emsg == "Not an editor command"
		    let exception = '^Vim:' . exception . ': ' . emsg
		else
		    let exception = '^Vim(\a\+):' . exception . ': ' . emsg
		endif
	    else
		if exception == "E492"
		    let exception = '^Vim:' . exception
		else
		    let exception = '^Vim(\a\+):' . exception
		endif
	    endif
	endif
	if exception == "" && v:exception != ""
	    Xout a:n.": v:exception is set:" v:exception
	    let error = 1
	elseif exception != "" && v:exception !~ exception
	    Xout a:n.": v:exception (".v:exception.") does not match" exception
	    let error = 1
	endif
	if line == 0 && v:throwpoint != ""
	    Xout a:n.": v:throwpoint is set:" v:throwpoint
	    let error = 1
	elseif line != 0 && v:throwpoint !~ '\<' . line . '\>'
	    Xout a:n.": v:throwpoint (".v:throwpoint.") does not match" line
	    let error = 1
	endif
	if !error
	    Xloop 1				" X: 2097151
	endif
    endfunction

    while 1
	try
	    throw "x1"
	catch /.*/
	    break
	endtry
    endwhile
    call CHECK(1)

    while 1
	try
	    throw "x2"
	catch /.*/
	    break
	finally
	    call CHECK(2)
	endtry
	break
    endwhile
    call CHECK(3)

    while 1
	try
	    let errcaught = 0
	    try
		try
		    throw "x3"
		catch /.*/
		    SetLineNumber line_before_error
		    asdf
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(4, 'E492', "Not an editor command",
		    \ line_before_error + 1)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(4)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(5)

    Xpath 2097152				" X: 2097152

    while 1
	try
	    let intcaught = 0
	    try
		try
		    throw "x4"
		catch /.*/
		    SetLineNumber two_lines_before_interrupt
		    "INTERRUPT
		    let dummy = 0
		endtry
	    catch /.*/
		let intcaught = 1
		call CHECK(6, "Vim:Interrupt", '',
		    \ two_lines_before_interrupt + 2)
	    endtry
	finally
	    if !intcaught && $VIMNOINTTHROW
		call CHECK(6)
	    endif
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile
    call CHECK(7)

    Xpath 4194304				" X: 4194304

    while 1
	try
	    let errcaught = 0
	    try
		try
"		    if 1
			SetLineNumber line_before_throw
			throw "x5"
		    " missing endif
		catch /.*/
		    Xpath 8388608			" X: 0
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(8, 'E171', "Missing :endif", line_before_throw + 3)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(8)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(9)

    Xpath 16777216				" X: 16777216

    try
	while 1
	    try
		throw "x6"
	    finally
		break
	    endtry
	    break
	endwhile
    catch /.*/
	Xpath 33554432				" X: 0
    endtry
    call CHECK(10)

    try
	while 1
	    try
		throw "x7"
	    finally
		break
	    endtry
	    break
	endwhile
    catch /.*/
	Xpath 67108864				" X: 0
    finally
	call CHECK(11)
    endtry
    call CHECK(12)

    while 1
	try
	    let errcaught = 0
	    try
		try
		    throw "x8"
		finally
		    SetLineNumber line_before_error
		    asdf
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(13, 'E492', "Not an editor command",
		    \ line_before_error + 1)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(13)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(14)

    Xpath 134217728				" X: 134217728

    while 1
	try
	    let intcaught = 0
	    try
		try
		    throw "x9"
		finally
		    SetLineNumber two_lines_before_interrupt
		    "INTERRUPT
		endtry
	    catch /.*/
		let intcaught = 1
		call CHECK(15, "Vim:Interrupt", '',
		    \ two_lines_before_interrupt + 2)
	    endtry
	finally
	    if !intcaught && $VIMNOINTTHROW
		call CHECK(15)
	    endif
	    break		" discard interrupt for $VIMNOINTTHROW
	endtry
    endwhile
    call CHECK(16)

    Xpath 268435456				" X: 268435456

    while 1
	try
	    let errcaught = 0
	    try
		try
"		    if 1
			SetLineNumber line_before_throw
			throw "x10"
		    " missing endif
		finally
		    call CHECK(17)
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(18, 'E171', "Missing :endif", line_before_throw + 3)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(18)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(19)

    Xpath 536870912				" X: 536870912

    while 1
	try
	    let errcaught = 0
	    try
		try
"		    if 1
			SetLineNumber line_before_throw
			throw "x11"
		    " missing endif
		endtry
	    catch /.*/
		let errcaught = 1
		call CHECK(20, 'E171', "Missing :endif", line_before_throw + 3)
	    endtry
	finally
	    if !errcaught && $VIMNOERRTHROW
		call CHECK(20)
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile
    call CHECK(21)

    Xpath 1073741824				" X: 1073741824

endif

Xcheck 2038431743


"-------------------------------------------------------------------------------
"
" Test 60:  (Re)throwing v:exception; :echoerr.				    {{{1
"
"	    A user exception can be rethrown after catching by throwing
"	    v:exception.  An error or interrupt exception cannot be rethrown
"	    because Vim exceptions cannot be faked.  A Vim exception using the
"	    value of v:exception can, however, be triggered by the :echoerr
"	    command.
"-------------------------------------------------------------------------------

XpathINIT

try
    try
	Xpath 1					" X: 1
	throw "oops"
    catch /oops/
	Xpath 2					" X: 2
	throw v:exception	" rethrow user exception
    catch /.*/
	Xpath 4					" X: 0
    endtry
catch /^oops$/			" catches rethrown user exception
    Xpath 8					" X: 8
catch /.*/
    Xpath 16					" X: 0
endtry

function! F()
    try
	let caught = 0
	try
	    Xpath 32				" X: 32
	    write /n/o/n/w/r/i/t/a/b/l/e/_/f/i/l/e
	    Xpath 64				" X: 0
	    Xout "did_emsg was reset before executing " .
		\ "BufWritePost autocommands."
	catch /^Vim(write):/
	    let caught = 1
	    throw v:exception	" throw error: cannot fake Vim exception
	catch /.*/
	    Xpath 128				" X: 0
	finally
	    Xpath 256				" X: 256
	    if !caught && !$VIMNOERRTHROW
		Xpath 512			" X: 0
	    endif
	endtry
    catch /^Vim(throw):/	" catches throw error
	let caught = caught + 1
    catch /.*/
	Xpath 1024				" X: 0
    finally
	Xpath 2048				" X: 2048
	if caught != 2
	    if !caught && !$VIMNOERRTHROW
		Xpath 4096			" X: 0
	    elseif caught
		Xpath 8192			" X: 0
	    endif
	    return		| " discard error for $VIMNOERRTHROW
	endif
    endtry
endfunction

call F()
delfunction F

function! G()
    try
	let caught = 0
	try
	    Xpath 16384				" X: 16384
	    asdf
	catch /^Vim/		" catch error exception
	    let caught = 1
	    " Trigger Vim error exception with value specified after :echoerr
	    let value = substitute(v:exception, '^Vim\((.*)\)\=:', '', "")
	    echoerr value
	catch /.*/
	    Xpath 32768				" X: 0
	finally
	    Xpath 65536				" X: 65536
	    if !caught
		if !$VIMNOERRTHROW
		    Xpath 131072		" X: 0
		else
		    let value = "Error"
		    echoerr value
		endif
	    endif
	endtry
    catch /^Vim(echoerr):/
	let caught = caught + 1
	if v:exception !~ value
	    Xpath 262144			" X: 0
	endif
    catch /.*/
	Xpath 524288				" X: 0
    finally
	Xpath 1048576				" X: 1048576
	if caught != 2
	    if !caught && !$VIMNOERRTHROW
		Xpath 2097152			" X: 0
	    elseif caught
		Xpath 4194304			" X: 0
	    endif
	    return		| " discard error for $VIMNOERRTHROW
	endif
    endtry
endfunction

call G()
delfunction G

unlet! value caught

if ExtraVim()
    try
	let errcaught = 0
	try
	    Xpath 8388608			" X: 8388608
	    let intcaught = 0
	    "INTERRUPT
	catch /^Vim:/		" catch interrupt exception
	    let intcaught = 1
	    " Trigger Vim error exception with value specified after :echoerr
	    echoerr substitute(v:exception, '^Vim\((.*)\)\=:', '', "")
	catch /.*/
	    Xpath 16777216			" X: 0
	finally
	    Xpath 33554432			" X: 33554432
	    if !intcaught
		if !$VIMNOINTTHROW
		    Xpath 67108864		" X: 0
		else
		    echoerr "Interrupt"
		endif
	    endif
	endtry
    catch /^Vim(echoerr):/
	let errcaught = 1
	if v:exception !~ "Interrupt"
	    Xpath 134217728			" X: 0
	endif
    finally
	Xpath 268435456				" X: 268435456
	if !errcaught && !$VIMNOERRTHROW
	    Xpath 536870912			" X: 0
	endif
    endtry
endif

Xcheck 311511339

" Test 61 was moved to test_vimscript.vim
let Xtest = 62

"-------------------------------------------------------------------------------
" Test 62:  Catching error exceptions					    {{{1
"
"	    An error inside a :try/:endtry region is converted to an exception
"	    and can be caught.  The error exception has a "Vim(cmdname):" prefix
"	    where cmdname is the name of the failing command, or a "Vim:" prefix
"	    if no command name is known.  The "Vim" prefixes cannot be faked.
"-------------------------------------------------------------------------------

XpathINIT

function! MSG(enr, emsg)
    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    if a:enr == ""
	Xout "TODO: Add message number for:" a:emsg
	let v:errmsg = ":" . v:errmsg
    endif
    let match = 1
    if v:errmsg !~ '^'.a:enr.':' || (english && v:errmsg !~ a:emsg)
	let match = 0
	if v:errmsg == ""
	    Xout "Message missing."
	else
	    let v:errmsg = escape(v:errmsg, '"')
	    Xout "Unexpected message:" v:errmsg
	endif
    endif
    return match
endfunction

while 1
    try
	try
	    let caught = 0
	    unlet novar
	catch /^Vim(unlet):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(unlet):', '', "")
	finally
	    Xpath 1				" X: 1
	    if !caught && !$VIMNOERRTHROW
		Xpath 2				" X: 0
	    endif
	    if !MSG('E108', "No such variable")
		Xpath 4				" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 8					" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let caught = 0
	    throw novar			" error in :throw
	catch /^Vim(throw):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(throw):', '', "")
	finally
	    Xpath 16				" X: 16
	    if !caught && !$VIMNOERRTHROW
		Xpath 32			" X: 0
	    endif
	    if caught ? !MSG('E121', "Undefined variable")
			\ : !MSG('E15', "Invalid expression")
		Xpath 64			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 128				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let caught = 0
	    throw "Vim:faked"		" error: cannot fake Vim exception
	catch /^Vim(throw):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(throw):', '', "")
	finally
	    Xpath 256				" X: 256
	    if !caught && !$VIMNOERRTHROW
		Xpath 512			" X: 0
	    endif
	    if !MSG('E608', "Cannot :throw exceptions with 'Vim' prefix")
		Xpath 1024			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 2048				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

function! F()
    while 1
    " Missing :endwhile
endfunction

while 1
    try
	try
	    let caught = 0
	    call F()
	catch /^Vim(endfunction):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(endfunction):', '', "")
	finally
	    Xpath 4096				" X: 4096
	    if !caught && !$VIMNOERRTHROW
		Xpath 8192			" X: 0
	    endif
	    if !MSG('E170', "Missing :endwhile")
		Xpath 16384			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 32768				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let caught = 0
	    ExecAsScript F
	catch /^Vim:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim:', '', "")
	finally
	    Xpath 65536				" X: 65536
	    if !caught && !$VIMNOERRTHROW
		Xpath 131072			" X: 0
	    endif
	    if !MSG('E170', "Missing :endwhile")
		Xpath 262144			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 524288				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

function! G()
    call G()
endfunction

while 1
    try
	let mfd_save = &mfd
	set mfd=3
	try
	    let caught = 0
	    call G()
	catch /^Vim(call):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(call):', '', "")
	finally
	    Xpath 1048576			" X: 1048576
	    if !caught && !$VIMNOERRTHROW
		Xpath 2097152			" X: 0
	    endif
	    if !MSG('E132', "Function call depth is higher than 'maxfuncdepth'")
		Xpath 4194304			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 8388608				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	let &mfd = mfd_save
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

function! H()
    return H()
endfunction

while 1
    try
	let mfd_save = &mfd
	set mfd=3
	try
	    let caught = 0
	    call H()
	catch /^Vim(return):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(return):', '', "")
	finally
	    Xpath 16777216			" X: 16777216
	    if !caught && !$VIMNOERRTHROW
		Xpath 33554432			" X: 0
	    endif
	    if !MSG('E132', "Function call depth is higher than 'maxfuncdepth'")
		Xpath 67108864			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 134217728				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	let &mfd = mfd_save
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

unlet! caught mfd_save
delfunction F
delfunction G
delfunction H
Xpath 268435456					" X: 268435456

Xcheck 286331153

" Leave MSG() for the next test.


"-------------------------------------------------------------------------------
" Test 63:  Suppressing error exceptions by :silent!.			    {{{1
"
"	    A :silent! command inside a :try/:endtry region suppresses the
"	    conversion of errors to an exception and the immediate abortion on
"	    error.  When the commands executed by the :silent! themselves open
"	    a new :try/:endtry region, conversion of errors to exception and
"	    immediate abortion is switched on again - until the next :silent!
"	    etc.  The :silent! has the effect of setting v:errmsg to the error
"	    message text (without displaying it) and continuing with the next
"	    script line.
"
"	    When a command triggering autocommands is executed by :silent!
"	    inside a :try/:endtry, the autocommand execution is not suppressed
"	    on error.
"
"	    This test reuses the function MSG() from the previous test.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT! 1 4

let taken = ""

function! S(n) abort
    XloopNEXT
    let g:taken = g:taken . "E" . a:n
    let v:errmsg = ""
    exec "asdf" . a:n

    " Check that ":silent!" continues:
    Xloop 1

    " Check that ":silent!" sets "v:errmsg":
    if MSG('E492', "Not an editor command")
	Xloop 2
    endif
endfunction

function! Foo()
    while 1
	try
	    try
		let caught = 0
		" This is not silent:
		call S(3)				" X: 0 * 16
	    catch /^Vim:/
		let caught = 1
		let errmsg3 = substitute(v:exception, '^Vim:', '', "")
		silent! call S(4)			" X: 3 * 64
	    finally
		if !caught
		    let errmsg3 = v:errmsg
		    " Do call S(4) here if not executed in :catch.
		    silent! call S(4)
		endif
		Xpath 1048576			" X: 1048576
		if !caught && !$VIMNOERRTHROW
		    Xpath 2097152		" X: 0
		endif
		let v:errmsg = errmsg3
		if !MSG('E492', "Not an editor command")
		    Xpath 4194304		" X: 0
		endif
		silent! call S(5)			" X: 3 * 256
		" Break out of try conditionals that cover ":silent!".  This also
		" discards the aborting error when $VIMNOERRTHROW is non-zero.
		break
	    endtry
	catch /.*/
	    Xpath 8388608			" X: 0
	    Xout v:exception "in" v:throwpoint
	endtry
    endwhile
    " This is a double ":silent!" (see caller).
    silent! call S(6)					" X: 3 * 1024
endfunction

function! Bar()
    try
	silent! call S(2)				" X: 3 * 4
							" X: 3 * 4096
	silent! execute "call Foo() | call S(7)"
	silent! call S(8)				" X: 3 * 16384
    endtry	" normal end of try cond that covers ":silent!"
    " This has a ":silent!" from the caller:
    call S(9)						" X: 3 * 65536
endfunction

silent! call S(1)					" X: 3 * 1
silent! call Bar()
silent! call S(10)					" X: 3 * 262144

let expected = "E1E2E3E4E5E6E7E8E9E10"
if taken != expected
    Xpath 16777216				" X: 0
    Xout "'taken' is" taken "instead of" expected
endif

augroup TMP
    autocmd BufWritePost * Xpath 33554432	" X: 33554432
augroup END

Xpath 67108864					" X: 67108864
write /i/m/p/o/s/s/i/b/l/e
Xpath 134217728					" X: 134217728

autocmd! TMP
unlet! caught errmsg3 taken expected
delfunction S
delfunction Foo
delfunction Bar
delfunction MSG

Xcheck 236978127


"-------------------------------------------------------------------------------
" Test 64:  Error exceptions after error, interrupt or :throw		    {{{1
"
"	    When an error occurs after an interrupt or a :throw but before
"	    a matching :catch is reached, all following :catches of that try
"	    block are ignored, but the error exception can be caught by the next
"	    surrounding try conditional.  Any previous error exception is
"	    discarded.  An error is ignored when there is a previous error that
"	    has not been caught.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    while 1
	try
	    try
		Xpath 1				" X: 1
		let caught = 0
		while 1
"		    if 1
		    " Missing :endif
		endwhile	" throw error exception
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 2				" X: 2
		if caught || $VIMNOERRTHROW
		    Xpath 4			" X: 4
		endif
	    endtry
	catch /.*/
	    Xpath 8				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		Xpath 16			" X: 16
		let caught = 0
		try
"		    if 1
		    " Missing :endif
		catch /.*/	" throw error exception
		    Xpath 32			" X: 0
		catch /.*/
		    Xpath 64			" X: 0
		endtry
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 128			" X: 128
		if caught || $VIMNOERRTHROW
		    Xpath 256			" X: 256
		endif
	    endtry
	catch /.*/
	    Xpath 512				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		try
		    Xpath 1024			" X: 1024
		    "INTERRUPT
		catch /do_not_catch/
		    Xpath 2048			" X: 0
"		    if 1
		    " Missing :endif
		catch /.*/	" throw error exception
		    Xpath 4096			" X: 0
		catch /.*/
		    Xpath 8192			" X: 0
		endtry
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 16384			" X: 16384
		if caught || $VIMNOERRTHROW
		    Xpath 32768			" X: 32768
		endif
	    endtry
	catch /.*/
	    Xpath 65536				" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		try
		    Xpath 131072		" X: 131072
		    throw "x"
		catch /do_not_catch/
		    Xpath 262144		" X: 0
"		    if 1
		    " Missing :endif
		catch /x/	" throw error exception
		    Xpath 524288		" X: 0
		catch /.*/
		   Xpath 1048576		" X: 0
		endtry
	    catch /^Vim(/
		let caught = 1
	    finally
		Xpath 2097152			" X: 2097152
		if caught || $VIMNOERRTHROW
		    Xpath 4194304		" X: 4194304
		endif
	    endtry
	catch /.*/
	    Xpath 8388608			" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    while 1
	try
	    try
		let caught = 0
		Xpath 16777216			" X: 16777216
"		endif		" :endif without :if; throw error exception
"		if 1
		" Missing :endif
	    catch /do_not_catch/ " ignore new error
		Xpath 33554432			" X: 0
	    catch /^Vim(endif):/
		let caught = 1
	    catch /^Vim(/
		Xpath 67108864			" X: 0
	    finally
		Xpath 134217728			" X: 134217728
		if caught || $VIMNOERRTHROW
		    Xpath 268435456		" X: 268435456
		endif
	    endtry
	catch /.*/
	    Xpath 536870912			" X: 0
	    Xout v:exception "in" v:throwpoint
	finally
	    break		" discard error for $VIMNOERRTHROW
	endtry
    endwhile

    Xpath 1073741824				" X: 1073741824

endif

Xcheck 1499645335

" Test 65 was moved to test_vimscript.vim
let Xtest = 66

"-------------------------------------------------------------------------------
" Test 66:  Stop range :call on error, interrupt, or :throw		    {{{1
"
"	    When a function which is multiply called for a range since it
"	    doesn't handle the range itself has an error in a command
"	    dynamically enclosed by :try/:endtry or gets an interrupt or
"	    executes a :throw, no more calls for the remaining lines in the
"	    range are made.  On an error in a command not dynamically enclosed
"	    by :try/:endtry, the function is executed again for the remaining
"	    lines in the range.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    let file = tempname()
    exec "edit" file

    insert
line 1
line 2
line 3
.

    XloopINIT! 1 2

    let taken = ""
    let expected = "G1EF1E(1)F1E(2)F1E(3)G2EF2E(1)G3IF3I(1)G4TF4T(1)G5AF5A(1)"

    function! F(reason, n) abort
	let g:taken = g:taken . "F" . a:n .
	    \ substitute(a:reason, '\(\l\).*', '\u\1', "") .
	    \ "(" . line(".") . ")"

	if a:reason == "error"
	    asdf
	elseif a:reason == "interrupt"
	    "INTERRUPT
	    let dummy = 0
	elseif a:reason == "throw"
	    throw "xyz"
	elseif a:reason == "aborting error"
	    XloopNEXT
	    if g:taken != g:expected
		Xloop 1				" X: 0
		Xout "'taken' is" g:taken "instead of" g:expected
	    endif
	    try
		bwipeout!
		call delete(file)
		asdf
	    endtry
	endif
    endfunction

    function! G(reason, n)
	let g:taken = g:taken . "G" . a:n .
	    \ substitute(a:reason, '\(\l\).*', '\u\1', "")
	1,3call F(a:reason, a:n)
    endfunction

    Xpath 8					" X: 8
    call G("error", 1)
    try
	Xpath 16				" X: 16
	try
	    call G("error", 2)
	    Xpath 32				" X: 0
	finally
	    Xpath 64				" X: 64
	    try
		call G("interrupt", 3)
		Xpath 128			" X: 0
	    finally
		Xpath 256			" X: 256
		try
		    call G("throw", 4)
		    Xpath 512			" X: 0
		endtry
	    endtry
	endtry
    catch /xyz/
	Xpath 1024				" X: 1024
    catch /.*/
	Xpath 2048				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry
    Xpath 4096					" X: 4096
    call G("aborting error", 5)
    Xpath 8192					" X: 0
    Xout "'taken' is" taken "instead of" expected

endif

Xcheck 5464


"-------------------------------------------------------------------------------
" Test 67:  :throw across :call command					    {{{1
"
"	    On a call command, an exception might be thrown when evaluating the
"	    function name, during evaluation of the arguments, or when the
"	    function is being executed.  The exception can be caught by the
"	    caller.
"-------------------------------------------------------------------------------

XpathINIT

function! THROW(x, n)
    if a:n == 1
	Xpath 1						" X: 1
    elseif a:n == 2
	Xpath 2						" X: 2
    elseif a:n == 3
	Xpath 4						" X: 4
    endif
    throw a:x
endfunction

function! NAME(x, n)
    if a:n == 1
	Xpath 8						" X: 0
    elseif a:n == 2
	Xpath 16					" X: 16
    elseif a:n == 3
	Xpath 32					" X: 32
    elseif a:n == 4
	Xpath 64					" X: 64
    endif
    return a:x
endfunction

function! ARG(x, n)
    if a:n == 1
	Xpath 128					" X: 0
    elseif a:n == 2
	Xpath 256					" X: 0
    elseif a:n == 3
	Xpath 512					" X: 512
    elseif a:n == 4
	Xpath 1024					" X: 1024
    endif
    return a:x
endfunction

function! F(x, n)
    if a:n == 2
	Xpath 2048					" X: 0
    elseif a:n == 4
	Xpath 4096					" X: 4096
    endif
endfunction

while 1
    try
	let error = 0
	let v:errmsg = ""

	while 1
	    try
		Xpath 8192				" X: 8192
		call {NAME(THROW("name", 1), 1)}(ARG(4711, 1), 1)
		Xpath 16384				" X: 0
	    catch /^name$/
		Xpath 32768				" X: 32768
	    catch /.*/
		let error = 1
		Xout "1:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "1:" v:errmsg
		endif
		if error
		    Xpath 65536				" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 131072				" X: 131072
		call {NAME("F", 2)}(ARG(THROW("arg", 2), 2), 2)
		Xpath 262144				" X: 0
	    catch /^arg$/
		Xpath 524288				" X: 524288
	    catch /.*/
		let error = 1
		Xout "2:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "2:" v:errmsg
		endif
		if error
		    Xpath 1048576			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 2097152				" X: 2097152
		call {NAME("THROW", 3)}(ARG("call", 3), 3)
		Xpath 4194304				" X: 0
	    catch /^call$/
		Xpath 8388608				" X: 8388608
	    catch /^0$/	    " default return value
		Xpath 16777216				" X: 0
		Xout "3:" v:throwpoint
	    catch /.*/
		let error = 1
		Xout "3:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "3:" v:errmsg
		endif
		if error
		    Xpath 33554432			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 67108864				" X: 67108864
		call {NAME("F", 4)}(ARG(4711, 4), 4)
		Xpath 134217728				" X: 134217728
	    catch /.*/
		let error = 1
		Xout "4:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "4:" v:errmsg
		endif
		if error
		    Xpath 268435456			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

    catch /^0$/	    " default return value
	Xpath 536870912					" X: 0
	Xout v:throwpoint
    catch /.*/
	let error = 1
	Xout v:exception "in" v:throwpoint
    finally
	if !error && $VIMNOERRTHROW && v:errmsg != ""
	    let error = 1
	    Xout v:errmsg
	endif
	if error
	    Xpath 1073741824				" X: 0
	endif
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

unlet error
delfunction F

Xcheck 212514423

" Leave THROW(), NAME(), and ARG() for the next test.


"-------------------------------------------------------------------------------
" Test 68:  :throw across function calls in expressions			    {{{1
"
"	    On a function call within an expression, an exception might be
"	    thrown when evaluating the function name, during evaluation of the
"	    arguments, or when the function is being executed.  The exception
"	    can be caught by the caller.
"
"	    This test reuses the functions THROW(), NAME(), and ARG() from the
"	    previous test.
"-------------------------------------------------------------------------------

XpathINIT

function! F(x, n)
    if a:n == 2
	Xpath 2048					" X: 0
    elseif a:n == 4
	Xpath 4096					" X: 4096
    endif
    return a:x
endfunction

unlet! var1 var2 var3 var4

while 1
    try
	let error = 0
	let v:errmsg = ""

	while 1
	    try
		Xpath 8192				" X: 8192
		let var1 = {NAME(THROW("name", 1), 1)}(ARG(4711, 1), 1)
		Xpath 16384				" X: 0
	    catch /^name$/
		Xpath 32768				" X: 32768
	    catch /.*/
		let error = 1
		Xout "1:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "1:" v:errmsg
		endif
		if error
		    Xpath 65536				" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 131072				" X: 131072
		let var2 = {NAME("F", 2)}(ARG(THROW("arg", 2), 2), 2)
		Xpath 262144				" X: 0
	    catch /^arg$/
		Xpath 524288				" X: 524288
	    catch /.*/
		let error = 1
		Xout "2:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "2:" v:errmsg
		endif
		if error
		    Xpath 1048576			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 2097152				" X: 2097152
		let var3 = {NAME("THROW", 3)}(ARG("call", 3), 3)
		Xpath 4194304				" X: 0
	    catch /^call$/
		Xpath 8388608				" X: 8388608
	    catch /^0$/	    " default return value
		Xpath 16777216				" X: 0
		Xout "3:" v:throwpoint
	    catch /.*/
		let error = 1
		Xout "3:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "3:" v:errmsg
		endif
		if error
		    Xpath 33554432			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

	while 1
	    try
		Xpath 67108864				" X: 67108864
		let var4 = {NAME("F", 4)}(ARG(4711, 4), 4)
		Xpath 134217728				" X: 134217728
	    catch /.*/
		let error = 1
		Xout "4:" v:exception "in" v:throwpoint
	    finally
		if !error && $VIMNOERRTHROW && v:errmsg != ""
		    let error = 1
		    Xout "4:" v:errmsg
		endif
		if error
		    Xpath 268435456			" X: 0
		endif
		let error = 0
		let v:errmsg = ""
		break		" discard error for $VIMNOERRTHROW
	    endtry
	endwhile

    catch /^0$/	    " default return value
	Xpath 536870912					" X: 0
	Xout v:throwpoint
    catch /.*/
	let error = 1
	Xout v:exception "in" v:throwpoint
    finally
	if !error && $VIMNOERRTHROW && v:errmsg != ""
	    let error = 1
	    Xout v:errmsg
	endif
	if error
	    Xpath 1073741824				" X: 0
	endif
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

if exists("var1") || exists("var2") || exists("var3") ||
	    \ !exists("var4") || var4 != 4711
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648			" X: 0
    if exists("var1")
	Xout "var1 =" var1
    endif
    if exists("var2")
	Xout "var2 =" var2
    endif
    if exists("var3")
	Xout "var3 =" var3
    endif
    if !exists("var4")
	Xout "var4 unset"
    elseif var4 != 4711
	Xout "var4 =" var4
    endif
endif

unlet! error var1 var2 var3 var4
delfunction THROW
delfunction NAME
delfunction ARG
delfunction F

Xcheck 212514423

" Tests 69 to 75 were moved to test_trycatch.vim
let Xtest = 76


"-------------------------------------------------------------------------------
" Test 76:  Errors, interrupts, :throw during expression evaluation	    {{{1
"
"	    When a function call made during expression evaluation is aborted
"	    due to an error inside a :try/:endtry region or due to an interrupt
"	    or a :throw, the expression evaluation is aborted as well.	No
"	    message is displayed for the cancelled expression evaluation.  On an
"	    error not inside :try/:endtry, the expression evaluation continues.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    let taken = ""

    function! ERR(n)
	let g:taken = g:taken . "E" . a:n
	asdf
    endfunction

    function! ERRabort(n) abort
	let g:taken = g:taken . "A" . a:n
	asdf
    endfunction	" returns -1; may cause follow-up msg for illegal var/func name

    function! WRAP(n, arg)
	let g:taken = g:taken . "W" . a:n
	let g:saved_errmsg = v:errmsg
	return arg
    endfunction

    function! INT(n)
	let g:taken = g:taken . "I" . a:n
	"INTERRUPT9
	let dummy = 0
    endfunction

    function! THR(n)
	let g:taken = g:taken . "T" . a:n
	throw "should not be caught"
    endfunction

    function! CONT(n)
	let g:taken = g:taken . "C" . a:n
    endfunction

    function! MSG(n)
	let g:taken = g:taken . "M" . a:n
	let errmsg = (a:n >= 37 && a:n <= 44) ? g:saved_errmsg : v:errmsg
	let msgptn = (a:n >= 10 && a:n <= 27) ? "^$" : "asdf"
	if errmsg !~ msgptn
	    let g:taken = g:taken . "x"
	    Xout "Expr" a:n.": Unexpected message:" v:errmsg
	endif
	let v:errmsg = ""
	let g:saved_errmsg = ""
    endfunction

    let v:errmsg = ""

    try
	let t = 1
	XloopINIT 1 2
	while t <= 9
	    Xloop 1				" X: 511
	    try
		if t == 1
		    let v{ERR(t) + CONT(t)} = 0
		elseif t == 2
		    let v{ERR(t) + CONT(t)}
		elseif t == 3
		    let var = exists('v{ERR(t) + CONT(t)}')
		elseif t == 4
		    unlet v{ERR(t) + CONT(t)}
		elseif t == 5
		    function F{ERR(t) + CONT(t)}()
		    endfunction
		elseif t == 6
		    function F{ERR(t) + CONT(t)}
		elseif t == 7
		    let var = exists('*F{ERR(t) + CONT(t)}')
		elseif t == 8
		    delfunction F{ERR(t) + CONT(t)}
		elseif t == 9
		    let var = ERR(t) + CONT(t)
		endif
	    catch /asdf/
		" v:errmsg is not set when the error message is converted to an
		" exception.  Set it to the original error message.
		let v:errmsg = substitute(v:exception, '^Vim:', '', "")
	    catch /^Vim\((\a\+)\)\=:/
		" An error exception has been thrown after the original error.
		let v:errmsg = ""
	    finally
		call MSG(t)
		let t = t + 1
		XloopNEXT
		continue	" discard an aborting error
	    endtry
	endwhile
    catch /.*/
	Xpath 512				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry

    try
	let t = 10
	XloopINIT 1024 2
	while t <= 18
	    Xloop 1				" X: 1024 * 511
	    try
		if t == 10
		    let v{INT(t) + CONT(t)} = 0
		elseif t == 11
		    let v{INT(t) + CONT(t)}
		elseif t == 12
		    let var = exists('v{INT(t) + CONT(t)}')
		elseif t == 13
		    unlet v{INT(t) + CONT(t)}
		elseif t == 14
		    function F{INT(t) + CONT(t)}()
		    endfunction
		elseif t == 15
		    function F{INT(t) + CONT(t)}
		elseif t == 16
		    let var = exists('*F{INT(t) + CONT(t)}')
		elseif t == 17
		    delfunction F{INT(t) + CONT(t)}
		elseif t == 18
		    let var = INT(t) + CONT(t)
		endif
	    catch /^Vim\((\a\+)\)\=:\(Interrupt\)\@!/
		" An error exception has been triggered after the interrupt.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
	    finally
		call MSG(t)
		let t = t + 1
		XloopNEXT
		continue	" discard interrupt
	    endtry
	endwhile
    catch /.*/
	Xpath 524288				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry

    try
	let t = 19
	XloopINIT 1048576 2
	while t <= 27
	    Xloop 1				" X: 1048576 * 511
	    try
		if t == 19
		    let v{THR(t) + CONT(t)} = 0
		elseif t == 20
		    let v{THR(t) + CONT(t)}
		elseif t == 21
		    let var = exists('v{THR(t) + CONT(t)}')
		elseif t == 22
		    unlet v{THR(t) + CONT(t)}
		elseif t == 23
		    function F{THR(t) + CONT(t)}()
		    endfunction
		elseif t == 24
		    function F{THR(t) + CONT(t)}
		elseif t == 25
		    let var = exists('*F{THR(t) + CONT(t)}')
		elseif t == 26
		    delfunction F{THR(t) + CONT(t)}
		elseif t == 27
		    let var = THR(t) + CONT(t)
		endif
	    catch /^Vim\((\a\+)\)\=:/
		" An error exception has been triggered after the :throw.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
	    finally
		call MSG(t)
		let t = t + 1
		XloopNEXT
		continue	" discard exception
	    endtry
	endwhile
    catch /.*/
	Xpath 536870912				" X: 0
	Xout v:exception "in" ExtraVimThrowpoint()
    endtry

    let v{ERR(28) + CONT(28)} = 0
    call MSG(28)
    let v{ERR(29) + CONT(29)}
    call MSG(29)
    let var = exists('v{ERR(30) + CONT(30)}')
    call MSG(30)
    unlet v{ERR(31) + CONT(31)}
    call MSG(31)
    function F{ERR(32) + CONT(32)}()
    endfunction
    call MSG(32)
    function F{ERR(33) + CONT(33)}
    call MSG(33)
    let var = exists('*F{ERR(34) + CONT(34)}')
    call MSG(34)
    delfunction F{ERR(35) + CONT(35)}
    call MSG(35)
    let var = ERR(36) + CONT(36)
    call MSG(36)

    let saved_errmsg = ""

    let v{WRAP(37, ERRabort(37)) + CONT(37)} = 0
    call MSG(37)
    let v{WRAP(38, ERRabort(38)) + CONT(38)}
    call MSG(38)
    let var = exists('v{WRAP(39, ERRabort(39)) + CONT(39)}')
    call MSG(39)
    unlet v{WRAP(40, ERRabort(40)) + CONT(40)}
    call MSG(40)
    function F{WRAP(41, ERRabort(41)) + CONT(41)}()
    endfunction
    call MSG(41)
    function F{WRAP(42, ERRabort(42)) + CONT(42)}
    call MSG(42)
    let var = exists('*F{WRAP(43, ERRabort(43)) + CONT(43)}')
    call MSG(43)
    delfunction F{WRAP(44, ERRabort(44)) + CONT(44)}
    call MSG(44)
    let var = ERRabort(45) + CONT(45)
    call MSG(45)

    Xpath 1073741824				" X: 1073741824

    let expected = ""
	\ . "E1M1E2M2E3M3E4M4E5M5E6M6E7M7E8M8E9M9"
	\ . "I10M10I11M11I12M12I13M13I14M14I15M15I16M16I17M17I18M18"
	\ . "T19M19T20M20T21M21T22M22T23M23T24M24T25M25T26M26T27M27"
	\ . "E28C28M28E29C29M29E30C30M30E31C31M31E32C32M32E33C33M33"
	\ . "E34C34M34E35C35M35E36C36M36"
	\ . "A37W37C37M37A38W38C38M38A39W39C39M39A40W40C40M40A41W41C41M41"
	\ . "A42W42C42M42A43W43C43M43A44W44C44M44A45C45M45"

    if taken != expected
	" The Xpath command does not accept 2^31 (negative); display explicitly:
	exec "!echo 2147483648 >>" . g:ExtraVimResult
						" X: 0
	Xout "'taken' is" taken "instead of" expected
	if substitute(taken,
	\ '\(.*\)E3C3M3x\(.*\)E30C30M30x\(.*\)A39C39M39x\(.*\)',
	\ '\1E3M3\2E30C30M30\3A39C39M39\4',
	\ "") == expected
	    Xout "Is ++emsg_skip for var with expr_start non-NULL"
		\ "in f_exists ok?"
	endif
    endif

    unlet! v var saved_errmsg taken expected
    call delete(WA_t5)
    call delete(WA_t14)
    call delete(WA_t23)
    unlet! WA_t5 WA_t14 WA_t23
    delfunction WA_t5
    delfunction WA_t14
    delfunction WA_t23

endif

Xcheck 1610087935


"-------------------------------------------------------------------------------
" Test 77:  Errors, interrupts, :throw in name{brace-expression}	    {{{1
"
"	    When a function call made during evaluation of an expression in
"	    braces as part of a function name after ":function" is aborted due
"	    to an error inside a :try/:endtry region or due to an interrupt or
"	    a :throw, the expression evaluation is aborted as well, and the
"	    function definition is ignored, skipping all commands to the
"	    ":endfunction".  On an error not inside :try/:endtry, the expression
"	    evaluation continues and the function gets defined, and can be
"	    called and deleted.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT 1 4

function! ERR() abort
    Xloop 1					" X: 1 + 4 + 16 + 64
    asdf
endfunction		" returns -1

function! OK()
    Xloop 2					" X: 2 * (1 + 4 + 16)
    let v:errmsg = ""
    return 0
endfunction

let v:errmsg = ""

Xpath 4096					" X: 4096
function! F{1 + ERR() + OK()}(arg)
    " F0 should be defined.
    if exists("a:arg") && a:arg == "calling"
	Xpath 8192				" X: 8192
    else
	Xpath 16384				" X: 0
    endif
endfunction
if v:errmsg != ""
    Xpath 32768					" X: 0
endif
XloopNEXT

Xpath 65536					" X: 65536
call F{1 + ERR() + OK()}("calling")
if v:errmsg != ""
    Xpath 131072				" X: 0
endif
XloopNEXT

Xpath 262144					" X: 262144
delfunction F{1 + ERR() + OK()}
if v:errmsg != ""
    Xpath 524288				" X: 0
endif
XloopNEXT

try
    while 1
	let caught = 0
	try
	    Xpath 1048576			" X: 1048576
	    function! G{1 + ERR() + OK()}(arg)
		" G0 should not be defined, and the function body should be
		" skipped.
		if exists("a:arg") && a:arg == "calling"
		    Xpath 2097152		" X: 0
		else
		    Xpath 4194304		" X: 0
		endif
		" Use an unmatched ":finally" to check whether the body is
		" skipped when an error occurs in ERR().  This works whether or
		" not the exception is converted to an exception.
		finally
		    Xpath 8388608		" X: 0
		    Xout "Body of G{1 + ERR() + OK()}() not skipped"
		    " Discard the aborting error or exception, and break the
		    " while loop.
		    break
		" End the try conditional and start a new one to avoid
		" ":catch after :finally" errors.
		endtry
		try
		Xpath 16777216			" X: 0
	    endfunction

	    " When the function was not defined, this won't be reached - whether
	    " the body was skipped or not.  When the function was defined, it
	    " can be called and deleted here.
	    Xpath 33554432			" X: 0
	    Xout "G0() has been defined"
	    XloopNEXT
	    try
		call G{1 + ERR() + OK()}("calling")
	    catch /.*/
		Xpath 67108864			" X: 0
	    endtry
	    Xpath 134217728			" X: 0
	    XloopNEXT
	    try
		delfunction G{1 + ERR() + OK()}
	    catch /.*/
		Xpath 268435456			" X: 0
	    endtry
	catch /asdf/
	    " Jumped to when the function is not defined and the body is
	    " skipped.
	    let caught = 1
	catch /.*/
	    Xpath 536870912			" X: 0
	finally
	    if !caught && !$VIMNOERRTHROW
		Xpath 1073741824		" X: 0
	    endif
	    break		" discard error for $VIMNOERRTHROW
	endtry			" jumped to when the body is not skipped
    endwhile
catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout "Body of G{1 + ERR() + OK()}() not skipped, exception caught"
    Xout v:exception "in" v:throwpoint
endtry

Xcheck 1388671


"-------------------------------------------------------------------------------
" Test 78:  Messages on parsing errors in expression evaluation		    {{{1
"
"	    When an expression evaluation detects a parsing error, an error
"	    message is given and converted to an exception, and the expression
"	    evaluation is aborted.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    let taken = ""

    function! F(n)
	let g:taken = g:taken . "F" . a:n
    endfunction

    function! MSG(n, enr, emsg)
	let g:taken = g:taken . "M" . a:n
	let english = v:lang == "C" || v:lang =~ '^[Ee]n'
	if a:enr == ""
	    Xout "TODO: Add message number for:" a:emsg
	    let v:errmsg = ":" . v:errmsg
	endif
	if v:errmsg !~ '^'.a:enr.':' || (english && v:errmsg !~ a:emsg)
	    if v:errmsg == ""
		Xout "Expr" a:n.": Message missing."
		let g:taken = g:taken . "x"
	    else
		let v:errmsg = escape(v:errmsg, '"')
		Xout "Expr" a:n.": Unexpected message:" v:errmsg
		Xout "Expected: " . a:enr . ': ' . a:emsg
		let g:taken = g:taken . "X"
	    endif
	endif
    endfunction

    function! CONT(n)
	let g:taken = g:taken . "C" . a:n
    endfunction

    let v:errmsg = ""
    XloopINIT 1 2

    try
	let t = 1
	while t <= 14
	    let g:taken = g:taken . "T" . t
	    let v:errmsg = ""
	    try
		let caught = 0
		if t == 1
		    let v{novar + CONT(t)} = 0
		elseif t == 2
		    let v{novar + CONT(t)}
		elseif t == 3
		    let var = exists('v{novar + CONT(t)}')
		elseif t == 4
		    unlet v{novar + CONT(t)}
		elseif t == 5
		    function F{novar + CONT(t)}()
		    endfunction
		elseif t == 6
		    function F{novar + CONT(t)}
		elseif t == 7
		    let var = exists('*F{novar + CONT(t)}')
		elseif t == 8
		    delfunction F{novar + CONT(t)}
		elseif t == 9
		    echo novar + CONT(t)
		elseif t == 10
		    echo v{novar + CONT(t)}
		elseif t == 11
		    echo F{novar + CONT(t)}
		elseif t == 12
		    let var = novar + CONT(t)
		elseif t == 13
		    let var = v{novar + CONT(t)}
		elseif t == 14
		    let var = F{novar + CONT(t)}()
		endif
	    catch /^Vim\((\a\+)\)\=:/
		" v:errmsg is not set when the error message is converted to an
		" exception.  Set it to the original error message.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
		let caught = 1
	    finally
		if t <= 8 && t != 3 && t != 7
		    call MSG(t, 'E475', 'Invalid argument\>')
		else
		    if !caught	" no error exceptions ($VIMNOERRTHROW set)
			call MSG(t, 'E15', "Invalid expression")
		    else
			call MSG(t, 'E121', "Undefined variable")
		    endif
		endif
		let t = t + 1
		XloopNEXT
		continue	" discard an aborting error
	    endtry
	endwhile
    catch /.*/
	Xloop 1					" X: 0
	Xout t.":" v:exception "in" ExtraVimThrowpoint()
    endtry

    function! T(n, expr, enr, emsg)
	try
	    let g:taken = g:taken . "T" . a:n
	    let v:errmsg = ""
	    try
		let caught = 0
		execute "let var = " . a:expr
	    catch /^Vim\((\a\+)\)\=:/
		" v:errmsg is not set when the error message is converted to an
		" exception.  Set it to the original error message.
		let v:errmsg = substitute(v:exception,
		    \ '^Vim\((\a\+)\)\=:', '', "")
		let caught = 1
	    finally
		if !caught	" no error exceptions ($VIMNOERRTHROW set)
		    call MSG(a:n, 'E15', "Invalid expression")
		else
		    call MSG(a:n, a:enr, a:emsg)
		endif
		XloopNEXT
		" Discard an aborting error:
		return
	    endtry
	catch /.*/
	    Xloop 1				" X: 0
	    Xout a:n.":" v:exception "in" ExtraVimThrowpoint()
	endtry
    endfunction

    call T(15, 'Nofunc() + CONT(15)',	'E117',	"Unknown function")
    call T(16, 'F(1 2 + CONT(16))',	'E116',	"Invalid arguments")
    call T(17, 'F(1, 2) + CONT(17)',	'E118',	"Too many arguments")
    call T(18, 'F() + CONT(18)',	'E119',	"Not enough arguments")
    call T(19, '{(1} + CONT(19)',	'E110',	"Missing ')'")
    call T(20, '("abc"[1) + CONT(20)',	'E111',	"Missing ']'")
    call T(21, '(1 +) + CONT(21)',	'E15',	"Invalid expression")
    call T(22, '1 2 + CONT(22)',	'E15',	"Invalid expression")
    call T(23, '(1 ? 2) + CONT(23)',	'E109',	"Missing ':' after '?'")
    call T(24, '("abc) + CONT(24)',	'E114',	"Missing quote")
    call T(25, "('abc) + CONT(25)",	'E115',	"Missing quote")
    call T(26, '& + CONT(26)',		'E112', "Option name missing")
    call T(27, '&asdf + CONT(27)',	'E113', "Unknown option")

    Xpath 134217728				" X: 134217728

    let expected = ""
	\ . "T1M1T2M2T3M3T4M4T5M5T6M6T7M7T8M8T9M9T10M10T11M11T12M12T13M13T14M14"
	\ . "T15M15T16M16T17M17T18M18T19M19T20M20T21M21T22M22T23M23T24M24T25M25"
	\ . "T26M26T27M27"

    if taken != expected
	Xpath 268435456				" X: 0
	Xout "'taken' is" taken "instead of" expected
	if substitute(taken, '\(.*\)T3M3x\(.*\)', '\1T3M3\2', "") == expected
	    Xout "Is ++emsg_skip for var with expr_start non-NULL"
		\ "in f_exists ok?"
	endif
    endif

    unlet! var caught taken expected
    call delete(WA_t5)
    unlet! WA_t5
    delfunction WA_t5

endif

Xcheck 134217728


"-------------------------------------------------------------------------------
" Test 79:  Throwing one of several errors for the same command		    {{{1
"
"	    When several errors appear in a row (for instance during expression
"	    evaluation), the first as the most specific one is used when
"	    throwing an error exception.  If, however, a syntax error is
"	    detected afterwards, this one is used for the error exception.
"	    On a syntax error, the next command is not executed, on a normal
"	    error, however, it is (relevant only in a function without the
"	    "abort" flag).  v:errmsg is not set.
"
"	    If throwing error exceptions is configured off, v:errmsg is always
"	    set to the latest error message, that is, to the more general
"	    message or the syntax error, respectively.
"-------------------------------------------------------------------------------

XpathINIT

XloopINIT 1 2

function! NEXT(cmd)
    exec a:cmd . " | Xloop 1"
endfunction

call NEXT('echo novar')				" X: 1 *  1  (checks nextcmd)
XloopNEXT
call NEXT('let novar #')			" X: 0 *  2  (skips nextcmd)
XloopNEXT
call NEXT('unlet novar #')			" X: 0 *  4  (skips nextcmd)
XloopNEXT
call NEXT('let {novar}')			" X: 0 *  8  (skips nextcmd)
XloopNEXT
call NEXT('unlet{ novar}')			" X: 0 * 16  (skips nextcmd)

function! EXEC(cmd)
    exec a:cmd
endfunction

function! MATCH(expected, msg, enr, emsg)
    let msg = a:msg
    if a:enr == ""
	Xout "TODO: Add message number for:" a:emsg
	let msg = ":" . msg
    endif
    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    if msg !~ '^'.a:enr.':' || (english && msg !~ a:emsg)
	let match =  0
	if a:expected		" no match although expected
	    if a:msg == ""
		Xout "Message missing."
	    else
		let msg = escape(msg, '"')
		Xout "Unexpected message:" msg
		Xout "Expected:" a:enr . ": " . a:emsg
	    endif
	endif
    else
	let match =  1
	if !a:expected		" match although not expected
	    let msg = escape(msg, '"')
	    Xout "Unexpected message:" msg
	    Xout "Expected none."
	endif
    endif
    return match
endfunction

try

    while 1				" dummy loop
	try
	    let v:errmsg = ""
	    let caught = 0
	    let thrmsg = ""
	    call EXEC('echo novar')	" normal error
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let thrmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 32				" X: 32
	    if !caught
		if !$VIMNOERRTHROW
		    Xpath 64			" X: 0
		endif
	    elseif !MATCH(1, thrmsg, 'E121', "Undefined variable")
	    \ || v:errmsg != ""
		Xpath 128			" X: 0
	    endif
	    if !caught && !MATCH(1, v:errmsg, 'E15', "Invalid expression")
		Xpath 256			" X: 0
	    endif
	    break			" discard error if $VIMNOERRTHROW == 1
	endtry
    endwhile

    Xpath 512					" X: 512
    let cmd = "let"
    XloopINIT 1024 32
    while cmd != ""
	try
	    let v:errmsg = ""
	    let caught = 0
	    let thrmsg = ""
	    call EXEC(cmd . ' novar #')		" normal plus syntax error
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let thrmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xloop 1				" X: 1024 * (1 + 32)
	    if !caught
		if !$VIMNOERRTHROW
		    Xloop 2			" X: 0
		endif
	    else
		if cmd == "let"
		    let match = MATCH(0, thrmsg, 'E121', "Undefined variable")
		elseif cmd == "unlet"
		    let match = MATCH(0, thrmsg, 'E108', "No such variable")
		endif
		if match					" normal error
		    Xloop 4			" X: 0
		endif
		if !MATCH(1, thrmsg, 'E488', "Trailing characters")
		\|| v:errmsg != ""
								" syntax error
		    Xloop 8			" X: 0
		endif
	    endif
	    if !caught && !MATCH(1, v:errmsg, 'E488', "Trailing characters")
								" last error
		Xloop 16			" X: 0
	    endif
	    if cmd == "let"
		let cmd = "unlet"
	    else
		let cmd = ""
	    endif
	    XloopNEXT
	    continue			" discard error if $VIMNOERRTHROW == 1
	endtry
    endwhile

    Xpath 1048576				" X: 1048576
    let cmd = "let"
    XloopINIT 2097152 32
    while cmd != ""
	try
	    let v:errmsg = ""
	    let caught = 0
	    let thrmsg = ""
	    call EXEC(cmd . ' {novar}')		" normal plus syntax error
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let thrmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xloop 1				" X: 2097152 * (1 + 32)
	    if !caught
		if !$VIMNOERRTHROW
		    Xloop 2			" X: 0
		endif
	    else
		if MATCH(0, thrmsg, 'E121', "Undefined variable") " normal error
		    Xloop 4			" X: 0
		endif
		if !MATCH(1, thrmsg, 'E475', 'Invalid argument\>')
		\ || v:errmsg != ""				  " syntax error
		    Xloop 8			" X: 0
		endif
	    endif
	    if !caught && !MATCH(1, v:errmsg, 'E475', 'Invalid argument\>')
								" last error
		Xloop 16			" X: 0
	    endif
	    if cmd == "let"
		let cmd = "unlet"
	    else
		let cmd = ""
	    endif
	    XloopNEXT
	    continue			" discard error if $VIMNOERRTHROW == 1
	endtry
    endwhile

catch /.*/
    " The Xpath command does not accept 2^31 (negative); add explicitly:
    let Xpath = Xpath + 2147483648		" X: 0
    Xout v:exception "in" v:throwpoint
endtry

unlet! next_command thrmsg match
delfunction NEXT
delfunction EXEC
delfunction MATCH

Xcheck 70288929


"-------------------------------------------------------------------------------
" Test 80:  Syntax error in expression for illegal :elseif		    {{{1
"
"	    If there is a syntax error in the expression after an illegal
"	    :elseif, an error message is given (or an error exception thrown)
"	    for the illegal :elseif rather than the expression error.
"-------------------------------------------------------------------------------

XpathINIT

function! MSG(enr, emsg)
    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    if a:enr == ""
	Xout "TODO: Add message number for:" a:emsg
	let v:errmsg = ":" . v:errmsg
    endif
    let match = 1
    if v:errmsg !~ '^'.a:enr.':' || (english && v:errmsg !~ a:emsg)
	let match = 0
	if v:errmsg == ""
	    Xout "Message missing."
	else
	    let v:errmsg = escape(v:errmsg, '"')
	    Xout "Unexpected message:" v:errmsg
	endif
    endif
    return match
endfunction

let v:errmsg = ""
if 0
else
elseif 1 ||| 2
endif
Xpath 1						" X: 1
if !MSG('E584', ":elseif after :else")
    Xpath 2					" X: 0
endif

let v:errmsg = ""
if 1
else
elseif 1 ||| 2
endif
Xpath 4						" X: 4
if !MSG('E584', ":elseif after :else")
    Xpath 8					" X: 0
endif

let v:errmsg = ""
elseif 1 ||| 2
Xpath 16					" X: 16
if !MSG('E582', ":elseif without :if")
    Xpath 32					" X: 0
endif

let v:errmsg = ""
while 1
    elseif 1 ||| 2
endwhile
Xpath 64					" X: 64
if !MSG('E582', ":elseif without :if")
    Xpath 128					" X: 0
endif

while 1
    try
	try
	    let v:errmsg = ""
	    let caught = 0
	    if 0
	    else
	    elseif 1 ||| 2
	    endif
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 256				" X: 256
	    if !caught && !$VIMNOERRTHROW
		Xpath 512			" X: 0
	    endif
	    if !MSG('E584', ":elseif after :else")
		Xpath 1024			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 2048				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let v:errmsg = ""
	    let caught = 0
	    if 1
	    else
	    elseif 1 ||| 2
	    endif
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 4096				" X: 4096
	    if !caught && !$VIMNOERRTHROW
		Xpath 8192			" X: 0
	    endif
	    if !MSG('E584', ":elseif after :else")
		Xpath 16384			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 32768				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let v:errmsg = ""
	    let caught = 0
	    elseif 1 ||| 2
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 65536				" X: 65536
	    if !caught && !$VIMNOERRTHROW
		Xpath 131072			" X: 0
	    endif
	    if !MSG('E582', ":elseif without :if")
		Xpath 262144			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 524288				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let v:errmsg = ""
	    let caught = 0
	    while 1
		elseif 1 ||| 2
	    endwhile
	catch /^Vim\((\a\+)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((\a\+)\)\=:', '', "")
	finally
	    Xpath 1048576			" X: 1048576
	    if !caught && !$VIMNOERRTHROW
		Xpath 2097152			" X: 0
	    endif
	    if !MSG('E582', ":elseif without :if")
		Xpath 4194304			" X: 0
	    endif
	endtry
    catch /.*/
	Xpath 8388608				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

Xpath 16777216					" X: 16777216

unlet! caught
delfunction MSG

Xcheck 17895765


"-------------------------------------------------------------------------------
" Test 81:  Discarding exceptions after an error or interrupt		    {{{1
"
"	    When an exception is thrown from inside a :try conditional without
"	    :catch and :finally clauses and an error or interrupt occurs before
"	    the :endtry is reached, the exception is discarded.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    try
	Xpath 1					" X: 1
	try
	    Xpath 2				" X: 2
	    throw "arrgh"
	    Xpath 4				" X: 0
"	    if 1
		Xpath 8				" X: 0
	    " error after :throw: missing :endif
	endtry
	Xpath 16				" X: 0
    catch /arrgh/
	Xpath 32				" X: 0
    endtry
    Xpath 64					" X: 0
endif

if ExtraVim()
    try
	Xpath 128				" X: 128
	try
	    Xpath 256				" X: 256
	    throw "arrgh"
	    Xpath 512				" X: 0
	endtry		" INTERRUPT
	Xpath 1024				" X: 0
    catch /arrgh/
	Xpath 2048				" X: 0
    endtry
    Xpath 4096					" X: 0
endif

Xcheck 387


"-------------------------------------------------------------------------------
" Test 82:  Ignoring :catch clauses after an error or interrupt		    {{{1
"
"	    When an exception is thrown and an error or interrupt occurs before
"	    the matching :catch clause is reached, the exception is discarded
"	    and the :catch clause is ignored (also for the error or interrupt
"	    exception being thrown then).
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    try
	try
	    Xpath 1				" X: 1
	    throw "arrgh"
	    Xpath 2				" X: 0
"	    if 1
		Xpath 4				" X: 0
		" error after :throw: missing :endif
	catch /.*/
	    Xpath 8				" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	catch /.*/
	    Xpath 16				" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	endtry
	Xpath 32				" X: 0
    catch /arrgh/
	Xpath 64				" X: 0
    endtry
    Xpath 128					" X: 0
endif

if ExtraVim()
    function! E()
	try
	    try
		Xpath 256			" X: 256
		throw "arrgh"
		Xpath 512			" X: 0
"		if 1
		    Xpath 1024			" X: 0
		    " error after :throw: missing :endif
	    catch /.*/
		Xpath 2048			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    catch /.*/
		Xpath 4096			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    endtry
	    Xpath 8192				" X: 0
	catch /arrgh/
	    Xpath 16384				" X: 0
	endtry
    endfunction

    call E()
    Xpath 32768					" X: 0
endif

if ExtraVim()
    try
	try
	    Xpath 65536				" X: 65536
	    throw "arrgh"
	    Xpath 131072			" X: 0
	catch /.*/	"INTERRUPT
	    Xpath 262144			" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	catch /.*/
	    Xpath 524288			" X: 0
	    Xout v:exception "in" ExtraVimThrowpoint()
	endtry
	Xpath 1048576				" X: 0
    catch /arrgh/
	Xpath 2097152				" X: 0
    endtry
    Xpath 4194304				" X: 0
endif

if ExtraVim()
    function I()
	try
	    try
		Xpath 8388608			" X: 8388608
		throw "arrgh"
		Xpath 16777216			" X: 0
	    catch /.*/	"INTERRUPT
		Xpath 33554432			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    catch /.*/
		Xpath 67108864			" X: 0
		Xout v:exception "in" ExtraVimThrowpoint()
	    endtry
	    Xpath 134217728			" X: 0
	catch /arrgh/
	    Xpath 268435456			" X: 0
	endtry
    endfunction

    call I()
    Xpath 536870912				" X: 0
endif

Xcheck 8454401


"-------------------------------------------------------------------------------
" Test 83:  Executing :finally clauses after an error or interrupt	    {{{1
"
"	    When an exception is thrown and an error or interrupt occurs before
"	    the :finally of the innermost :try is reached, the exception is
"	    discarded and the :finally clause is executed.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()
    try
	Xpath 1					" X: 1
	try
	    Xpath 2				" X: 2
	    throw "arrgh"
	    Xpath 4				" X: 0
"	    if 1
		Xpath 8				" X: 0
	    " error after :throw: missing :endif
	finally
	    Xpath 16				" X: 16
	endtry
	Xpath 32				" X: 0
    catch /arrgh/
	Xpath 64				" X: 0
    endtry
    Xpath 128					" X: 0
endif

if ExtraVim()
    try
	Xpath 256				" X: 256
	try
	    Xpath 512				" X: 512
	    throw "arrgh"
	    Xpath 1024				" X: 0
	finally		"INTERRUPT
	    Xpath 2048				" X: 2048
	endtry
	Xpath 4096				" X: 0
    catch /arrgh/
	Xpath 8192				" X: 0
    endtry
    Xpath 16384					" X: 0
endif

Xcheck 2835


"-------------------------------------------------------------------------------
" Test 84:  Exceptions in autocommand sequences.			    {{{1
"
"	    When an exception occurs in a sequence of autocommands for
"	    a specific event, the rest of the sequence is not executed.  The
"	    command that triggered the autocommand execution aborts, and the
"	    exception is propagated to the caller.
"
"	    For the FuncUndefined event under a function call expression or
"	    :call command, the function is not executed, even when it has
"	    been defined by the autocommands before the exception occurred.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    function! INT()
	"INTERRUPT
	let dummy = 0
    endfunction

    aug TMP
	autocmd!

	autocmd User x1 Xpath 1			" X: 1
	autocmd User x1 throw "x1"
	autocmd User x1 Xpath 2			" X: 0

	autocmd User x2 Xpath 4			" X: 4
	autocmd User x2 asdf
	autocmd User x2 Xpath 8			" X: 0

	autocmd User x3 Xpath 16		" X: 16
	autocmd User x3 call INT()
	autocmd User x3 Xpath 32		" X: 0

	autocmd FuncUndefined U1 function! U1()
	autocmd FuncUndefined U1     Xpath 64	" X: 0
	autocmd FuncUndefined U1 endfunction
	autocmd FuncUndefined U1 Xpath 128	" X: 128
	autocmd FuncUndefined U1 throw "U1"
	autocmd FuncUndefined U1 Xpath 256	" X: 0

	autocmd FuncUndefined U2 function! U2()
	autocmd FuncUndefined U2     Xpath 512	" X: 0
	autocmd FuncUndefined U2 endfunction
	autocmd FuncUndefined U2 Xpath 1024	" X: 1024
	autocmd FuncUndefined U2 ASDF
	autocmd FuncUndefined U2 Xpath 2048	" X: 0

	autocmd FuncUndefined U3 function! U3()
	autocmd FuncUndefined U3     Xpath 4096	" X: 0
	autocmd FuncUndefined U3 endfunction
	autocmd FuncUndefined U3 Xpath 8192	" X: 8192
	autocmd FuncUndefined U3 call INT()
	autocmd FuncUndefined U3 Xpath 16384	" X: 0
    aug END

    try
	try
	    Xpath 32768				" X: 32768
	    doautocmd User x1
	catch /x1/
	    Xpath 65536				" X: 65536
	endtry

	while 1
	    try
		Xpath 131072			" X: 131072
		let caught = 0
		doautocmd User x2
	    catch /asdf/
		let caught = 1
	    finally
		Xpath 262144			" X: 262144
		if !caught && !$VIMNOERRTHROW
		    Xpath 524288		" X: 0
		    " Propagate uncaught error exception,
		else
		    " ... but break loop for caught error exception,
		    " or discard error and break loop if $VIMNOERRTHROW
		    break
		endif
	    endtry
	endwhile

	while 1
	    try
		Xpath 1048576			" X: 1048576
		let caught = 0
		doautocmd User x3
	    catch /Vim:Interrupt/
		let caught = 1
	    finally
		Xpath 2097152			" X: 2097152
		if !caught && !$VIMNOINTTHROW
		    Xpath 4194304		" X: 0
		    " Propagate uncaught interrupt exception,
		else
		    " ... but break loop for caught interrupt exception,
		    " or discard interrupt and break loop if $VIMNOINTTHROW
		    break
		endif
	    endtry
	endwhile

	if exists("*U1") | delfunction U1 | endif
	if exists("*U2") | delfunction U2 | endif
	if exists("*U3") | delfunction U3 | endif

	try
	    Xpath 8388608			" X: 8388608
	    call U1()
	catch /U1/
	    Xpath 16777216			" X: 16777216
	endtry

	while 1
	    try
		Xpath 33554432			" X: 33554432
		let caught = 0
		call U2()
	    catch /ASDF/
		let caught = 1
	    finally
		Xpath 67108864			" X: 67108864
		if !caught && !$VIMNOERRTHROW
		    Xpath 134217728		" X: 0
		    " Propagate uncaught error exception,
		else
		    " ... but break loop for caught error exception,
		    " or discard error and break loop if $VIMNOERRTHROW
		    break
		endif
	    endtry
	endwhile

	while 1
	    try
		Xpath 268435456			" X: 268435456
		let caught = 0
		call U3()
	    catch /Vim:Interrupt/
		let caught = 1
	    finally
		Xpath 536870912			" X: 536870912
		if !caught && !$VIMNOINTTHROW
		    Xpath 1073741824		" X: 0
		    " Propagate uncaught interrupt exception,
		else
		    " ... but break loop for caught interrupt exception,
		    " or discard interrupt and break loop if $VIMNOINTTHROW
		    break
		endif
	    endtry
	endwhile
    catch /.*/
	" The Xpath command does not accept 2^31 (negative); display explicitly:
	exec "!echo 2147483648 >>" . g:ExtraVimResult
	Xout "Caught" v:exception "in" v:throwpoint
    endtry

    unlet caught
    delfunction INT
    delfunction U1
    delfunction U2
    delfunction U3
    au! TMP
    aug! TMP
endif

Xcheck 934782101


"-------------------------------------------------------------------------------
" Test 85:  Error exceptions in autocommands for I/O command events	    {{{1
"
"	    When an I/O command is inside :try/:endtry, autocommands to be
"	    executed after it should be skipped on an error (exception) in the
"	    command itself or in autocommands to be executed before the command.
"	    In the latter case, the I/O command should not be executed either.
"	    Example 1: BufWritePre, :write, BufWritePost
"	    Example 2: FileReadPre, :read, FileReadPost.
"-------------------------------------------------------------------------------

XpathINIT

function! MSG(enr, emsg)
    let english = v:lang == "C" || v:lang =~ '^[Ee]n'
    if a:enr == ""
	Xout "TODO: Add message number for:" a:emsg
	let v:errmsg = ":" . v:errmsg
    endif
    let match = 1
    if v:errmsg !~ '^'.a:enr.':' || (english && v:errmsg !~ a:emsg)
	let match = 0
	if v:errmsg == ""
	    Xout "Message missing."
	else
	    let v:errmsg = escape(v:errmsg, '"')
	    Xout "Unexpected message:" v:errmsg
	endif
    endif
    return match
endfunction

" Remove the autocommands for the events specified as arguments in all used
" autogroups.
function Delete_autocommands(...)
    let augfile = tempname()
    while 1
	try
	    exec "redir >" . augfile
	    aug
	    redir END
	    exec "edit" augfile
	    g/^$/d
	    norm G$
	    let wrap = "w"
	    while search('\%(  \|^\)\@<=.\{-}\%(  \)\@=', wrap) > 0
		let wrap = "W"
		exec "norm y/  \n"
		let argno = 1
		while argno <= a:0
		    exec "au!" escape(@", " ") a:{argno}
		    let argno = argno + 1
		endwhile
	    endwhile
	catch /.*/
	finally
	    bwipeout!
	    call delete(augfile)
	    break		" discard errors for $VIMNOERRTHROW
	endtry
    endwhile
endfunction

call Delete_autocommands("BufWritePre", "BufWritePost")

while 1
    try
	try
	    let post = 0
	    aug TMP
		au! BufWritePost * let post = 1
	    aug END
	    let caught = 0
	    write /n/o/n/e/x/i/s/t/e/n/t
	catch /^Vim(write):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(write):', '', "")
	finally
	    Xpath 1				" X: 1
	    if !caught && !$VIMNOERRTHROW
		Xpath 2				" X: 0
	    endif
	    let v:errmsg = substitute(v:errmsg, '^"/n/o/n/e/x/i/s/t/e/n/t" ',
		\ '', "")
	    if !MSG('E212', "Can't open file for writing")
		Xpath 4				" X: 0
	    endif
	    if post
		Xpath 8				" X: 0
		Xout "BufWritePost commands executed after write error"
	    endif
	    au! TMP
	    aug! TMP
	endtry
    catch /.*/
	Xpath 16				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	try
	    let post = 0
	    aug TMP
		au! BufWritePre  * asdf
		au! BufWritePost * let post = 1
	    aug END
	    let tmpfile = tempname()
	    let caught = 0
	    exec "write" tmpfile
	catch /^Vim\((write)\)\=:/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim\((write)\)\=:', '', "")
	finally
	    Xpath 32				" X: 32
	    if !caught && !$VIMNOERRTHROW
		Xpath 64			" X: 0
	    endif
	    let v:errmsg = substitute(v:errmsg, '^"'.tmpfile.'" ', '', "")
	    if !MSG('E492', "Not an editor command")
		Xpath 128			" X: 0
	    endif
	    if filereadable(tmpfile)
		Xpath 256			" X: 0
		Xout ":write command not suppressed after BufWritePre error"
	    endif
	    if post
		Xpath 512			" X: 0
		Xout "BufWritePost commands executed after BufWritePre error"
	    endif
	    au! TMP
	    aug! TMP
	endtry
    catch /.*/
	Xpath 1024				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

call delete(tmpfile)

call Delete_autocommands("BufWritePre", "BufWritePost",
    \ "BufReadPre", "BufReadPost", "FileReadPre", "FileReadPost")

while 1
    try
	try
	    let post = 0
	    aug TMP
		au! FileReadPost * let post = 1
	    aug END
	    let caught = 0
	    read /n/o/n/e/x/i/s/t/e/n/t
	catch /^Vim(read):/
	    let caught = 1
	    let v:errmsg = substitute(v:exception, '^Vim(read):', '', "")
	finally
	    Xpath 2048				" X: 2048
	    if !caught && !$VIMNOERRTHROW
		Xpath 4096			" X: 0
	    endif
	    let v:errmsg = substitute(v:errmsg, ' /n/o/n/e/x/i/s/t/e/n/t$',
		\ '', "")
	    if !MSG('E484', "Can't open file")
		Xpath 8192			" X: 0
	    endif
	    if post
		Xpath 16384			" X: 0
		Xout "FileReadPost commands executed after write error"
	    endif
	    au! TMP
	    aug! TMP
	endtry
    catch /.*/
	Xpath 32768				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

while 1
    try
	let infile = tempname()
	let tmpfile = tempname()
	exec "!echo XYZ >" . infile
	exec "edit" tmpfile
	try
	    Xpath 65536				" X: 65536
	    try
		let post = 0
		aug TMP
		    au! FileReadPre  * asdf
		    au! FileReadPost * let post = 1
		aug END
		let caught = 0
		exec "0read" infile
	    catch /^Vim\((read)\)\=:/
		let caught = 1
		let v:errmsg = substitute(v:exception, '^Vim\((read)\)\=:', '',
		    \ "")
	    finally
		Xpath 131072			" X: 131072
		if !caught && !$VIMNOERRTHROW
		    Xpath 262144		" X: 0
		endif
		let v:errmsg = substitute(v:errmsg, ' '.infile.'$', '', "")
		if !MSG('E492', "Not an editor command")
		    Xpath 524288		" X: 0
		endif
		if getline("1") == "XYZ"
		    Xpath 1048576		" X: 0
		    Xout ":read command not suppressed after FileReadPre error"
		endif
		if post
		    Xpath 2097152		" X: 0
		    Xout "FileReadPost commands executed after " .
			\ "FileReadPre error"
		endif
		au! TMP
		aug! TMP
	    endtry
	finally
	    bwipeout!
	endtry
    catch /.*/
	Xpath 4194304				" X: 0
	Xout v:exception "in" v:throwpoint
    finally
	break		" discard error for $VIMNOERRTHROW
    endtry
endwhile

call delete(infile)
call delete(tmpfile)
unlet! caught post infile tmpfile
delfunction MSG
delfunction Delete_autocommands

Xcheck 198689

"-------------------------------------------------------------------------------
" Test 86:  setloclist crash						    {{{1
"
"	    Executing a setloclist() on BufUnload shouldn't crash Vim
"-------------------------------------------------------------------------------

func F
    au BufUnload * :call setloclist(0, [{'bufnr':1, 'lnum':1, 'col':1, 'text': 'tango down'}])

    :lvimgrep /.*/ *.mak
endfunc

XpathINIT

ExecAsScript F

delfunction F
Xout  "No Crash for vimgrep on BufUnload"
Xcheck 0 

" Test 87 was moved to test_vimscript.vim
let Xtest = 88


"-------------------------------------------------------------------------------
" Test 88:  $VIMNOERRTHROW and $VIMNOINTTHROW support			    {{{1
"
"	    It is possible to configure Vim for throwing exceptions on error
"	    or interrupt, controlled by variables $VIMNOERRTHROW and
"	    $VIMNOINTTHROW.  This is just for increasing the number of tests.
"	    All tests here should run for all four combinations of setting
"	    these variables to 0 or 1.  The variables are intended for the
"	    development phase only.  In the final release, Vim should be
"	    configured to always use error and interrupt exceptions.
"
"	    The test result is "OK",
"
"		- if the $VIMNOERRTHROW and the $VIMNOINTTHROW control are not
"		  configured and exceptions are thrown on error and on
"		  interrupt.
"
"		- if the $VIMNOERRTHROW or the $VIMNOINTTHROW control is
"		  configured and works as intended.
"
"	    What actually happens, is shown in the test output.
"
"	    Otherwise, the test result is "FAIL", and the test output describes
"	    the problem.
"
" IMPORTANT:  This must be the last test because it sets $VIMNOERRTHROW and
"	      $VIMNOINTTHROW.
"-------------------------------------------------------------------------------

XpathINIT

if ExtraVim()

    function! ThrowOnError()
	XloopNEXT
	let caught = 0
	try
	    Xloop 1				" X: 1 + 8 + 64
	    asdf
	catch /.*/
	    let caught = 1	" error exception caught
	finally
	    Xloop 2				" X: 2 + 16 + 128
	    return caught	" discard aborting error
	endtry
	Xloop 4					" X: 0
    endfunction

    let quits_skipped = 0

    function! ThrowOnInterrupt()
	XloopNEXT
	let caught = 0
	try
	    Xloop 1				" X: (1 + 8 + 64) * 512
	    "INTERRUPT3
	    let dummy = 0
	    let g:quits_skipped = g:quits_skipped + 1
	catch /.*/
	    let caught = 1	" interrupt exception caught
	finally
	    Xloop 2				" X: (2 + 16 + 128) * 512
	    return caught	" discard interrupt
	endtry
	Xloop 4					" X: 0
    endfunction

    function! CheckThrow(Type)
	execute 'return ThrowOn' . a:Type . '()'
    endfunction

    function! CheckConfiguration(type)	    " type is "error" or "interrupt"

	let type = a:type
	let Type = substitute(type, '.*', '\u&', "")
	let VAR = '$VIMNO' . substitute(type, '\(...\).*', '\U\1', "") . 'THROW'

	if type == "error"
	    XloopINIT! 1 8
	elseif type == "interrupt"
	    XloopINIT! 512 8
	endif

	exec 'let requested_for_tests = exists(VAR) && ' . VAR . ' == 0'
	exec 'let suppressed_for_tests = ' . VAR . ' != 0'
	let used_in_tests = CheckThrow(Type)

	exec 'let ' . VAR . ' = 0'
	let request_works = CheckThrow(Type)

	exec 'let ' . VAR . ' = 1'
	let suppress_works = !CheckThrow(Type)

	if type == "error"
	    XloopINIT! 262144 8
	elseif type == "interrupt"
	    XloopINIT! 2097152 8

	    if g:quits_skipped != 0
		Xloop 1				" X: 0*2097152
		Xout "Test environment error.  Interrupt breakpoints skipped: "
		    \ . g:quits_skipped . ".\n"
		    \ . "Cannot check whether interrupt exceptions are thrown."
		return
	    endif
	endif

	let failure =
	    \ !suppressed_for_tests && !used_in_tests
	    \ || !request_works

	let contradiction =
	    \ used_in_tests
		\ ? suppressed_for_tests && !request_works
		\ : !suppressed_for_tests

	if failure
	    " Failure in configuration.
	    Xloop 2				" X: 0 * 2*  (262144 + 2097152)
	elseif contradiction
	    " Failure in test logic.  Should not happen.
	    Xloop 4				" X: 0 * 4 * (262144 + 2097152)
	endif

	let var_control_configured =
	    \ request_works != used_in_tests
	    \ || suppress_works == used_in_tests

	let var_control_not_configured =
	    \ requested_for_tests || suppressed_for_tests
		\ ? request_works && !suppress_works
		\ : request_works == used_in_tests
		    \ && suppress_works != used_in_tests

	let with = used_in_tests ? "with" : "without"

	let set = suppressed_for_tests ? "non-zero" :
	    \ requested_for_tests ? "0" : "unset"

	let although = contradiction && !var_control_not_configured
	    \ ? ",\nalthough "
	    \ : ".\n"

	let output = "All tests were run " . with . " throwing exceptions on "
	    \ . type . although

	if !var_control_not_configured
	    let output = output . VAR . " was " . set . "."

	    if !request_works && !requested_for_tests
		let output = output .
		    \ "\n" . Type . " exceptions are not thrown when " . VAR .
		    \ " is\nset to 0."
	    endif

	    if !suppress_works && (!used_in_tests ||
	    \ !request_works &&
	    \ !requested_for_tests && !suppressed_for_tests)
		let output = output .
		    \ "\n" . Type . " exceptions are thrown when " . VAR .
		    \ " is set to 1."
	    endif

	    if !failure && var_control_configured
		let output = output .
		    \ "\nRun tests also with " . substitute(VAR, '^\$', '', "")
		    \ . "=" . used_in_tests . "."
		    \ . "\nThis is for testing in the development phase only."
		    \ . "  Remove the \n"
		    \ . VAR . " control in the final release."
	    endif
	else
	    let output = output .
		\ "The " . VAR . " control is not configured."
	endif

	Xout output
    endfunction

    call CheckConfiguration("error")
    Xpath 16777216				" X: 16777216
    call CheckConfiguration("interrupt")
    Xpath 33554432				" X: 33554432
endif

Xcheck 50443995

" IMPORTANT: No test should be added after this test because it changes
"	     $VIMNOERRTHROW and $VIMNOINTTHROW.


"-------------------------------------------------------------------------------
" Modelines								    {{{1
" vim: ts=8 sw=4 tw=80 fdm=marker
"-------------------------------------------------------------------------------
