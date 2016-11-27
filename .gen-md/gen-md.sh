#!/usr/bin/env sh
snippet_dir='.gen-md'
PERL6LIB=lib pod-render.pl6 --md ./lib/IRCPlugin/Keira.pm6 || exit
mv Keira.md $snippet_dir/pod.md || exit
cd $snippet_dir || exit
cat head.md pod.md tail.md > ../README.md || exit
