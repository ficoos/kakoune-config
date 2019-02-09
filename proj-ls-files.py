#!/usr/bin/python3
import subprocess
import os

LINE_FORMAT = '\033[33m{prefix} \033[37m{path}\033[0m{base}'

def get_files(cmd, prefix):
    # TODO:  this method should throw away stderr since it messes up the output
    output = subprocess.check_output(cmd)
    lines = output.splitlines()
    for line in lines:
        line = line.decode('utf8')
        base = os.path.basename(line)
        path = os.path.dirname(line)
        if path:
            path += "/"
        print(LINE_FORMAT.format(prefix=prefix, path=path, base=base))

def get_git_files():
    # TODO: do this in the git root
    get_files(['git', 'ls-files', '-c'], 'git')
    get_files(['git', 'ls-files', '-o', '--exclude-standard'], 'git-other')
    if os.path.exists('.gitmodules'):
        mod_prefixes = subprocess.check_output(['git', 'config', '--file', '.gitmodules', '--get-regexp', 'path'])
        mod_prefixes = [l.decode('utf8') for l in mod_prefixes.split()]
        get_files(['git', 'ls-files', '--recurse-submodules'] + mod_prefixes, 'git-submodules')

def get_find_files():
    get_files(['find', '-type', 'f', '-follow'], 'find')

if os.path.exists('.git'):
    get_git_files()
else:
    get_find_files()
