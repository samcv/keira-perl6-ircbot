[![Build Status](https://travis-ci.org/samcv/keira-perl6-ircbot.svg?branch=master)](https://travis-ci.org/samcv/keira-perl6-ircbot)
What
====

A Perl 6+5 bot using the IRC::Client Perl 6 module

Description
===========

This is an IRC bot in Perl 5 and 6. It was originally only in Perl 5 but the core has now been rewriten in Perl 6, and the rest is being ported over now.

Text Substitution
-----------------

s/before/after/gi functionality. Use g or i at the end to make it global or case insensitive

If the last character is a slash, we assume any slashes in the $after term are literal ( Except for the last one ) If not, then anything after the last slash is a specifier

Seen
----

Replys with the last time the specified user has spoke, joined, quit or parted. `Usage: !seen nickname`

Saving Channel Event Data
-------------------------

The command `!SAVE` will cause the channel event data and history file to be saved. Normally it will save when the data changes in memory provided it hasn't already saved within the last 10 seconds

Tell
----

Syntax: `!tell nickname message` or `!tell nickname in 10 minutes message`

Will tell the specified nickname the message the next time they speak in channel

Operator Commands
=================

People who have been added as an operator in the 'botnick-ops.json' file will be allowed to perform the following commands if their nick, hostname and usermask match those in the file.

Ban
---

The specified user will be banned by 30 minutes at default. You can override this and set a specific number of seconds to ban for instead. The bot will automatically unban the person once this time period is up, as well as printing to the channel how long the user has been banned for. Usage: `!ban nick`.

Unban
-----

`Usage: !unban nick`

Op
--

Gives ops to specified user, or if no user is specified, gives operator to the user who did the command. `Usage: !op` or `!op nickname`.

DeOp
----

Takes ops away from the specified user, or if no user is specified, removes operator status from the user who did the command. `Usage: !deop` or `!deop nickname`.

Kick
----

Kicks the specified user from the channel. You are also allowed to specify a custom kickmessage as well. `Usage: !kick nickname` or `!kick nickname custom message`.

Topic
-----

Sets the topic. `Usage: !topic new topic message here`.

Hexidecimal/Decimal/Unicode conversions
=======================================

You can convert between any of these three using the general syntax `!from2to`

When converting from numerical each value that is a different number is delimited by spaces. Examples are below.

Get Unicode Codepoints
----------------------

Usage: `!hex2uni 🐧ABCD`

Output: `1F427 41 42 43 44`

Will get the Unicode codepoints in hex for a given string.

Convert from Unicode Codepoints to Characters
---------------------------------------------

Usage: `!uni2hex 1F427 41 42 43 44`

Output: `🐧ABCD`

Mentioned
---------

Gets the last time the specified person mentioned any users the bot knows about.

`Usage: !mentioned nickname`

Time
----

Gets the current time in the specified location. Uses Google to do the lookups.

`Usage !time Location`

Perl 6 Eval
-----------

Evaluates the requested Perl 6 code and returns the output of standard out and error messages.

`Usage: !p6 my $var = "Hello Perl 6 World!"; say $var`

Perl 5 Eval
-----------

Evaluates the requested Perl 5 code and returns the output of standard out and error messages.

`Usage: !p my $var = "Hello Perl 5 World!\n"; print $var`
o
## Commands performed by Perl 5 in `said.pl`
All of these commands below have not been reimplemented in Perl 6 yet.

#### Transliterate
Usage: `!transliterate ありがとうございました`

Works for almost all languages or non language characters.  Converts into romanized ASCII text.

Output: `arigatougozaimasita`

#### Fortune
Usage: `!fortune`
Gets a short fortune using the Linux/Unix `fortune` program.

#### Unicode Lookup
Usage: `!ul 🐧`

Output: `https://www.fileformat.info/info/unicode/char/1f427/index.htm`

 `[ Unicode Character 'PENGUIN' (U+1F427) ] `

Will lookup a a unicode character at the fileformat.info website.
To get a response not for a character but for the codepoint you want, use:

`!unicodelookup 1F427`

#### Urban Dictionary
Usage: `!ud thing to look up`

Ouput: The top definition and example from urbandictionary.com

#### Questions
You can have the bot answer yes or no questions.  Just address the bot by name like so:

`mybot is the sky blue?`

Response will be either `Is the sky blue? No.` or `Is the sky blue? Yes.`

You can also ask it a this or that question, with a maximum number of arguments being three.
`mybot is it going to be a good day today or a bad day today?`

`It is going to be a good day today` or `A bad day today`

	fullwidth/fw
	uc
	ucirc
	lc
	lcirc
	help
	action
