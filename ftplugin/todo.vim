" File:        todo.txt.vim
" Description: Todo.txt filetype detection
" Author:      David Beniamine <David@Beniamine.net>, Leandro Freitas <freitass@gmail.com>
" License:     Vim license
" Website:     http://github.com/dbeniamine/todo.txt-vim

" Save context {{{1
let s:save_cpo = &cpo
set cpo&vim

if exists("g:Todo_txt_loaded")
    finish
else
    let g:Todo_txt_loaded=0.8.1
endif

" General options {{{1
" Some options lose their values when window changes. They will be set every
" time this script is invocated, which is whenever a file of this type is
" created or edited.
setlocal textwidth=0
setlocal wrapmargin=0

" Mappings {{{1

if !exists("g:Todo_txt_do_not_map")
" Sort todo by (first) context
    noremap <silent><localleader>sc :call todo#HierarchicalSort('@', '', 1)<CR>

    noremap <silent><localleader>scp :call todo#HierarchicalSort('@', '+', 1)<CR>
" Sort todo by (first) project
    noremap <silent><localleader>sp :call todo#HierarchicalSort('+', '',1)<CR>
    noremap <silent><localleader>spc :call todo#HierarchicalSort('+', '@',1)<CR>

" Sort tasks {{{2
    nnoremap <script> <silent> <buffer> <LocalLeader>s :call todo#Sort()<CR>
    nnoremap <script> <silent> <buffer> <LocalLeader>s@ :sort /.\{-}\ze@/ <CR>
    nnoremap <script> <silent> <buffer> <LocalLeader>s+ :sort /.\{-}\ze+/ <CR>
" Priorities {{{2
    noremap <script> <silent> <buffer> <LocalLeader>j :call todo#PrioritizeIncrease()<CR>
    noremap <script> <silent> <buffer> <LocalLeader>k :call todo#PrioritizeDecrease()<CR>

    noremap <script> <silent> <buffer> <LocalLeader>a :call todo#PrioritizeAdd('A')<CR>
    noremap <script> <silent> <buffer> <LocalLeader>b :call todo#PrioritizeAdd('B')<CR>
    noremap <script> <silent> <buffer> <LocalLeader>c :call todo#PrioritizeAdd('C')<CR>

" Insert date {{{2
    inoremap <script> <silent> <buffer> date<Tab> <C-R>=strftime("%Y-%m-%d")<CR>

    inoremap <script> <silent> <buffer> due: due:<C-R>=strftime("%Y-%m-%d")<CR>
    inoremap <script> <silent> <buffer> DUE: DUE:<C-R>=strftime("%Y-%m-%d")<CR>

    noremap <script> <silent> <buffer> <localleader>d :call todo#PrependDate()<CR>

" Mark done {{{2
    noremap <script> <silent> <buffer> <Plug>DoToggleMarkAsDone :call todo#ToggleMarkAsDone('')<CR>
                \:silent! call repeat#set("\<Plug>DoToggleMarkAsDone")<CR>
    nmap <localleader>x <Plug>DoToggleMarkAsDone
    " noremap <script> <silent> <buffer> <localleader>x :call todo#ToggleMarkAsDone('')<CR>

" Mark done {{{2
    noremap <script> <silent> <buffer> <Plug>DoCancel :call todo#ToggleMarkAsDone('Cancelled')<CR>
                \:silent! call repeat#set("\<Plug>DoCancel")<CR>
    nmap <localleader>C <Plug>DoCancel

" Mark all done {{{2
    noremap <script> <silent> <buffer> <localleader>X :call todo#MarkAllAsDone()<CR>

" Remove completed {{{2
    nnoremap <script> <silent> <buffer> <localleader>D :call todo#RemoveCompleted()<CR>

" Sort by due: date {{{2
    nnoremap <script> <silent> <buffer> <localleader>sd :call todo#SortDue()<CR>
" try fix format {{{2
    nnoremap <script> <silent> <buffer> <localleader>ff :call todo#FixFormat()<CR>
endif

" Folding {{{1
" Options {{{2
setlocal foldmethod=expr
setlocal foldexpr=TodoFoldLevel(v:lnum)
setlocal foldtext=TodoFoldText()

" TodoFoldLevel(lnum) {{{2
function! TodoFoldLevel(lnum)
    " The match function returns the index of the matching pattern or -1 if
    " the pattern doesn't match. In this case, we always try to match a
    " completed task from the beginning of the line so that the matching
    " function will always return -1 if the pattern doesn't match or 0 if the
    " pattern matches. Incrementing by one the value returned by the matching
    " function we will return 1 for the completed tasks (they will be at the
    " first folding level) while for the other lines 0 will be returned,
    " indicating that they do not fold.
    return match(getline(a:lnum),'\C^x\s') + 1
endfunction

" TodoFoldText() {{{2
function! TodoFoldText()
    " The text displayed at the fold is formatted as '+- N Completed tasks'
    " where N is the number of lines folded.
    return '+' . v:folddashes . ' '
                \ . (v:foldend - v:foldstart + 1)
                \ . ' Completed tasks '
endfunction

" Restore context {{{1
let &cpo = s:save_cpo

" vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab foldmethod=marker
