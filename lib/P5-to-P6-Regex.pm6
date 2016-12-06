use v6;
sub P5-to-P6-Regex ( Str $regex is copy ) is export returns Str {
    # We need to do this to allow Perl 5/PCRE style regex's to work as expected in Perl 6
    # And make user input safe
    # Change from [a-z] to [a..z] for character classes
    while $regex ~~ /'[' .*? <( '-' )> .*? ']'/ {
      $regex ~~ s:g/'[' .*? <( '-' )> .*? ']'/../;
    }
        # Escape all the following characters
    for Qw[ - & ! " ' % = , ; : ~ ` @ { } < > ] ->  $old {
      $regex ~~ s:g/$old/{ ｢\｣ ~ $old}/;
    }
    $regex ~~ s:g/'\b'/<|w>/; # Replace \b for word boundary with <|w
    $regex ~~ s:g/'#'/'#'/; # Quote all hashes #
    $regex ~~ s:g/ '$' .+ $ /\\\$/; # Escape all $ unless they're at the end
    $regex ~~ s:g/'[' (.*?) ']'/<[$0]>/; # Replace [a..z] with <[a..z]>
    $regex ~~ s:g/' '/<.ws>/; # Replace spaces with <.ws>
    $regex ~~ s:g/'(?i)'/ :i /;
    $regex;
}
