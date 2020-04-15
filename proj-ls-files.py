#!/usr/bin/python3
import subprocess
import os
import sys

LINE_FORMAT = '{abspath}\0\033[33m{prefix}\0 \033[37m{path}\033[0m{base}\n'


def get_files(cmd, prefix):
    p = subprocess.Popen(
        cmd,
        stderr=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        encoding='utf8',
    )
    try:
        for line in p.stdout:
            line = line.strip()
            base = os.path.basename(line)
            path = os.path.dirname(line)
            abspath = os.path.abspath(line)
            if path:
                path += "/"
            sys.stdout.write(LINE_FORMAT.format(
                abspath=abspath,
                prefix=prefix,
                path=path,
                base=base,
            ))
    finally:
        p.wait()


def get_git_files():
    # TODO: do this in the git root
    get_files(['git', 'ls-files', '-c'], 'git')
    get_files(['git', 'ls-files', '-o', '--exclude-standard'], 'git-other')
    if os.path.exists('.gitmodules'):
        mod_prefixes = subprocess.check_output([
            'git',
            'config',
            '--file',
            '.gitmodules',
            '--get-regexp',
            'path'])
        mod_prefixes = [l.decode('utf8') for l in mod_prefixes.split()]
        get_files(['git',
                   'ls-files',
                   '--recurse-submodules'] + mod_prefixes,
                  'git-submodules')


def get_find_files():
    get_files(['find', '-type', 'f', '-follow'], 'find')


if subprocess.call(('git', 'rev-parse'), stderr=subprocess.DEVNULL) == 0:
    get_git_files()
else:
    get_find_files()
