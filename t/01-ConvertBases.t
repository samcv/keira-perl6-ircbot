#!perl6

use Test;

use lib 'lib';

use ConvertBases;
is convert-bases( :from<unicode>, :to<unicode>, "This is a Test String 🐧" ), "This is a Test String 🐧", "Unicode to Unicode";
is convert-bases( :from<unicode>, :to<hex>, "This is a Test String 🐧" ), "54 68 69 73 20 69 73 20 61 20 54 65 73 74 20 53 74 72 69 6e 67 20 1f427", "Unicode to Hex";
is convert-bases( :from<unicode>, :to<dec>, "This is a Test String 🐧" ), "84 104 105 115 32 105 115 32 97 32 84 101 115 116 32 83 116 114 105 110 103 32 128039", "Unicode to Decimal";
is convert-bases( :from<unicode>, :to<binary>, "This is a Test String 🐧" ), "1010100 1101000 1101001 1110011 100000 1101001 1110011 100000 1100001 100000 1010100 1100101 1110011 1110100 100000 1010011 1110100 1110010 1101001 1101110 1100111 100000 11111010000100111", "Unicode to Binary";

done-testing;
