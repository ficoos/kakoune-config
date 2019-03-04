#lsp related settings and commands

plug "ul/kak-lsp" do %{
    cargo build --release --locked
} config %{
    nop %sh{
        lsp_conf="$kak_config/lsp/kak-lsp.toml"
        sed -e "s:@kak_config@:$kak_config:g" "${lsp_conf}.template" > "$lsp_conf"
    }
    set-option global lsp_cmd "%val{config}/plugins/kak-lsp/target/release/kak-lsp -s %val{session} --config %val{config}/lsp/kak-lsp.toml"
    nop %sh{ ( $kak_opt_lsp_cmd -vvv ) > /tmp/kak-lsp.log 2>&1 < /dev/null & }
    hook global KakEnd .* lsp-exit

    set-face global DiagnosticError   default,rgb:330000
    set-face global DiagnosticWarning default,rgb:333300
    set-face global Reference         default,default+u

    hook global WinSetOption filetype=(c|cpp|javascript|python|go) %{
        # TODO: analyze server capabilities to choose what to turn on or off
        set-option window lsp_auto_highlight_references true
        set-option window lsp_hover_anchor true
        set-option window lsp-auto-hover-insert-mode-enable
        lsp-auto-hover-disable
        lsp-enable-window
    }
    hook global WinSetOption filetype=(javascript) %{
        # flow doesn't support references (yet?)
        set-option window lsp_auto_highlight_references false
    }
}

# Language Servers
define-command lsp-update-ccls -docstring 'update ccls' %{ nop %sh{
    source_dir=$kak_config/lsp/ccls
    if [ ! -d "$source_dir" ]; then
        git clone https://github.com/MaskRay/ccls.git "$source_dir"
    fi
    cd "$source_dir"
    git pull
    cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DUSE_SHARED_LLVM=true || exit 1
    cmake --build Release
}}

define-command lsp-update-pyls -docstring 'update the python language server' %{ nop %sh{
    venv_dir=$kak_config/lsp/pyls
    if [ ! -d "$venv_dir" ]; then
        virtualenv "$venv_dir"
    fi
    cat > "$venv_dir/pyls" <<EOF
#!/usr/bin/sh
if [ -f 'Pipfile' ]; then
    exec pipenv run pyls
fi
base_dir=\$(dirname \$0)
source \$base_dir/bin/activate
exec \$base_dir/bin/pyls "\$@"
EOF
    chmod a+x "$venvdir/pyls"
    cd "$venv_dir"
    source ./bin/activate
    pip install -U 'python-language-server[all]'
}}

define-command lsp-update-flow -docstring 'update the javascript language server' %{ nop %sh{
    flow_dir=$kak_config/lsp/flow
    if [ ! -d "$flow_dir" ]; then
        mkdir -p "$flow_dir"
    fi

    cd "$flow_dir"
    npm install --save-dev flow-bin
}}

define-command lsp-update-bingo -docstring 'update the go language server' %{ nop %sh{
    go get -u github.com/saibing/bingo
}}

# FIXME: this is here to compensate for https://github.com/ul/kak-lsp/issues/176
define-command -override -hidden lsp-show-error -params 1 %{
    echo -debug "kak-lsp:" %arg{1}
}

map global normal <f1> ':enter-user-mode<space>lsp<ret>'
map global normal <c-w> ':enter-user-mode<space>window<ret>'
map global normal <c-w> ':enter-user-mode<space>window<ret>'
map global normal <c-w> ':enter-user-mode<space>window<ret>'
map global normal <c-w> ':enter-user-mode<space>window<ret>'
map global normal <c-w> ':enter-user-mode<space>window<ret>'
