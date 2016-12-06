#!/usr/bin/env perl6
# Copyright © 2016
#     Samantha McVey <samantham@posteo.net>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2

use v6.c;
use IRC::Client;
constant MESSAGE-LIMIT = 4;
class Unicodable does IRC::Client::Plugin {
    has %.hash;
    has $.MAX = 4;
    sub get-query ( Str $query is copy, $e, $self ) is export {
        $query .= trim;
        if $query.codes == 1 {
            if $self.hash{$query.ord} {
                say-to-chan $self.hash{$query}, $e;
            }
            else {
                say-to-chan "Can't find that codepoint?", $e
            }
        }
        else {
            my @words = $query.uc.words;
            my @results;
            for $self.hash.kv -> $codepoint, $name {
                if $name.key.contains(@words) {
                    my $result = sprintf "U+%s %s %s [%s]", (sprintf "%x", $codepoint).uc, $codepoint.chr, $name.key, $name.value;
                    push @results, $result;
                    if @results.elems == $self.MAX {
                        say-to-chan @results, $e;
                    }
                }
            }
            say-to-chan @results, $e if @results.elems < $self.MAX;
            if @results.elems > $self.MAX {
                "unicode.txt".IO.spurt(@results.join("\n"));
                my $link = qx<pastebinit -P -b sprunge.us ./unicode.txt>;
                say-to-chan $link, $e;
            }
        }
    }

    sub say-to-chan ($text is copy, $e) {
        $text = $text.join("\n") if $text ~~ Array;
        start {
            for $text.lines {
                $e.irc.send: :where($e.channel) :text(~$_);
                sleep 0.2;
            }
        }
    }
    method irc-connected ($e) {
        say "Loading unicode symbols";
        for (0..0x1FFFF) {
            %!hash{$_} = uniname($_) => uniprop($_);
        }
        say "Done loading";
        $.NEXT;
    }
    method irc-privmsg-channel ($e) {
        if $e.text.starts-with('u: ') {
            start {
                my $text = $e.text;
                $text ~~ s/ ^ 'u: ' //;
                get-query($text, $e, self)
            }
        }
        $.NEXT;
    }
}
