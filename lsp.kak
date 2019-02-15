#lsp related settings and commands

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

