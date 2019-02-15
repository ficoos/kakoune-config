# install plug.kak if not installed
evaluate-commands %sh{
    printf "%s\n" "source \"$kak_config/plugins/plug.kak/rc/plug.kak\""
    if [ ! -d "$kak_config/plugins/plug.kak" ]; then
        mkdir -p "$kak_config/plugins"
        git clone https://github.com/andreyorst/plug.kak.git "$kak_config/plugins/plug.kak"
        printf "%s\n" "plug-install"
    fi
}

plug "andreyorst/plug.kak" noload
plug "andreyorst/fzf.kak"
plug "andreyorst/smarttab.kak"
plug "lenormf/kakoune-extra" load %{
    vcs.kak
}
plug "ul/kak-lsp" do %{
    cargo build --release --locked
} config %{
    nop %sh{
        lsp_conf="$kak_config/lsp/kak-lsp.toml"
        sed -e "s:@kak_config@:$kak_config:g" "${lsp_conf}.template" > "$lsp_conf"
    }
    set-option global lsp_cmd "%val{config}/plugins/kak-lsp/target/release/kak-lsp -s %val{session} --config %val{config}/lsp/kak-lsp.toml"
    hook global KakEnd .* lsp-exit

    set-face global DiagnosticError default,rgb:330000
    set-face global DiagnosticWarning default,rgb:333300
    set-face global Reference default,default+u

    hook global WinSetOption filetype=(c|cpp) %{
        set-option window lsp_auto_highlight_references true
        set-option window lsp_hover_anchor false
        lsp-auto-hover-enable
        lsp-enable-window
        }
}

# Language Servers
define-command lsp-ccls-update -docstring 'Update ccls' %{ nop %sh{
    source_dir=$kak_config/lsp/ccls
    if [ ! -d "$source_dir" ]; then
        git clone https://github.com/MaskRay/ccls.git "$source_dir"
    fi
    cd "$source_dir"
    git pull
    cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DUSE_SHARED_LLVM=true || exit 1
    cmake --build Release
}}

define-command lsp-pyls-update -docstring 'Update the python language server' %{ nop %sh{
    venv_dir=$kak_config/lsp/pyls
    if [ ! -d "$venv_dir" ]; then
        virtualenv "$venv_dir"
    fi
    cd "$venv_dir"
    source ./bin/activate
    pip install -U 'python-language-server[all]'
}}

colorscheme gotham

# hide clippy
set-option global ui_options ncurses_assistant=none

# editorconfig
hook global BufSetOption aligntab=true %{ noexpandtab }
hook global BufSetOption aligntab=false %{ expandtab }
hook global BufOpenFile .* %{ editorconfig-load }
hook global BufNewFile .* %{ editorconfig-load }

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

