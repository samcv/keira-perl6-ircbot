#!/usr/bin/env perl6
# Copyright © 2016
#     Samantha McVey <samantham@posteo.net>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the Artistic License 2

use v6.c;
use IRC::Client;
# My modules
use P5-to-P6-Regex;
constant MESSAGE-LIMIT = 4;
my %unicode-props =
    Lu => 'Letter, uppercase',
    Ll => 'Letter, lowercase',
    Lt => 'Letter, titlecase',
    Lm => 'Letter, modifier',
    Lo => 'Letter, other',
    Mn => 'Mark, nonspacing',
    Me => 'Mark, enclosing',
    Nd => 'Number, decimal digit',
    Nl => 'Number, letter',
    No => 'Number, other',
    Pc => 'Punctuation, connector',
    Pd => 'Punctuation, dash',
    Pe => 'Punctuation, close',
    Pi => 'Punctuation, initial quote',
    Pf => 'Punctuation, final quote',
    Po => 'Punctuation, other',
    Sm => 'Symbol, math',
    Sc => 'Symbol, currency',
    Sk => 'Symbol, modifier',
    So => 'Symbol, other',
    Zs => 'Separator, space',
    Zl => 'Separator, line',
    Zp => 'Separator, paragraph',
    Cc => 'Other, control',
    Cf => 'Other, format',
    Cs => 'Other, surrogate',
    Co => 'Other, private use',
    Cn => 'Other, not assigned';

class Unicodable does IRC::Client::Plugin {
    has %.hash;
    has $.MAX = 4;
    sub format-codes ($codepoint, $description, $type) {
        my $type-str = %unicode-props{$type} ?? " {%unicode-props{$type}}" !! "";
        my $result = sprintf "U+%s %s %s [%s]%s", (sprintf "%x", $codepoint).uc, $codepoint.chr, $description, $type, $type-str;
        $result;
    }
    sub query-code ( Str $query is copy, $e, $self ) {
        my $codepoint = $query.ord;
        if $self.hash{$codepoint} {
            my $response = format-codes($codepoint, uniname($codepoint), uniprop($codepoint));
            say-to-chan $response, $e;
        }
        else {
            say-to-chan "Can't find that codepoint?", $e;
        }
    }
    sub get-query ( Str $query is copy, $e, $self ) is export {
        $query .= trim;
        say "this many codes {$query.codes}";
        if $query.codes == 1 {
            query-code($query, $e, $self);
        }
        elsif $query ~~ m:i/ ^ '0x' [ \d | <[a..f]> ]+ $ / {
            say "looks like a number";
            query-code($query.Num.chr, $e, $self);
        }
        else {
            my $is-regex = False;
            say $query;
            if $query ~~ / ^ '/' .* '/' $ / {
                $query ~~ s/ ^ '/' //;
                $query ~~ s/ '/' $ //;
                say $query;
                 $is-regex = True;
                 $query = P5-to-P6-Regex($query);
                 say $query;
            }
            my @words = $query.uc.words;
            my @results;
            sub thingy ( $codepoint, $name ) {
                my $result = format-codes($codepoint, $name.key, $name.value);
                #my $result = sprintf "U+%s %s %s [%s]", (sprintf "%x", $codepoint).uc, $codepoint.chr, $name.key, $name.value;
                push @results, $result;
                if @results.elems == $self.MAX {
                    say-to-chan @results, $e;
                }
            }
            if $is-regex {
                for $self.hash.kv -> $codepoint, $name {
                    if $name.key ~~ /<$query>/ {
                        thingy $codepoint, $name;
                    }
                }

            }
            else {
                for $self.hash.kv -> $codepoint, $name {
                    if $name.key.contains(@words) or $name.key.words ∩ @words {
                        thingy $codepoint, $name;
                    }
                }
            }
            if @results.elems < $self.MAX {
                if @results.elems < 1 {
                    say-to-chan "Can't find anything", $e;
                }
                else {
                    say-to-chan @results, $e;
                }
            }
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
