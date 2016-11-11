#!/usr/bin/env sh
snippet_dir='.gen-md'
pod-render.pl6 --md ./lib/Perlbot.pm6
mv Perlbot.md $snippet_dir/pod.md
cd $snippet_dir
cat head.md pod.md tail.md > ../README.md
