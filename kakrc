# install plug.kak if not installed
evaluate-commands %sh{
    printf "%s\n" "source \"$kak_config/plugins/plug.kak/rc/plug.kak\""
    if [ ! -d "$kak_config/plugins/plug.kak" ]; then
        mkdir -p "$kak_config/plugins"
        git clone https://github.com/andreyorst/plug.kak.git "$kak_config/plugins/plug.kak"
        printf "%s\n" "plug-install"
    fi
}

# FIXME: There is a bug in upstream tmux terminfo.
#        This ensures we have the correct terminfo install.
#        Remove when bug is fixed upstream.
nop %sh{
    terminfo_path=$kak_config/tmux-256color.terminfo
    if [ ! -f "$terminfo_path" ]; then
        wget https://raw.githubusercontent.com/mawww/kakoune/master/contrib/tmux-256color.terminfo -O "$terminfo_path"
        tic "$terminfo_path"
    fi
}

plug "andreyorst/plug.kak" noload
plug "andreyorst/fzf.kak"
plug "andreyorst/smarttab.kak"
plug "lenormf/kakoune-extra" load %{
    vcs.kak
}

source "%val{config}/lsp.kak"

colorscheme gotham

# hide clippy
set-option global ui_options ncurses_assistant=none

# editorconfig
hook global BufSetOption aligntab=true %{ noexpandtab }
hook global BufSetOption aligntab=false %{ expandtab }
hook global BufOpenFile .* %{ editorconfig-load }
hook global BufNewFile .* %{ editorconfig-load }

# highlight todo/fixme/etc
set-face global Task white,default+b
declare-option -docstring 'Task matcher' regex task_regex '(TODO:|FIXME:|@\w+:?)'
add-highlighter shared/CodeTask regex "^\h*(?://|/\*)\h*%opt{task_regex}" 1:Task
add-highlighter shared/ScriptTask regex "^\h*(?:#)\h*%opt{task_regex}" 1:Task
add-highlighter shared/MarkupTask regex "^\h*(?:<!--)\h*%opt{task_regex}" 1:Task
hook global WinSetOption filetype=(c|cpp|javascript|rust|go) %{
    add-highlighter window/task ref CodeTask
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/task }
}

hook global WinSetOption filetype=(python|sh|bash|kak) %{
    add-highlighter window/task ref ScriptTask
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/task }
}

hook global WinSetOption filetype=(html|xml) %{
    add-highlighter window/task ref MarkupTask
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/task }
}

# show matching char
add-highlighter global/ show-matching

# line numbers
add-highlighter global/ number-lines

# show whitespace
add-highlighter global/ show-whitespaces -lf ' '

# show trailing whitespace
set-face global TrailingWhitespace default,green
add-highlighter global/ regex '([ \t\r]+)\n' 1:TrailingWhitespace

# highlight cloumn 80
set-face global ColumnLimit default,black
add-highlighter global/ column 80 ColumnLimit

# user keys
map global normal <\> , -docstring 'leader'
map global user c ':delete-buffer<ret>' -docstring 'delete buffer'
map global user t ':tmux-repl-window<ret>' -docstring 'create a new terminal window'
map global user e ':make-next-error<ret>' -docstring 'go to next error'
map global user E ':make-previous-error<ret>' -docstring 'go to previous error'

# window keys
declare-user-mode window
map global normal <c-w> ':enter-user-mode<space>window<ret>'
map global window <left> ':nop %sh{ tmux select-pane -t {left-of} }<ret>' -docstring 'select pane to the left'
map global window <right> ':nop %sh{ tmux select-pane -t {right-of} }<ret>' -docstring 'select pane to the right'
map global window <up> ':nop %sh{ tmux select-pane -t {up-of} }<ret>' -docstring 'select pane above'
map global window <down> ':nop %sh{ tmux select-pane -t {down-of} }<ret>' -docstring 'select pane below'
map global window t ':cw<ret>' -docstring 'select tools pane'
map global window d ':focus %opt{docsclient}<ret>' -docstring 'select docs pane'
map global window j ':focus %opt{mainclient}<ret>' -docstring 'select jump pane'

map global normal <a-right> ':better-buffer-next<ret>' -docstring 'go to next non-scratch buffer'
map global normal <a-left> ':better-buffer-previous<ret>' -docstring 'go to previous non-scratch buffer'

evaluate-commands %sh{
	if [ -f '.project.fish' ]; then
		echo set-option global makecmd 'proj'
	fi
}

define-command better-buffer-previous \
	-docstring %{better-buffer-next : go to next buffer, but better!
This skips buffers with names beginning with an asterix (*). } \
%{ evaluate-commands %sh{
    eval "set -- $kak_buflist $kak_buflist"
    found_current=
    for (( i=$#;i>0;i-- )); do
        if [ "$found_current" ]; then
            if [ "${!i:0:1}" != "*" ]; then
                printf "%s\n" "buffer \"${!i}\""
                exit
            fi
        else
            if [ "${!i}" = "$kak_bufname" ]; then
                found_current="${!i}"
            fi
        fi
    done
}}

define-command better-buffer-next \
	-docstring %{better-buffer-previous: go to previous buffer, but better!
This skips buffers with names beginning with an asterix (*). } \
%{ evaluate-commands %sh{
    eval "set -- $kak_buflist $kak_buflist"
    found_current=
    for (( i=1; i<=$#;i++)); do
        if [ "$found_current" ]; then
            if [ "${!i:0:1}" != "*" ]; then
                printf "%s\n" "buffer \"${!i}\""
                exit
            fi
        else
            if [ "${!i}" = "$kak_bufname" ]; then
                found_current="${!i}"
            fi
        fi
    done
}}

# ide mode, opens a 3 window tmux format
define-command ide -docstring 'default ide split' %{
    rename-client main
    set-option global jumpclient main
    new rename-client tools
    set-option global toolsclient tools
    nop %sh{ tmux move-pane -t {left-of} }
    nop %sh{ tmux resize-pane -y 11 }
    focus main
    new rename-client docs
    set-option global docsclient docs
    focus main
}

# vim compat
define-command cw -docstring 'jump to toolsclient' \
%{ focus %opt{toolsclient} }

define-command vsp -docstring '
vsp: create a new kakoune client in a vertical split' \
%{
	try %{
		tmux-terminal-horizontal kak -c %val{session} -e "buffer %val{bufname}"
	} catch %{
		fail "Only supported inside tmux"
	}
}

define-command sp -docstring '
sp: create a new kakoune client in a horizontal split' \
%{
	try %{
		tmux-terminal-vertical kak -c %val{session} -e "buffer %val{bufname}"
	} catch %{
		fail "Only supported inside tmux"
	}
}

# make pattern, by default only catches "errors
set-option global make_error_pattern " (?:(?:fatal )?error|warning|note):"

# fzf
define-command proj-edit -params 2 -hidden %{
    edit %arg{2}
}

define-command fzf-project-files -docstring '
fzf-project-files: fuzzy find files in project' \
%{ evaluate-commands %sh{
    message="Open single or multiple files.
<ret>: open file in new buffer.
<c-w>: open file in new window"
    [ ! -z "${kak_client_env_TMUX}" ] && tmux_keybindings="
<c-s>: open file in horizontal split
<c-v>: open file in vertical split"

    printf "%s\n" "info -title 'fzf project' '$message$tmux_keybindings'"
    [ ! -z "${kak_client_env_TMUX}" ] && additional_flags="--expect ctrl-v --expect ctrl-s"
    printf "%s\n" "fzf %{proj-edit} %{python3 ~/.config/kak/proj-ls-files.py} %{--expect ctrl-w --ansi --no-sort -n 2.. $additional_flags}"
}}

map global normal <c-p> ': fzf-project-files<ret>'
map global normal <c-f> ': fzf-buffer<ret>'

# git gutter
hook global WinCreate .* %{ evaluate-commands %sh{
    if [ -n "${kak_opt_vcs_root_path}" ]; then
        case "${kak_opt_vcs_name}" in
            git)
                echo "
                    git show-diff
                    hook global BufWritePost %val{buffile} %{git update-diff}
                    hook global BufReload %val{buffile} %{git update-diff}
                    hook global WinDisplay %val{buffile} %{git update-diff}
                ";;
        esac
    fi
}}
