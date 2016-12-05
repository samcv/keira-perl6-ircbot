#!/usr/bin/env perl6
# Copyright © 2016
#     Aleks-Daniel Jakimenko-Aleksejev <alex.jakimenko@gmail.com>
#     Daniel Green <ddgreen@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
use v6.c;
use IRC::Client;
constant MESSAGE-LIMIT = 4;
class Unicodable does IRC::Client::Plugin {
    method irc-privmsg-channel ($e) {
        if $e.text.starts-with('u: ') {
            my $text = $e.text;
            $text ~~ s/ ^ 'u: ' //;
            my $output = process($text);
            my $i;
            for $output.lines {
                $i++;
                last if $i > 4;
                $e.irc.send: :where($e.channel) :text(~$_);
                sleep 1;
            }
        }
        $.NEXT;
    }

    sub help($message) {
        “Just type any unicode character or part of a character name. Alternatively, you can also provide a code snippet or a regex”
    };


    sub get-description($ord) {
        my $char = $ord.chr;
        $char = ‘◌’ ~ $ord.chr if $char.uniprop.starts-with(‘M’);
        try {
            $char.encode;
            CATCH { default { $char = ‘unencodable character’ } }
        }
        sprintf("U+%04X %s [%s] (%s)", $ord, uniname($ord), uniprop($ord), $char)
    }
    sub process ($query is copy) {
        my $old-dir = $*CWD;
        my $filename;
        my $output;
        my @all;
        if $query ~~ /^ <+[a..z] +[A..Z] +space>+ $/ {
            my @words;
            my @props;
            for $query.words {
                if /^ <[A..Z]> <[a..z]> $/ {
                    @props.push: $_
                } else {
                    @words.push: .uc
                }
            }
            for (0..0x1FFFF).grep({ (!@words or uniname($_).contains(@words.all))
                                    and (!@props or uniprop($_) eq @props.any) }) {
                my $char-desc = get-description($_);
                @all.push: $char-desc;
                return $char-desc if @all < MESSAGE-LIMIT; # >;
            }
        }
        elsif $query ~~ /^ ‘/’ / {
            return ‘Regexes are not supported yet, sorry! Try code blocks instead’;
        }
        if $output {
            for $output.split(“\c[31]”) {
                try {
                    my $char-desc = get-description(+$_);
                    @all.push: $char-desc;
                    return $char-desc if @all < MESSAGE-LIMIT; # >;
                    CATCH {
                        .say;
                        return ‘Oops, something went wrong!’;
                    }
                }
            }
        }
        else {
            for $query.comb».ords.flat {
                my $char-desc = get-description($_);
                @all.push: $char-desc;
                return $char-desc if @all < MESSAGE-LIMIT; # >;
            }
        }
        return @all[*-1] if @all == MESSAGE-LIMIT;
        return @all.join: “\n” if @all > MESSAGE-LIMIT;
        return ‘Found nothing!’ if not @all;
        return;

        LEAVE {
            chdir $old-dir;
            unlink $filename if $filename.defined and $filename.chars > 0;
        }
    }
}


# vim: expandtab shiftwidth=4 ft=perl6
