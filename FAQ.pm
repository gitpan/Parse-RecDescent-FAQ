package Parse::RecDescent::FAQ;

use vars qw($VERSION);

$VERSION = '1.4';

1;
__END__

=head1 NAME

Parse::RecDescent::FAQ - Unofficial, unauthorized FAQ for Parse::RecDescent

=head1 Parse::RecDescent Questions

=head2 Matching line continuation characters

I need to parse a grammar that includes line continuation
characters.  For example:

 // COMMAND ARG1-VALUE,ARG2-VALUE, +
    ARG3-VALUE,ARG4-VALUE, +
    EVEN-MORE-ARGS
 // ANOTHERCOMMAND
 * and a comment
 * or two

How do I formulate a rule (or rules) to treat the first command
as if all 5 arguments were specified on a single line?  I need to
skip over the /\s*+\n\s*/ sequence.  It seems like skip or resync
should do this for me, but if so, I haven't discovered the
correct technique, yet.



=over 4

=item * Answer by Damian Conway

 use Parse::RecDescent;
 
 my @lines = << 'EOINST';
 // COMMAND ARG1-VALUE,ARG2-VALUE, +
    ARG3-VALUE,ARG4-VALUE, +
    EVEN-MORE-ARGS
 // ANOTHERCOMMAND
 * and a comment
 * or two
 EOINST
 
 my $parse = Parse::RecDescent->new(join '', <DATA>) or die "Bad Grammar!";
 
 use Data::Dumper 'Dumper';
 print Dumper [
 $parse->Instructions("@lines") or die "NOT parsable!!\n"
 ];
 
 __DATA__
 
 Instructions: command(s)
 
 command: multiline_command
        | singleline_command
        | comment
 
 singleline_command: 
 	'//'  /.*/
 		{ {command => $item[-1]} }
 
 multiline_command:  
 	'//' /(.*?[+][ \t]*\n)+.*/
 		{ $item[-1] =~ s/[+][ \t]*\n//g; {command => $item[-1]} }
 
 comment:
 	'*'  /.*/
 		{ {comment => $item[-1]} }
 


=back

=head2 Incremental generation of data structure representing parse

I have a data structure which is

a hash of entries
where
an entry is a list/array of sets

I have also a grammar that can parse the syntax of the text files that
contain the data I want to fill this structure with. Until here
everything is ok.

Problem: I cannot figure out how to actually FILL the parsed data into
the structure. I can only decide if a string is grammatically correct
or not.



=over 4

=item * Answer by Marcel Grunaer

Try this grammar, which you have to feed the input as one big
string. It uses a global variable, $::res into which the results
are assembled. At the end the variable is also returned for
convenience.

It basically parses a phrase and a list of meanings. Instead of
reconstructing what it just parsed at each step, it checks the
remaining text at various stages (using an idea taken from
Parse::RecDescent::Consumer) to see what the 'phrase' or 'meaning'
subrules just matched. The 'meanings' subrule then (implicitly)
returns a reference to an array of 'meaning' strings. That arrayref
is stored at the proper slot in the result hash.

(Hope that explanation makes sense. I'm sure Damian can come up
with a grammar that's way more elegant and efficient...)


 
 
 { sub consumer {
          my $text = shift;
          my $closure = sub { substr $text, 0, length($text) - 
 length($_[0]) }
 } }
 
 start : entry(s) { $::res }
 
 entry :
            comment
          | def
          | <error>
 
 def : <rulevar: local $p_cons>
 def : <rulevar: local $p_text>
 
 # The // skips initial whitespace so it won't end up in $p_text
 
 def :
      // { $p_cons = consumer($text) } phrase { $p_text = 
 $p_cons->($text) }
      '=' meanings ';'
      { $::res->{$p_text} = $item{meanings} }
 
 comment : /#.*(?=\n)/m
 
 phrase  : ident(s)
 
 ident   : /[\w&\.'-]+/
 
 meanings : meaning(s /:/)
 
 meaning : <rulevar: local $m_cons>
 meaning : // { $m_cons = consumer($text) } element(s /,?/) 
 { $m_cons->($text) }
 
 element : alternation(s /\|/)
 
 alternation : expr(s /[+>]/)
 
 expr : /!?/ term
 
 term : ident '(' meaning ')' | ident

=back

=head2 How can I match parenthetical expressions to arbitrary depth?

Example: a, (b ,c, (e,f , [h, i], j) )

=over 4

=item * Answer by FAQ author

Maybe Text::Balanced is enough for your needs. See it on search.CPAN.org
under author id DCONWAY.

=item * Answer by lhoward of perlmonks.org:

Parse::RecDescent implements a full-featured recursive-descent
parser. A real parser (as opposed to parsing a string with a regular
expression alone) is much more powerful and can be more apropriate for
parsing highly structured/nested data like you have. It 
has been a while since I've written a grammer so it may look a bit
rough. 

 use Parse::RecDescent;
 my $teststr="blah1,blah2(blah3,blah4(blah5,blah6(blah7))),blah8";
 my $grammar = q {
         content:        /[^\)\(\,]+/
         function:       content '(' list ')'
         value:          content
         item:           function | value
         list:           item ',' list | item
         startrule:      list
 };
 my $parser = new Parse::RecDescent ($grammar) or die "Bad grammar!\n";
 
 defined $parser->startrule($teststr) or print "Bad text!\n";


To which merlyn (Randal Schwartz) of perlmonks.org says:

Simplifying the grammar, we get: 

 use Parse::RecDescent;  
 my $teststr="blah1,blah2(blah3,blah4(blah5,blah6(blah7))),blah8";  
 my $grammar = q {
  list: <leftop: item ',' item> 
  item: word '(' list ')' <commit>
      | word 
  word: /\w+/  
 };  
 my $parser = new Parse::RecDescent ($grammar) or die "Bad grammar!\n";
 
 defined $parser->list($teststr) or print "Bad text!\n";

 

=back

=head2 Switching out of first-match-wins mode

I have a set of alternatives on which I want to avoid the
default first-match-wins behavior of Parse::RecDescent. How do I do
it? 

=over 4
=item * Answer by FAQ author

Use a scored grammar. For example, this scoring directive

 opcode: /$match_text1/  <score: { length join '' @item}>
 opcode: /$match_text2/  <score: { length join '' @item}>
 opcode: /$match_text3/  <score: { length join '' @item}>

would return the opcode with the longest length, as opposed to which
one matched first.

Just look for the section "Scored productions" in the .pod
documentation. 


=back

=head2 I'm having problems with the inter-token separator:

 my $parse = Parse::RecDescent->new(<<'EndGrammar');

 rebol   : block  { dump_item('block', \@item)  }
         | scalar { dump_item('scalar', \@item) }

 block       : '[' block_stuff(s?) ']'
 block_stuff : scalar
 scalar      : <skip:''> '%' file
 file        : /w+/

 EndGrammar

My grammar matches a filename, ie: 

 %reb.html

just fine. However, it does not match a filename within a block, ie: 

 [ %reb.html ]

and I know exactly why after tracing the grammar. 

It is trying the 

 <skip:''> '%' file

production with the input text 

 " %reb.html"

note the space in the input text. 

The reason this distresses me is that I have not changed the universal token 
separator from 

 /\s*/

Yet it did not gobble up the white space between the '[' terminal and the <skip:''>'%' file production


=over 4

=item * Answer by Randal Schwartz

That's the expected behavior. The outer prefix is in effect until
changed, but you changed it early in the rule, so the previous
"whitespace skip" is effectively gone by the time you hunt for '%'.  

To get what you want, you want: 

 '%' <skip:''> file

in your rule. 
back

=back

=head2 Getting text from subrule matches

I can't seem to get the text from my subrule matches...

=over 4
=item * Answer by Damian Conway

Your problem is in this rule:

    tuple : (number dot)(2)

is the same as:

    tuple        : anon_subrule(2)

    anon_subrule : number dot

Like all subrules, this anonymous subrule returns only its last item
(namely, the dot). If you want just the number back, write this:

    tuple : (number dot {$item[1]})(2)

If you want both number and dot back (in a nested array), write this:

    tuple : (number dot {\@item})(2)

=back

=head2 Matching blank lines

How do I match an arbitrary number of blank lines in Parse::RecDescent?

=over 4

=item * Answer by Damian Conway

Unless you use the /m suffix, the trailing $ means "end of string", 
not "end of line". You want:

   blank_line:  /^\s+?$/m

or 
   
   blank_line:  /^\s+?\n/

=back
=head2 More on blank lines

I have a rule which MUST be failing, but it isn't. Why?


   blank_line:    { $text =~ /silly-regex/ }
   
          parses with no error.

=over 4
=item * Answer by Damian Conway

The pattern match still fails, but returns the empty string ("").
Since that's not undef, the rule matches (even though it doesn't
do what you want).

=back


=head2 Error handling

I'm trying to write a parser for orders for Atlantis (PBEM game).
Syntax is pretty simple: one line per command, each command
starts with name, followed by list of parameters. Basically it's
something like this (grammar for parsing one line):

 Statement:Comment | Command Comment(?)
 Comment:/;.*/ 
 Command:'#atlantis' <commit> FactionID String
    Command:'attack' <commit> Number(s)
 ....

However I have problems to make it work as I want:

1) In case of failed parsing (syntax error, not allowey keyword, ...) 
I want to store error messages in variable (not to be just printed), so I can 
process them later.

I don't think Parse::RecDescent has a hook for that (Damian, something
for the todo list?), but you can always install a $SIG {__WARN__}
handler and process the generated warnings.

2) In case if user types "attack bastards" I want to give him
error message that "list of numbers expected" instead
of just saying the "cannot parse this line". The only
thing that I came up with now was defining every command
like this:
 Command:Attack
 Attack:'attack' AttackParams
 AttackParams:Number(s) | <error>
 ...
Any better solutions?

=over 4

=item * You can just do:

    Command:   '#atlantis' <commit> FactionID String
       |   'attack' <commit> Number(s)
       |   <error>

and when you try to parse "attack bastards", you will get:

    ERROR (line 1): Invalid Command: Was expecting Number but found
        "bastards" instead

You might want to use <error?>, which will only print the error when
it saw '#atlantis' or 'attack' (because then you are committed).

=back

=head2 My grammar is not returning any data! 

What's wrong?!

=over 4

=item * Answer by Brent Dax:

This is a clue; either something is wrong with your actions or the
grammar isn't parsing the data correctly. Try adding 
  | <error> 

clauses
to the end of each top-level rule. This will tell you if there's a
parsing error, and possibly what the error is. If this doesn't show
anything, look hard at the actions. You may want to explicitly set the
$return variable in the actions.   

=back

=head2 How can I get at the text remaining to be parsed?

See the documentation for the C<$text> variable.

=head2 You don't escape Perl symbols in your grammars. Why did I have to?

 my $grammar = <<EOGRAMMAR;
 
 export_line:	stock_symbol	COMMA   # 1
 		stock_name	COMMA2  # 2
 		stock_code	COMMA3  # 3
 		trade_side	COMMA4  # 4
 		trade_volume	COMMA5  # 5
 		floating_point	COMMA6  # 6
 		tc                      # 7
 { print "got \@item\n"; }
     | <error>
 EOGRAMMAR
 
 Why does '@' have to be escaped? And whatever reason
 that may be, why doesnt it apply to '\n'?
 


=over 4

=item * Answer by Damian Conway

Because you're using an interpolating here document. You almost certainly 
want this instead: 

 my $grammar = <<'EOGRAMMAR';		# The quotes are critical!
    
 
  export_line:	stock_symbol	COMMA   # 1
    		stock_name	COMMA2  # 2
    		stock_code	COMMA3  # 3
    		trade_side	COMMA4  # 4
    		trade_volume	COMMA5  # 5
    		floating_point	COMMA6  # 6
    		tc                      # 7
  { print "got @item\n"; }
     | <error>
 EOGRAMMAR
 


=back

=head2 Other modules appear to not work when used with P::RD

Such-and-such a module works fine when I don't use Parse::RecDescent

=over 4
=item * Answer by Damian Conway

 Did you alter the value of undef with your parser code? 

The problem has nothing to do with  Parse::RecDescent.
 
Rather, it was caused by your having set $/ to undef, which seems to
have caused Mail::POP3 to over-read from its socket (that might be
considered a bug in the Mail::POP3 module).

As a rule-of-thumb, *never* alter $/ without local-izing it. In other words, 
change things like this: 

         $/ = undef;

to this:

          {
          local $/;
          }

=back

=head1 Programming Topics Germane to Parse::RecDescent Use

=head2 Tracking text parsed between phases of the parse


I wanted to know, after matching a rule, what text the rule matched.
So I used two variables to remember what the remaining text and
offset were before and after the rule and just determined the
difference.

   report : <rulevar: local $rule_text>
   report : <rulevar: local $rule_offset>

   report :
             {
                 $rule_text   = $text;
                 $rule_offset = $thisoffset;
             }

         ...some subrules...

             {
                 my $str = substr($rule_text, 0, $thisoffset - 
$rule_offset);

                 # remove all sorts of whitespace

                 $str =~ s/^\s*//s;
                 $str =~ s/\s*$//s;
                 $str =~ s/\s+/ /gs;

                 # Now $str contains the text matched by this rule
             }

This is the kind of thing I thought would have been possible a lot
easier. Did I miss something?

If not, is there a way to make this available in every parser,
e.g. by providing a new directive or something like that?

=over 4

=item * The answer is on CPAN

Parse::RecDescent::Consumer, on CPAN, prints out the text consumed
between stages of a parse... even if that part may fail later. The
implementation is straightforward, it creates closures containing
C<$text> and evaluates them later to get the text consumed.

=back

=head2 Unconditionally listifying scalars

Quite often when using Parse::RecDescent, I want to treat the return value of 
a production the same regardless of whether P::RD returns a string or a 
list of string.

=over 4
=item * Use Scalar::Listify from CPAN.

=back

=head2 A tutorial on Shallow versus Deep Copying 

Written by "Philip 'Yes, that's my address' Newton" <nospam.newton@gmx.li>

Start off with an array of (references to) arrays: 

    @array = ( [1,2,3], ['a', 'u', 'B', 'Q', 'M'], ['%'] );


Now a shallow copy looks like this: 

    @shallow = ( $array[0], $array[1], $array[2] );


This copies the references over from @array to @shallow. Now @shallow
is ( [1,2,3], ['a', 'u', 'B', 'Q', 'M'], ['%'] ) -- the same as
@array. But there's only one 2 and one 'Q', since there are two
references pointing to the same place.  

Here's what it looks like in the debugger: 

  DB<5> x \@array
 0  ARRAY(0x10e5560)
   0  ARRAY(0x10e5464)
      0  1
      1  2
      2  3
   1  ARRAY(0x10e5638)
      0  'a'
      1  'u'
      2  'B'
      3  'Q'
      4  'M'
   2  ARRAY(0x10e568c)
      0  '%'
  DB<6> x \@shallow
 0  ARRAY(0xcaef60)
   0  ARRAY(0x10e5464)
      0  1
      1  2
      2  3
   1  ARRAY(0x10e5638)
      0  'a'
      1  'u'
      2  'B'
      3  'Q'
      4  'M'
   2  ARRAY(0x10e568c)
      0  '%'


You can see that @array lives somewhere around 0x10e5560, whereas
@shallow lives around 0xcaef60, but the three references point to
arrays in the same place. If I now change $array[1][2] to 'C', watch
what happens:  

  DB<7> $array[1][2] = 'C'


  DB<8> x \@array
 0  ARRAY(0x10e5560)
   0  ARRAY(0x10e5464)
      0  1
      1  2
      2  3
   1  ARRAY(0x10e5638)
      0  'a'
      1  'u'
      2  'C'
      3  'Q'
      4  'M'
   2  ARRAY(0x10e568c)
      0  '%'
  DB<9> x \@shallow
 0  ARRAY(0xcaef60)
   0  ARRAY(0x10e5464)
      0  1
      1  2
      2  3
   1  ARRAY(0x10e5638)
      0  'a'
      1  'u'
      2  'C'
      3  'Q'
      4  'M'
   2  ARRAY(0x10e568c)
      0  '%'

$shallow[1][2] is now also 'C'! This is because it just followed the
pointer to the array at 0x10e5638 and found the modified data there.  

Now see what happens when I do a copy that's one level deeper -- not
just copying the references but the data behind the references:  

 @deep = ( [ @{$array[0]} ], [ @{$array[1]} ], [ @{$array[2]} ] );

This uses the knowledge that @array[0..2] are all references to
arrays, and it only goes one level deeper. A more general algorithm
(such as Storable's dclone, mentioned in `perldoc -q copy`) would do a
walk and copy differently depending on the type of reference it
encounters at each stage.  

Now watch: 

  DB<12> x \@array
 0  ARRAY(0x10e5560)
   0  ARRAY(0x10e5464)
      0  1
      1  2
      2  3
   1  ARRAY(0x10e5638)
      0  'a'
      1  'u'
      2  'C'
      3  'Q'
      4  'M'
   2  ARRAY(0x10e568c)
      0  '%'
  DB<13> x \@deep
 0  ARRAY(0x10ef89c)
   0  ARRAY(0x10eb298)
      0  1
      1  2
      2  3
   1  ARRAY(0x10eb2c4)
      0  'a'
      1  'u'
      2  'C'
      3  'Q'
      4  'M'
   2  ARRAY(0x10ef07c)
      0  '%'


The references point to different places. 

Now if you change @array, @deep doesn't change: 

  DB<14> push @{$array[2]}, '$'


  DB<15> x \@array
 0  ARRAY(0x10e5560)
   0  ARRAY(0x10e5464)
      0  1
      1  2
      2  3
   1  ARRAY(0x10e5638)
      0  'a'
      1  'u'
      2  'C'
      3  'Q'
      4  'M'
   2  ARRAY(0x10e568c)
      0  '%'
      1  '$'
  DB<16> x \@shallow
 0  ARRAY(0xcaef60)
   0  ARRAY(0x10e5464)
      0  1
      1  2
      2  3
   1  ARRAY(0x10e5638)
      0  'a'
      1  'u'
      2  'C'
      3  'Q'
      4  'M'
   2  ARRAY(0x10e568c)
      0  '%'
      1  '$'
  DB<17> x \@deep
 0  ARRAY(0x10ef89c)
   0  ARRAY(0x10eb298)
      0  1
      1  2
      2  3
   1  ARRAY(0x10eb2c4)
      0  'a'
      1  'u'
      2  'C'
      3  'Q'
      4  'M'
   2  ARRAY(0x10ef07c)
      0  '%'


@deep didn't change, since it's got its own value of the anonymous
array containing '%', but @shallow did.  

Hope this helps a bit. 

Cheers, Philip -- Philip Newton <nospam.newton@gmx.li> 
If you're not part of the solution, you're part of the precipitate

=head2 Apparent, but not really deep copying:  my (@list) = @{[@{$_[0]}]};

I was meandering through demo_calc.pl in the Parse::RecDescent demo
directory and came across this 

 sub evalop
 {
        my (@list) = @{[@{$_[0]}]};
        my $val = shift(@list)->();
 ...       
 }

I took the line that confused me step-by-step and don't get the
purpose of this. Working from inner to outer: 


   @{$_[0]}     # easy --- deference an array reference
 [  @{$_[0]} ]    # ok --- turn it back into an array ref.. why?
 @{ [ @{$_[0]} ] } # umm -- uh.... well, the @sign implies
                             # we have an array, but how is it 
                             # different from the first array we
                             # dereferenced?

=over 4
=item * Matthew Wickerline says


The line from demo_calc.pl is in
fact not doing any deep copying.


    #!/usr/bin/perl -w
    my @original = (
        [0],  [1,2,3],  [4,5,6],  [7,8,9]
    );
    my @copy = &some_kind_of_copy( \@original );
    sub some_kind_of _copy {
        # here's that line from demo_calc.pl
        my (@list) = @{[@{$_[0]}]};
        return @list;
    }

 $original[0][0]         = 'zero';
 @{ $original[1] }[0..2] = qw(one   two   three);
 @{ $original[2] }[0..2] = qw(four  five  six);
 @{ $original[3] }[0..2] = qw(seven eight nine);
    # now use the debugger to look at the addresses,
    # or use Data::Dumper to look at @copy, or just
    # compare one of the items...
 if (  $copy[1][2] eq 'three'  ) {
    print "Shallow Copy\n";
 } elsif (  $copy[1][2] == 3  ) {
    print "Deep Copy\n";
 } else {
        print "This should never happen!!!\n"
	}


If you wanted that line to do deep copying of a list of anon arrays,
then the line should read

    my @list = map  { [@$_] }  @{$_[0]};
               # turn $_[0] into a list (of arrayrefs)
               # turn each (arrayref) element of that list
               # into an anonymous array containing
               # a list found by derefrencing the arrarref

Try plugging that line into above script instead of the line from the
demo_calc.pl and you'll see different output. The line from demo_calc.pl
is in fact doing extra useless work. My guess is that the extra
    @{[    ]}
around there is one of two things:
    1) a momentary lapse of attention
       resulting in a copy/paste error, or duplicate typing
 or
    2) an artifact of earlier code wherein something extra was
       going on in there and has since been deleted.

Even Damian can make a mistake, but it's not a mistake that affects
output... it just makes for a tiny bit of wasted work (or maybe Perl is
smart enough to optimze away the wasted work, I dunno).


=back



=head1 SEE ALSO

=over 4


=item * Parse::YAPP

A bottom-up parser which will be familiar to those who
have used Lex and Yacc. Parse::RecDescent is a top-down parser.

=item * Text::Balanced 

Use this instead of writing hairy regular expressions to match certain
common "balanced" forms of text, such as tags and parenthesized text.

=item * "Mastering Regular Expressions" by Jeffrey Freidl

You still need to know when to use /.*/ or /.+/ or /[^x]*/

=item * "Object-Oriented Perl" by Damian Conway

This book will aid you in complexity management for large grammars.

=item * http://www.PerlMonks.org

A useful site to get fast help on Perl.

=back

=head1 AUTHOR

The author of this FAQ is Terrence Brannon <tbone@cpan.org>. 

The author of Parse::RecDescent 
is Damian Conway. I asked him if he wanted to make this the official FAQ
for P::RD, but he did not reply. Sigh.

The (unwitting) contributors to this FAQ

=over 4 

=item * Me, the FAQ author, Terrence Brannon

=item * Damian Conway

=item * Marcel Grunaer

=item * Brent Dax

=item * Randal L. Schwartz, Perl hacker

=item * lhoward of Perlmonks

=item * Matthew Wickline

=back 

=cut
