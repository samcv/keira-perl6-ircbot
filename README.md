### perlbot

This is an IRC bot which will respond to the IRC channel when somebody pastes a link with the page title of that page

	Usage: perlbot.pl "username" "real name" "server address" "server port" "server channel"

### Commands

#### Tell
Usage: `!tell nickname Message to tell them`

This will tell that person the message the next time they speak in the channel or private message the bot.
#### Tell in
Usage: `!tell in 1m/h/d Message to tell them`

This will tell that person the message after that many minutes/hours/days that you specify.  It is triggered when they speak in the channel or private message the bot.
#### Seen
Usage: `!seen nickname`
Will tell you the last time that nickname has spoken, joined or parted/quit the channel.

#### Transliterate
Usage: `!transliterate ありがとうございました`

Works for almost all languages or non language characters.  Converts into romanized ASCII text.

Output: `arigatougozaimasita`

#### Fortune
Usage: `!fortune`
Gets a short fortune using the Linux/Unix `fortune` program.

#### Get Unicode Codepoints
Usage: `!u 🐧ABCD`

Output: `1F427 41 42 43 44`

Will get the Unicode codepoints in hex for a given string.

#### Convert from Unicode Codepoints to Characters
Usage: `!unicode 1F427 41 42 43 44`

Output: `🐧ABCD`

Is the reverse of the `!u` command.

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



	fullwidth
	fw
	fromhex
	tohex
	uc
	ucirc
	lc
	lcirc
	perl
	p
	help
	action
