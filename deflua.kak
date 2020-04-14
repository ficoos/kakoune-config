require-module lua
require-module kak

add-highlighter shared/kakrc/code/lua_commands regex '(^|\h)define-lua-command\h' 0:keyword
add-highlighter shared/kakrc/lua_command1 region -recurse '\{' 'define-lua-command\h.*?\K%\{' '\}' ref lua
add-highlighter shared/kakrc/lua_command2 region -recurse '\(' 'define-lua-command\h.*?\K%\(' '\)' ref lua
add-highlighter shared/kakrc/lua_command3 region -recurse '\[' 'define-lua-command\h.*?\K%\[' '\]' ref lua
add-highlighter shared/kakrc/lua_command4 region -recurse '<'  'define-lua-command\h.*?\K%<'  '>'  ref lua

define-command define-lua-command \
-docstring "define-lua-command [<switches>] <name> <cmds>: define a command <name> executing <cmds>
 Switches:
     -params <arg>                  take parameters, accessible to each shell escape as $0..$N
     parameter should take the form <count> or <min>..<max> (both omittable)
     -override                      allow overriding an existing command
     -hidden                        do not display the command in completion candidates
     -docstring <arg>               define the documentation string for command
     -file-completion               complete parameters using filename completion
     -client-completion             complete parameters using client name completion
     -buffer-completion             complete parameters using buffer name completion
     -command-completion            complete parameters using kakoune command completion
     -shell-completion              complete parameters using shell command completion
     -shell-script-completion <arg> complete parameters using the given shell-script
     -shell-script-candidates <arg> get the parameter candidates using the given shell-script" \
-params 1.. %{ evaluate-commands %sh{
    # filtering arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -docstring)
                shift
                docstring=$(printf "%s\n" "$1" | sed "s/&/&&/g")
                docstring="-docstring %&$docstring&" ;;
            -params)
                shift
                params="-params $1" ;;
            -shell-script-completion)
                shift
                completion=$(printf "%s\n" "$1" | sed "s/&/&&/g")
                completion="-shell-script-completion %&$completion&" ;;
            -shell-script-candidates)
                shift
                candidates=$(printf "%s\n" "$1" | sed "s/&/&&/g")
                candidates="-shell-script-candidates %&$candidates&" ;;
            -override|-hidden|-menu|-file-completion|-client-completion|-buffer-completion|-command-completion|-shell-completion)
                switches="$switches $1" ;;
            *)
                args="$args '$1'" ;;
        esac
        shift
    done

    eval "set -- $args"
    # at this point only name and body should be left as unhandled args
    if [ $# -ne 2 ]; then
        printf "%s\n" "fail %{'define-lua-command' wrong argument count}"
        exit
    fi

    command_name="$1"
    shift

    # creating command body file
    tmp=$(mktemp "${TMPDIR:-/tmp}/kakoune_lua_cmd_${command_name}.XXXXXXXXX")

    cat > $tmp <<<"$1"
    # extracting kakoune variables from command body
    vars=$(grep -o 'kak_\w*' <<<"$1" | uniq | sed "s/^/# /")
    luac -o "$tmp.c" "$tmp"
    mv "$tmp.c" "$tmp"
    # creating body of the command
    printf "%s\n" "
        define-command $switches $docstring $command_name $completion $candidates $params %{
            evaluate-commands %sh{
                $vars
                lua -e '_G = setmetatable(_G, { __index=function(tbl, key) return rawget(tbl, key) or (string.sub(key, 1, 4) == \"kak_\" and os.getenv(key)) or nil end})' $tmp \$@
            }
        }
        hook global -always KakEnd .* %{ nop %sh{ rm $tmp }}
    "
}}

alias global def-lua define-lua-command

