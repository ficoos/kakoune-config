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

plug "alexherbo2/prelude.kak"
plug "alexherbo2/connect.kak"
plug "andreyorst/plug.kak" noload
plug "andreyorst/smarttab.kak"
plug "lenormf/kakoune-extra" load %{
    vcs.kak
    filetype/git.kak
}
plug "ficoos/tool.kak"


source "%val{config}/lsp.kak"
source "%val{config}/deflua.kak"

define-command tmux-terminal-left-dock -params 1.. -shell-completion -docstring '
tmux-terminal-left-pane <program> [<arguments>]: create a new terminal as a tmux pane
The pane is opened on the left of the window
The program passed as argument will be executed in the new terminal' \
%{
    tmux-terminal-impl 'split-window -f -h -b -l 40' %arg{@}
}

define-command tmux-terminal-top-dock -params 1.. -shell-completion -docstring '
tmux-terminal-left-pane <program> [<arguments>]: create a new terminal as a tmux pane
The pane is opened on the left of the window
The program passed as argument will be executed in the new terminal' \
%{
    tmux-terminal-impl 'split-window -f -v -b -l 20' %arg{@}
}


define-command ranger -docstring 'Open the ranger file browser' %{
    connect-command tmux-terminal-left-dock ranger "--cmd=source %val{config}/rangerrc"
}

evaluate-commands %sh{
    if which ranger &> /dev/null; then
        echo "map global user f ': ranger<ret>' -docstring 'open file browser'"
    fi
}

colorscheme gotham

# hide clippy
set-option global ui_options ncurses_assistant=none

set-option global idle_timeout 500

# editorconfig
hook global BufSetOption aligntab=true %{ noexpandtab }
hook global BufSetOption aligntab=false %{ expandtab }
hook global BufSetOption indentwidth=.* %{
    set-option global softtabstop %opt{indentwidth}
    set-option global tabstop %opt{indentwidth}
}

hook global BufOpenFile .* %{ editorconfig-load }
hook global BufNewFile .* %{ editorconfig-load }

# highlight todo/fixme/etc
set-face global Task white,default+b
declare-option -docstring 'Task matcher' regex task_regex '(TODO:|FIXME:|@\w+:?)'
add-highlighter shared/CodeTask regex "^\h*(?://|/\*)\h*%opt{task_regex}" 1:Task
add-highlighter shared/LuaTask regex "^\h*(?:--)\h*%opt{task_regex}" 1:Task
add-highlighter shared/ScriptTask regex "^\h*(?:#)\h*%opt{task_regex}" 1:Task
add-highlighter shared/MarkupTask regex "^\h*(?:<!--)\h*%opt{task_regex}" 1:Task
hook global WinSetOption filetype=(c|cpp|javascript|rust|go|typescript) %{
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

hook global WinSetOption filetype=(lua) %{
    add-highlighter window/task ref LuaTask
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/task }
}

# show matching char
add-highlighter global/ show-matching

# line numbers
add-highlighter global/ number-lines

# show whitespace
add-highlighter global/ show-whitespaces -lf ' '

declare-option bool is_code false
hook global WinSetOption filetype=(python|sh|bash|kak|c|cpp|javascript|rust|go|typescript|lua|git-commit) %{
    set-option window is_code true
    hook -once -always window WinSetOption filetype=.* %{ set-option window is_code false}
}
# show trailing whitespace
set-face global TrailingWhitespace default,green
add-highlighter shared/TrailingWhitespace regex '(\h+)\n' 1:TrailingWhitespace
hook global WinSetOption is_code=true %{
    add-highlighter window/trailing_whitespace ref TrailingWhitespace
    hook -once -always window WinSetOption is_code=false %{ remove-highlighter window/trailing_whitespace }
}

# highlight cloumn 80
# TODO: make column configurable
set-face global ColumnLimit default,black
add-highlighter shared/ColumnLimit column 80 ColumnLimit
hook global WinSetOption is_code=true %{
    add-highlighter window/column_limit ref ColumnLimit
    hook -once -always window WinSetOption is_code=false %{ remove-highlighter window/column_limit}
}

# git
set-face global GitBlame default,default

# user keys
map global normal <\> ': enter-user-mode<space>user<ret>' -docstring 'leader'
map global user c ': delete-buffer<ret>' -docstring 'delete buffer'
map global user t ': connect-terminal<ret>' -docstring 'create a new terminal window'
map global user e ': make-next-error<ret>' -docstring 'go to next error'
map global user E ': make-previous-error<ret>' -docstring 'go to previous error'
map global user b ': tool-build<ret>' -docstring 'build using selected tool'
map global user C ': comment-line<ret>' -docstring '[un]comment block'
map global user '\' ': execute-keys \<ret>' -docstring 'no-hooks prefix'
map global user p ': enter-user-mode<space>paste<ret>' -docstring 'paste clipboard'
map global user y ': enter-user-mode<space>yank<ret>' -docstring 'yank clipboard'
map global user g ': terminal tig<ret>' -docstring 'yank clipboard'

# advanced paste
declare-user-mode paste
map global paste p '<!>xsel -p -o<ret>' -docstring 'primary'
map global paste s '<!>xsel -s -o<ret>' -docstring 'secondary'
map global paste b '<!>xsel -b -o<ret>' -docstring 'clipboard'
declare-user-mode yank
map global yank p '<a-|>xsel -p -i<ret>' -docstring 'primary'
map global yank s '<a-|>xsel -s -i<ret>' -docstring 'secondary'
map global yank b '<a-|>xsel -b -i<ret>' -docstring 'clipboard'

# window keys
declare-user-mode window
map global normal <c-w> ': enter-user-mode<space>window<ret>'
map global window t ': cw<ret>' -docstring 'select tools pane'
map global window d ': focus %opt{docsclient}<ret>' -docstring 'select docs pane'
map global window j ': focus %opt{mainclient}<ret>' -docstring 'select jump pane'

map global normal <a-right> ': better-buffer-next<ret>' -docstring 'go to next non-scratch buffer'
map global normal <a-left> ': better-buffer-previous<ret>' -docstring 'go to previous non-scratch buffer'

declare-option str build_tool 'make'
define-command tool-build %{
    %opt{build_tool}
}

evaluate-commands %sh{
    if [ -f '.project.fish' ]; then
        echo set-option global makecmd 'proj'
    fi
}

# TODO: define `write-all-quit-all`
define-command quit-all \
    -docstring %{quit-all: quits all clients} \
%{ evaluate-commands %sh{
    eval "set -- $kak_client_list"
    while [ -n "$1" ]; do
        printf '%s\n' "evaluate-commands -try-client $1 %{quit}"
        shift
    done
}}
alias global qa quit-all

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
declare-option -docstring 'Automatically open ide split' bool auto_ide false

hook -once global WinDisplay .* %{
    evaluate-commands %sh{
        if [ "$kak_opt_auto_ide" != "true" ]; then
            exit
        fi
        if [ -z "$TMUX" ]; then
            exit
        fi
        if [ "$kak_client" != "client0" ]; then
            exit
        fi
        echo ide
    }
}

define-command ide -docstring 'default ide split' %{
    rename-client main
    set-option global jumpclient main
    new rename-client tools
    set-option global toolsclient tools
    nop %sh{ tmux move-pane -t {left-of} }
    nop %sh{ tmux resize-pane -y 11 }
    nop %sh{ tmux select-pane -t 0 }
    new rename-client docs
    set-option global docsclient docs
    nop %sh{ tmux select-pane -t 0 }
}

# vim compat
define-command cw -docstring 'jump to toolsclient' \
%{ focus %opt{toolsclient} }

define-command -hidden -params 1.. terminal-horizontal %{
    try %{
        tmux-terminal-horizontal %arg{@}
    } catch %{
        try %{
            i3-terminal-horizontal %arg{@}
        } catch %{
            fail "Only supported inside tmux or i3"
        }
    }
}

define-command -hidden -params 1.. terminal-vertical %{
    try %{
        tmux-terminal-vertical %arg{@}
    } catch %{
        try %{
            i3-terminal-vertical %arg{@}
        } catch %{
            fail "Only supported inside tmux or i3"
        }
    }
}

define-command vsp -docstring '
vsp: create a new kakoune client in a vertical split' \
%{
    terminal-horizontal kak -c %val{session} -e "buffer %val{bufname}"
}

define-command sp -docstring '
sp: create a new kakoune client in a horizontal split' \
%{
    terminal-vertical kak -c %val{session} -e "buffer %val{bufname}"
}

# make pattern, by default only catches "errors
set-option global make_error_pattern " (?:(?:fatal )?error|warning|note):"

# fzf

declare-option str fzf_command 'fzf'
hook global WinCreate .* %{
    set-option global fzf_command %sh{
        [ -n "$TMUX" ] && printf "%s" "$kak_config/tmux-fzf.sh" && exit 0
        printf "%s" "pop-vt --stdio --location 2 --size 0.9,0.3 -- fzf"
    }
}

define-command fzf-buffer %{
    evaluate-commands %sh{
        match=$(
            eval set -- $kak_quoted_buflist
            printf "%s\n" "$@" | \
            grep -x -v -F "$kak_bufname" | \
            $kak_opt_fzf_command \
        ) && printf "%s\n" "buffer %{$match}"
    }
}

define-command fzf-project-files \
    -docstring 'fzf-project-files: fuzzy find files in project' \
%{
    evaluate-commands %sh{
        $kak_config/proj-ls-files.py | \
        $kak_opt_fzf_command -d '\0' --filepath-word -n '2..' --with-nth '2..' --ansi | \
        cut -d '' -f 1 | \
        while read -r l
        do
            printf "%s\n" "edit %{$l}"
        done
    }
    #evaluate-commands %sh{
    #    match=$($kak_config/rofi-edit-file.py) && echo edit "$match"
    #}
}

map global normal <c-p> ': fzf-project-files<ret>'
map global normal <,> ': fzf-buffer<ret>'

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

define-command -hidden edit-at \
    -params 2..4 \
    -docstring 'Edit on a different client' \
%{
    evaluate-commands -try-client %arg{1} %{
        edit %arg{2} %arg{3} %arg{4}
    }
}

define-command dup-view \
    -params 1 \
    -client-completion \
    -docstring 'dup-view <client>: duplicate current view to client' \
%{
    edit-at %arg{1} %val{buffile} %val{cursor_line} %val{cursor_column}
}

# must be last for ordering reasons
evaluate-commands %sh{
    lkakrc="${kak_opt_vcs_root_path:-$PWD}/.dir.kak"
    if [ -f $lkakrc ]; then
        echo "echo -debug \"Sourcing $lkakrc\""
        echo "source $lkakrc"
   fi
}

hook global ModuleLoaded x11 %{
    set-option global termcmd 'xfce4-terminal -e '
}

hook global ModuleLoaded x11-repl %{
define-command -override -docstring %{x11-repl [<arguments>]: create a new window for repl interaction
All optional parameters are forwarded to the new window} \
    -params .. \
    -shell-completion \
    x11-repl %{ evaluate-commands %sh{
        if [ -z "${kak_opt_termcmd}" ]; then
           echo 'fail termcmd option is not set'
           exit
        fi
        if [ $# -eq 0 ]; then cmd="${SHELL:-sh}"; else cmd="$@"; fi
        # The escape sequence in the printf command sets the terminal's title:
        setsid ${kak_opt_termcmd} "sh -c \"printf '\e]2;kak_repl_window\a' \
                && exec ${cmd}\"" < /dev/null > /dev/null 2>&1 &
}}
}

define-command evaluate-selection \
-docstring "evaluate-selection: evaluate the current selection" \
%{
    evaluate-commands %sh{
        tmp=$(mktemp "${TMPDIR:-/tmp}/kakoune_eval_selection.XXXXXXXXX")
        printf "%s" "$kak_selection" > $tmp
        printf "%s\n" "source $tmp"
        printf "%s\n" "nop %sh{rm $tmp}"
    }
}

define-lua-command test-lua %{
    print("echo -debug %{hello world}", kak_buflist)
}
