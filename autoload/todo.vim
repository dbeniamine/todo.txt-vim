" File:        autoload/todo.vim
" Description: Todo.txt sorting plugin
" Author:      David Beniamine <david@beniamine.net>, Peter (fretep) <githib.5678@9ox.net>
" Licence:     Vim licence
" Website:     http://github.com/dbeniamine/todo.txt.vim

" These two variables are parameters for the successive calls the vim sort
"   '' means no flags
"   '! i' means reverse and ignore case
"   for more information on flags, see :help sort
if (! exists("g:Todo_txt_first_level_sort_mode"))
    let g:Todo_txt_first_level_sort_mode='i'
endif
if (! exists("g:Todo_txt_second_level_sort_mode"))
    let g:Todo_txt_second_level_sort_mode='i'
endif
if (! exists("g:Todo_txt_third_level_sort_mode"))
    let g:Todo_txt_third_level_sort_mode='i'
endif


" Functions {{{1


function! todo#GetCurpos()
    if exists("*getcurpos")
        return getcurpos()
    endif
        return getpos('.')
endfunction

function! todo#PrioritizeIncrease()
    normal! 0f)h
endfunction

function! todo#PrioritizeDecrease()
    normal! 0f)h
endfunction

function! todo#PrioritizeAdd (priority)
    let oldpos=todo#GetCurpos()
    let line=getline('.')
    if line !~ '^([A-F])'
        :call todo#PrioritizeAddAction(a:priority)
        let oldpos[2]+=4
    else
        exec ':s/^([A-F])/('.a:priority.')/'
    endif
    call setpos('.',oldpos)
endfunction

function! todo#PrioritizeAddAction (priority)
    execute "normal! mq0i(".a:priority.") \<esc>`q"
endfunction

function! todo#RemovePriority()
    :s/^(\w)\s\+//ge
endfunction

function! todo#PrependDate()
    if (getline(".") =~ '\v^\(')
        execute "normal! 0f)a\<space>\<esc>l\"=strftime(\"%Y-%m-%d\")\<esc>P"
    else
        normal! I=strftime("%Y-%m-%d ")
    endif
endfunction

function todo#SaveRegisters()
    let s:last_search=@/
endfunction

function todo#RestoreRegisters()
    let @/=s:last_search
endfunction

function! todo#ToggleMarkAsDone(status)
    call todo#SaveRegisters()
    if (getline(".") =~ '\C^x\s*\d\{4\}')
        :call todo#UnMarkAsDone(a:status)
    else
        :call todo#MarkAsDone(a:status)
    endif
    call todo#RestoreRegisters()
endfunction

function! todo#FixFormat()
    " Remove heading space
    silent! %s/\C^\s*//
    " Remove priority from done tasks
    silent! %s/\C^x (\([A-Z]\)) \(.*\)/x \2 pri:\1/
endfunction

function! todo#UnMarkAsDone(status)
    if a:status==''
        let pat=''
    else
        let pat=' '.a:status
    endif
    exec ':s/\C^x\s*\d\{4}-\d\{1,2}-\d\{1,2}'.pat.'\s*//g'
    silent s/\C\(.*\) pri:\([A-Z]\)/(\2) \1/e
endfunction

function! todo#MarkAsDone(status)
    call todo#CreateNewRecurrence(1)
    if get(g:, 'TodoTxtStripDoneItemPriority', 0)
        exec ':s/\C^(\([A-Z]\))\(.*\)/\2/e'
    else
        exec ':s/\C^(\([A-Z]\))\(.*\)/\2 pri:\1/e'
    endif
    if a:status!=''
        exec 'normal! I'.a:status.' '
    endif
    call todo#PrependDate()
    if (getline(".") =~ '^ ')
        normal! gIx
    else
        normal! Ix 
    endif
endfunction

function! todo#MarkAllAsDone()
    :g!/^x /:call todo#MarkAsDone('')
endfunction

function! s:AppendToFile(file, lines)
    let l:lines = []

    " Place existing tasks in done.txt at the beggining of the list.
    if filereadable(a:file)
        call extend(l:lines, readfile(a:file))
    endif

    " Append new completed tasks to the list.
    call extend(l:lines, a:lines)

    " Write to file.
    call writefile(l:lines, a:file)
endfunction

function! todo#RemoveCompleted()
    " Check if we can write to done.txt before proceeding.
    let l:target_dir = expand('%:p:h')
    if exists("g:TodoTxtForceDoneName")
        let l:done=g:TodoTxtForceDoneName
    else
        let l:done=substitute(substitute(expand('%:t'),'todo','done',''),'Todo','Done','')
    endif
    let l:done_file = l:target_dir.'/'.l:done
    echo "Writing to ".l:done_file
    if !filewritable(l:done_file) && !filewritable(l:target_dir)
        echoerr "Can't write to file '".l:done_file."'"
        return
    endif

    let l:completed = []
    :g/^x /call add(l:completed, getline(line(".")))|d
    call s:AppendToFile(l:done_file, l:completed)
endfunction

function! todo#Sort(type)
    " vim :sort is usually stable
    " we sort first on contexts, then on projects and then on priority
    let g:Todo_fold_char='x'
    let oldcursor=todo#GetCurpos()
    if(a:type != "")
        exec ':sort /.\{-}\ze'.a:type.'/'
    elseif expand('%')=~'[Dd]one.*.txt'
        " FIXME: Put some unit tests around this, and fix case sensitivity if ignorecase is set.
        silent! %s/\(x\s*\d\{4}\)-\(\d\{2}\)-\(\d\{2}\)/\1\2\3/g
        sort n /^x\s*/
        silent! %s/\(x\s*\d\{4}\)\(\d\{2}\)/\1-\2-/g
    else
        silent normal gg
        let l:first=search('^\s*x')
        if  l:first != 0
            sort /^./r
            " at this point done tasks are at the end
            let l:first=search('^\s*x')
            let l:last=search('^\s*x','b')
            let l:diff=l:last-l:first+1
            " Cut the done lines
            execute ':'.l:first.'d a '.l:diff
        endif
        sort /@[a-zA-Z]*/ r
        sort /+[a-zA-Z]*/ r
        sort /\v\([A-Z]\)/ r
        "Now tasks without priority are at beggining, move them to the end
        silent normal gg
        let l:firstP=search('^\s*([A-Z])', 'cn')
        if  l:firstP != 1
            let num=l:firstP-1
            " Sort normal
            execute ':1 d b'.num
            silent normal G"bp
        endif
        if l:first != 0
            silent normal G"ap
            execute ':'.l:first.','.l:last.'sort /@[a-zA-Z]*/ r'
            execute ':'.l:first.','.l:last.'sort /+[a-zA-Z]*/ r'
            execute ':'.l:first.','.l:last.'sort /\v([A-Z])/ r'
        endif
    endif
    call setpos('.', oldcursor)
endfunction

function! todo#SortDue()
    " Check how many lines have a due:date on them
    let l:tasksWithDueDate = 0
    silent! %global/\v\c<due:\d{4}-\d{2}-\d{2}>/let l:tasksWithDueDate += 1
    if l:tasksWithDueDate == 0
        " No tasks with a due:date: No need to modify the buffer at all
        " Also means we don't need to cater for no matches on searches below
        return
    endif
    " FIXME: There is a small chance that due:\d{8} might legitimately exist in the buffer
    " We modify due:yyyy-mm-dd to yyyymmdd which would then mean we would alter the buffer
    " in an unexpected way, altering user data. Not sure how to deal with this at the moment.
    " I'm going to throw an exception, and if this is a problem we can revisit.
    silent %global/\v\c<due:\d{8}>/throw "Text matching 'due:\\d\\{8\\}' exists in the buffer, this function cannot sort your buffer"
    " Turn the due:date from due:yyyy-mm-dd to due:yyyymmdd so we can do a numeric sort
    silent! %substitute/\v<(due:\d{4})\-(\d{2})\-(\d{2})>/\1\2\3/ei
    " Sort all the lines with due: by numeric yyyymmdd, they will end up in ascending order at the bottom of the buffer
    sort in /\v\c<due:\ze\d{8}>/
    " Determine the line number of the first task with a due:date
    let l:firstLineWithDue = line("$") - l:tasksWithDueDate + 1
    " Put the sorted lines at the beginning of the file
    if l:firstLineWithDue > 1
        " ...but only if the whole file didn't get sorted.
        execute "silent " . l:firstLineWithDue . ",$move 0"
    endif
    " Change the due:yyyymmdd back to due:yyyy-mm-dd.
    silent! %substitute/\v<(due:\d{4})(\d{2})(\d{2})>/\1-\2-\3/ei
    silent global/\C^x /move$
    " Let's check a global for a user preference on the cursor position.
    if exists("g:TodoTxtSortDueDateCursorPos")
        if g:TodoTxtSortDueDateCursorPos ==? "top"
            normal gg
        elseif g:TodoTxtSortDueDateCursorPos ==? "lastdue" || g:TodoTxtSortDueDateCursorPos ==? "notoverdue"
            silent normal G
            " Sorry for the crazy RegExp. The next command should put cursor at at the top of the completed tasks,
            " or the bottom of the buffer. This is done by searching backwards for any line not starting with
            " "x " (x, space) which is important to distinguish from "xample task" for instance, which the more
            " simple "^[^x]" would match. More info: ":help /\@!". Be sure to enforce case sensitivity on "x".
            :silent! ?\v\C^(x )@!?+1
            let l:overduePat = todo#GetDateRegexForPastDates()
            let l:lastwrapscan = &wrapscan
            set nowrapscan
            try
                if g:TodoTxtSortDueDateCursorPos ==? "lastdue"
                    " This searches backwards for the last due task
                    :?\v\c<due:\d{4}\-\d{2}\-\d{2}>
                    " Try a forward search in case the last line of the buffer was a due:date task, don't match done
                    " Be sure to enforce case sensitivity on "x" while allowing mixed case on "due:"
                    :silent! /\v\C^(x )@!&.*<[dD][uU][eE]:\d{4}\-\d{2}\-\d{2}>
                elseif g:TodoTxtSortDueDateCursorPos ==? "notoverdue"
                    " This searches backwards for the last overdue task, and positions the cursor on the following line
                    execute ":?\\v\\c<due:" . l:overduePat . ">?+1"
                endif
            catch
                " Might fail if there are no active (or overdue) due:date tasks. Requires nowrapscan
                " This code path always means we want to be at the top of the buffer
                normal gg
            finally
                let &wrapscan = l:lastwrapscan
            endtry
        elseif g:TodoTxtSortDueDateCursorPos ==? "bottom"
            silent normal G
        endif
    else
        " Default: Top of the document
        normal gg
    endif
    " TODO: add time sorting (YYYY-MM-DD HH:MM)
endfunction

" This is a Hierarchical sort designed for todo.txt todo lists, however it
" might be used for other files types
" At the first level, lines are sorted by the word right after the first
" occurence of a:symbol, there must be no space between the symbol and the
" word. At the second level, the same kind of sort is done based on
" a:symbolsub, is a:symbol==' ', the second sort doesn't occurs
" Therefore, according to todo.txt syntaxt, if
"   a:symbol is a '+' it sort by the first project
"   a:symbol is an '@' it sort by the first context
" The last level of sort is done directly on the line, so according to
" todo.txt syntax, it means by priority. This sort is done if and only if the
" las argument is not 0
function! todo#HierarchicalSort(symbol, symbolsub, dolastsort)
    if v:statusmsg =~ '--No lines in buffer--'
        "Empty buffer do nothing
        return
    endif
    let g:Todo_fold_char=a:symbol
    "if the sort modes doesn't start by '!' it must start with a space
    let l:sortmode=Todo_txt_InsertSpaceIfNeeded(g:Todo_txt_first_level_sort_mode)
    let l:sortmodesub=Todo_txt_InsertSpaceIfNeeded(g:Todo_txt_second_level_sort_mode)
    let l:sortmodefinal=Todo_txt_InsertSpaceIfNeeded(g:Todo_txt_third_level_sort_mode)

    " Count the number of lines
    let l:position= todo#GetCurpos()
    execute "silent normal G"
    let l:linecount=getpos(".")[1]
    if(exists("g:Todo_txt_debug"))
        echo "Linescount: ".l:linecount
    endif
    execute "silent normal gg"

    " Get all the groups names
    let l:groups=GetGroups(a:symbol,1,l:linecount)
    if(exists("g:Todo_txt_debug"))
        echo "Groups: "
        echo l:groups
        echo 'execute sort'.l:sortmode.' /.\{-}\ze'.a:symbol.'/'
    endif
    " Sort by groups
    execute 'sort'.l:sortmode.' /.\{-}\ze'.a:symbol.'/'
    for l:g in l:groups
        let l:pat=a:symbol.l:g.'.*$'
        if(exists("g:Todo_txt_debug"))
            echo l:pat
        endif
        normal gg
        " Find the beginning of the group
        let l:groupBegin=search(l:pat,'c')
        " Find the end of the group
        let l:groupEnd=search(l:pat,'b')

        " I'm too lazy to sort groups of one line
        if(l:groupEnd==l:groupBegin)
            continue
        endif
        if a:dolastsort
            if( a:symbolsub!='')
                " Sort by subgroups
                let l:subgroups=GetGroups(a:symbolsub,l:groupBegin,l:groupEnd)
                " Go before the first line of the group
                " Sort the group using the second symbol
                for l:sg in l:subgroups
                    normal gg
                    let l:pat=a:symbol.l:g.'.*'.a:symbolsub.l:sg.'.*$\|'.a:symbolsub.l:sg.'.*'.a:symbol.l:g.'.*$'
                    " Find the beginning of the subgroup
                    let l:subgroupBegin=search(l:pat,'c')
                    " Find the end of the subgroup
                    let l:subgroupEnd=search(l:pat,'b')
                    " Sort by priority
                    execute l:subgroupBegin.','.l:subgroupEnd.'sort'.l:sortmodefinal
                endfor
            else
                " Sort by priority
                if(exists("g:Todo_txt_debug"))
                    echo 'execute '.l:groupBegin.','.l:groupEnd.'sort'.l:sortmodefinal
                endif
                execute l:groupBegin.','.l:groupEnd.'sort'.l:sortmodefinal
            endif
        endif
    endfor
    " Restore the cursor position
    call setpos('.', position)
endfunction

" Returns the list of groups starting by a:symbol between lines a:begin and
" a:end
function! GetGroups(symbol,begin, end)
    let l:curline=a:begin
    let l:groups=[]
    while l:curline <= a:end
        let l:curproj=strpart(matchstr(getline(l:curline),a:symbol.'\S*'),1)
        if l:curproj != "" && index(l:groups,l:curproj) == -1
            let l:groups=add(l:groups , l:curproj)
        endif
        let l:curline += 1
    endwhile
    return l:groups
endfunction

" Insert a space if needed (the first char isn't '!' or ' ') in front of 
" sort parameters
function! Todo_txt_InsertSpaceIfNeeded(str)
    let l:c=strpart(a:str,1,1)
    if( l:c != '!' && l:c !=' ')
        return " ".a:str
    endif
    retur a:str
endfunction

" function todo#CreateNewRecurrence {{{2
function! todo#CreateNewRecurrence(triggerOnNonStrict)
    " Given a line with a rec:timespan, create a new task based off the
    " recurrence and move the recurring tasks due:date to the next occurrence.
    "
    " This is implemented by a few other systems, so we will try to be as
    " compatible as possible with the existing specifications.
    "
    " Other example implementations:
    "   <http://swiftodoapp.com/>
    "   <https://github.com/bram85/todo.txt-tools/wiki/Recurrence>
    "

    let l:currentline = getline('.')

    " Don't operate on complete tasks
    if l:currentline =~# '^x '
        return
    endif

    let l:rec_date_rex = '\v\c(^|\s)rec:(\+)?(\d+)([dwmy])(\s|$)'
    let l:rec_parts = matchlist(l:currentline, l:rec_date_rex)
    " Don't operate on tasks without a valid "rec:" keyword.
    if empty(l:rec_parts)
        " If a "rec:" keyword exists, but it didn't match our expectations, warn
        " the user, and abort whatever is happening otherwise a recurring task
        " might be marked complete without a new recurrence being created.
        if l:currentline =~? '\v\c(^|\s)rec:'
            throw "Recurrence pattern is invalid. Aborting operation."
        endif
        return
    endif

    " Operations like postponing a task should not trigger the task to be
    " duplicated, non-strict mode allows the changing of the due date.
    let l:is_strict = l:rec_parts[2] ==# "+"
    if ! a:triggerOnNonStrict && ! l:is_strict
        return
    endif

    let l:units = str2nr(l:rec_parts[3])
    if l:units < 1
        let l:units = 1
    endif
    let l:unit_type = l:rec_parts[4]
    " If we had a space on both sides of the "rec:" that we are removing, then
    " we need to insert a space, otherwise, not.
    if l:rec_parts[1] ==# ' ' && l:rec_parts[5] ==# ' '
        let l:replace_string = ' '
    else
        let l:replace_string = ''
    endif

    " New task should have the rec: keyword stripped
    let l:newline = substitute(l:currentline, l:rec_date_rex, l:replace_string, '')
    " Insert above current line
    let l:new_task_line_num = line('.')
    if append(l:new_task_line_num - 1, l:newline) != 0
        throw "Failed at append line"
    endif

    " At this point, we need to change the due date of the recurring task.
    " Modes:
    "       Strict mode:        From the existing due date
    "       Non-Strict mode:    From the current date
    " So, we don't need to do anything for strict mode. Non-strict mode requires
    " setting the current date.
    if l:is_strict
        call todo#ChangeDueDate(l:units, l:unit_type, '')
    else
        call todo#ChangeDueDate(l:units, l:unit_type, strftime('%Y-%m-%d'))
    endif

    " Move onto the copied task
    call cursor(l:new_task_line_num, col('.'))
    if l:new_task_line_num != line('.')
        throw "Failed to move cursor"
    endif
endfunction

" function todo#ChangeDueDate {{{2
function! todo#ChangeDueDate(units, unit_type, from_reference)
    " Change the due:date on the current line by a number of days, months or
    " years
    "
    " units             The number of unit_type to add or subtract, integer
    "                   values only
    " unit_type         May be one of 'd' (days), 'm' (months) or 'y' (years),
    "                   as handled by todo#DateAdd
    " from_reference    Allows passing a different date to base the calculation
    "                   on, ignoring the existing due date in the line. Leave as
    "                   an empty string to use the due:date in the line,
    "                   otherwise a date as a string in the form "YYYY-MM-DD".

    let l:currentline = getline('.')

    " Don't operate on complete tasks
    if l:currentline =~# '^x '
        return
    endif

    let l:dueDateRex = '\v\c(^|\s)due:\zs\d{4}\-\d{2}\-\d{2}\ze(\s|$)'

    let l:duedate = matchstr(l:currentline, l:dueDateRex)
    if l:duedate ==# ''
        " No due date on current line, then add the due date as an offset from
        " current date. I.e. a v:count of 1 is due tomorrow, etc
        if l:currentline =~? '\v\c(^|\s)due:'
            " Has an invalid due: keyword, so don't add another, and don't
            " change the line
            return
        endif
        let l:duedate = strftime('%Y-%m-%d')
        let l:currentline .= ' due:' . l:duedate
    endif
    " If a valid reference has been passed, let's use it.
    if a:from_reference =~# '\v^\d{4}\-\d{2}\-\d{2}$'
        let l:duedate = a:from_reference
    endif

    let l:duedate = todo#DateStringAdd(l:duedate, v:count1 * a:units, a:unit_type)

    if setline('.', substitute(l:currentline, l:dueDateRex, l:duedate, '')) != 0
        throw "Failed to set line"
    endif
endfunction "}}}

" General date calculation functions {{{1

" function todo#GetDaysInMonth {{{2
function! todo#GetDaysInMonth(month, year)
    " Given a month and year, returns the number of days in the month, taking
    " leap years into consideration.

    if index([1, 3, 5, 7, 8, 10, 12], a:month) >= 0
        return 31
    elseif index([4, 6, 9, 11], a:month) >= 0
        return 30
    else
        " February, leap year fun.
        if a:year % 4 != 0
            return 28
        elseif a:year % 100 != 0
            return 29
        elseif a:year % 400 != 0
            return 28
        else
            return 29
        endif
    endif
endfunction

" function todo#DateAdd {{{2
function! todo#DateAdd(year, month, day, units, unit_type)
    " Add or subtract days, months or years from a date
    "
    " Date must be passed in components of year, month and day, all integers
    " units is the number of unit_type to add or subtract, integer values only
    " unit_type may be one of:
    "   d       days
    "   w       weeks, 7 days
    "   m       months, keeps the day of the month static except in the case
    "           that the day is the last day in the month or the day is higher
    "           than the number of days in the resultant month, where the result
    "           will stick to the end of the month. Examples:
    "               2017-01-15 +1m 2017-02-15 +1m 2017-03-15 +1m 2017-04-15
    "               2017-01-31 +1m 2017-02-28 +1m 2017-03-31 +1m 2017-04-30
    "               2017-01-30 +1m 2017-02-28 +1m 2017-03-31
    "               2017-01-30 +2m 2017-03-30
    "   y       years, 12 months


    " It is my understanding that VIM does not have date math functionality
    " built in. Given we only have to deal with dates, and not times, it isn't
    " all that scary to roll our own - we just need to watch out for leap years.

    " Check and clean up input
    if index(["d", "D", "w", "W", "m", "M", "y", "Y"], a:unit_type) < 0
        throw 'Invalid unit "'. a:unit_type . '" passed to todo#DateAdd()'
    endif

    let l:d = str2nr(a:day)
    let l:m = str2nr(a:month)
    let l:y = str2nr(a:year)
    let l:i = str2nr(a:units)

    " Years can be handled simply as 12 x months, weeks as 7 x days
    if a:unit_type ==? "y"
        let l:utype = "m"
        let l:i = l:i * 12
    elseif a:unit_type ==? "w"
        let l:utype = "d"
        let l:i = l:i * 7
    else
        let l:utype = a:unit_type
    endif

    " Check and clean up input
    if l:m < 1
        if l:m == 0
            let l:m = str2nr(strftime('%m'))
        else
            let l:m = 1
        endif
    endif
    if l:m > 12
        if l:i < 0 && l:utype ==? "m"
            " Subtracting an invalid (high) month
            " See comments for passing a high day below. Same reason for this.
            let l:m = 13
        else
            let l:m = 12
        endif
    endif
    if l:y < 1900           " See end of function for rationale
        if l:y == 0
            let l:y = str2nr(strftime('%Y'))
        else
            let l:y = 1900
        endif
    endif

    " Grab number of days in the month specified
    let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)

    " Check and clean up input
    if l:d < 1
        if l:d == 0
            let l:d = str2nr(strftime('%d'))
        else
            let l:d = 1
        endif
    endif
    " Allow passing a high day, this allows subtraction to be more sane when
    " the day is out of bounds, i.e. 2017-04-80 should probably come out as
    " 2017-04-30 not 2017-04-29. Addition deals with days being out of
    " bounds (high) fine, and if days are untouched, out of bounds user
    " input is caught at the end of the function.
    " if l:d > l:daysInMonth
    "     let l:d = l:daysInMonth
    " endif

    if l:utype ==? "d"
        " Adding DAYS
        while l:i > 0
            let l:d += 1
            if l:d > l:daysInMonth
                let l:d = 1
                let l:m += 1
                if l:m > 12
                    let l:m = 1
                    let l:y += 1
                endif
                let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
            endif
            let l:i -= 1
        endwhile
        " Subtracting DAYS
        while l:i < 0
            let l:d -= 1
            if l:d < 1
                let l:m -= 1
                if l:m < 1
                    if l:y > 1900
                        let l:m = 12
                        let l:y -= 1
                    else
                        let l:d = 1
                        let l:m = 1
                        break
                    endif
                endif
                let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
                let l:d = l:daysInMonth
            endif
            let l:i += 1
        endwhile
    elseif l:utype ==? "m"
        if l:d >= l:daysInMonth
            let l:wasLastDayOfMonth = 1
        else
            let l:wasLastDayOfMonth = 0
        endif
        " Adding MONTHS
        while l:i > 0
            let l:m += 1
            if l:m > 12
                let l:m = 1
                let l:y += 1
            endif
            let l:i -= 1
        endwhile
        " Subtracting MONTHS
        while l:i < 0
            let l:m -= 1
            if l:m < 1
                if l:y > 1900
                    let l:m = 12
                    let l:y -= 1
                else
                    let l:m = 1
                endif
            endif
            let l:i += 1
        endwhile
        let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
        if l:wasLastDayOfMonth
            let l:d = l:daysInMonth
        endif
    endif

    " Enforce some limits beyond which, I don't want to support.
    if l:y < 1900
        " Seeing as the date is going to be converted back to a string, dates
        " less that 1000 are bound to cause bugs. Given this is an app for tasks
        " you are doing in the here and now, I'm not supporting way back in the
        " past.
        let l:y = 1900
        let l:daysInMonth = todo#GetDaysInMonth(l:m, l:y)
    endif
    " If we mess with the year (just above), or the user passes a day higher
    " than the month, catch it here.
    if l:d > l:daysInMonth
        let l:d = l:daysInMonth
    endif
    return [l:y, l:m, l:d]
endfunction

" function todo#DateStringAdd {{{2
function! todo#DateStringAdd(date, units, unit_type)
    " A very thin overload of todo#DateAdd() that takes and returns the date as
    " a string rather than in [year, month, day] component form.
    "
    " Date must be passed in "YYYY-MM-DD" format, and is returned in this form
    " also.

    let [l:year, l:month, l:day] = todo#ParseDate(a:date)
    let [l:year, l:month, l:day] = todo#DateAdd(l:year, l:month, l:day, a:units, a:unit_type)
    let l:resulting_date = printf('%04d', l:year) . '-' . printf('%02d', l:month) . '-' . printf('%02d', l:day)
    return l:resulting_date
endfunction

" function todo#ParseDate {{{2
function! todo#ParseDate(datestring)
    " Given a date as a string in the format "YYYY-MM-DD", split the date into a
    " list [year, month, day]
    "
    " Does not check if the date is valid other than being digits. Will throw an
    " exception if the text does not match the expected date format.

    if a:datestring !~? '\v^(\d{4})\-(\d{2})\-(\d{2})$'
        throw "Invalid date passed '" . a:datestring . "'."
    endif
    let l:year = str2nr(strpart(a:datestring, 0, 4))
    let l:month = str2nr(strpart(a:datestring, 5, 2))
    let l:day = str2nr(strpart(a:datestring, 8, 2))
    return [l:year, l:month, l:day]
endfunction "}}}

" Completion {{{1

" Simple keyword completion on all buffers {{{2
function! TodoKeywordComplete(base)
    " Search for matches
    let res = []
    for bufnr in range(1,bufnr('$'))
        let lines=getbufline(bufnr,1,"$")
        for line in lines
            if line =~ a:base
                " init temporary item
                let item={}
                let item.word=substitute(line,'.*\('.a:base.'\S*\).*','\1',"")
                call add(res,item)
            endif
        endfor
    endfor
    return res
endfunction

" Convert an item to the completion format and add it to the completion list
fun! TodoAddToCompletionList(list,item,opp)
    " Create the definitive item
    let resitem={}
    let resitem.word=a:item.word
    let resitem.info=a:opp=='+'?"Projects":"Contexts"
    let resitem.info.=": ".join(a:item.related, ", ")
                \."\nBuffers: ".join(a:item.buffers, ", ")
    call add(a:list,resitem)
endfun

fun! TodoCopyTempItem(item)
    let ret={}
    let ret.word=a:item.word
    if has_key(a:item, "related")
        let ret.related=[a:item.related]
    else
        let ret.related=[]
    endif
    let ret.buffers=[a:item.buffers]
    return ret
endfun

" Intelligent completion for projects and Contexts {{{2
fun! todo#Complete(findstart, base)
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] !~ '\s'
            let start -= 1
        endwhile
        return start
    else
        if a:base !~ '^+' && a:base !~ '^@'
            return TodoKeywordComplete(a:base)
        endif
        " Opposite sign
        let opp=a:base=~'+'?'@':'+'
        " Search for matchs
        let res = []
        for bufnr in range(1,bufnr('$'))
            let lines=getbufline(bufnr,1,"$")
            for line in lines
                if line =~ " ".a:base
                    " init temporary item
                    let item={}
                    let item.word=substitute(line,'.*\('.a:base.'\S*\).*','\1',"")
                    let item.buffers=bufname(bufnr)
                    if line =~ '.*\s\('.opp.'\S\S*\).*'
                        let item.related=substitute(line,'.*\s\('.opp.'\S\S*\).*','\1',"")
                    endif
                    call add(res,item)
                endif
            endfor
        endfor
        call sort(res)
        " Here all results are sorted in res, but we need to merge them
        let ret=[]
        if res != []
            let curitem=TodoCopyTempItem(res[0])
            for it in res
                if curitem.word==it.word
                    " Merge results
                    if has_key(it, "related") && index(curitem.related,it.related) <0
                        call add(curitem.related,it.related)
                    endif
                    if index(curitem.buffers,it.buffers) <0
                        call add(curitem.buffers,it.buffers)
                    endif
                else
                    " Add to list
                    call TodoAddToCompletionList(ret,curitem,opp)
                    " Init new item from it
                    let curitem=TodoCopyTempItem(it)
                endif
            endfor
            " Don't forget to add the list item
            call TodoAddToCompletionList(ret,curitem,opp)
        endif
        return ret
    endif
endfun

" vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab foldmethod=marker
