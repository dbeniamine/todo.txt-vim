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

" Increment and Decrement The Priority.
" TODO: Make nrformats local to buffers of type todo
:set nf=octal,hex,alpha

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

function! todo#ToggleMarkAsDone(status)
    if (getline(".") =~ '\C^x\s*\d\{4\}')
        :call todo#UnMarkAsDone(a:status)
    else
        :call todo#MarkAsDone(a:status)
    endif
endfunction

function! todo#UnMarkAsDone(status)
    if a:status==''
        let pat=''
    else
        let pat=' '.a:status
    endif
    exec ':s/\C^x\s*\d\{4}-\d\{1,2}-\d\{1,2}'.pat.'\s*//g'
endfunction

function! todo#MarkAsDone(status)
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

function! todo#Sort()
    " vim :sort is usually stable
    " we sort first on contexts, then on projects and then on priority
    if expand('%')=~'[Dd]one.*.txt'
        " FIXME: Put some unit tests around this, and fix case sensitivity if ignorecase is set.
        silent! %s/\(x\s*\d\{4}\)-\(\d\{2}\)-\(\d\{2}\)/\1\2\3/g
        sort n /^x\s*/
        silent! %s/\(x\s*\d\{4}\)\(\d\{2}\)/\1-\2-/g
    else
        let oldcursor=getpos(".")
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
        sort /\v([A-Z])/ r
        if l:first != 0
            silent normal G"ap
            execute ':'.l:first.','.l:last.'sort /@[a-zA-Z]*/ r'
            execute ':'.l:first.','.l:last.'sort /+[a-zA-Z]*/ r'
            execute ':'.l:first.','.l:last.'sort /\v([A-Z])/ r'
        endif
        call cursor(oldcursor)
    endif
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
    let ret.related=[a:item.related]
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
                    let item.related=substitute(line,'.*\s\('.opp.'\S\S*\).*','\1',"")
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
                    if index(curitem.related,it.related) <0
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
