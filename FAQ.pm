package Parse::RecDescent::FAQ; 

use vars qw($VERSION);


our $VERSION = sprintf '%s', q$Revision: 2.25 $ =~ /Revision:\s+(.*)\s+/ ;

1;
__END__

=head1 NAME

Parse::RecDescent::FAQ - the official, authorized FAQ for Parse::RecDescent. 

=head1 DEBUGGING

=head1 PARSER BEHAVIOR

=head2 Commit in subrule which is optional in rule

Ques: When a subrule in a rule that has a "zero or
more" repetition specifier (ie. ? or s?) has a
<commit> directive in its production followed by the
conditional <error?> <reject> production, if that
subrule's production becomes committed, does that
error cause the rule containing the subrule to fail
also?  It should right, if we have committed?  It does
not seem to work.

Here is what I mean:

 myrule: 'stuff' mysubrule(?)

 mysubrule: ID <commit> '[' ']'
       | <error?> <reject>

If the 1st production of mysubrule has committed, then
myrule should fail.  It doesn't seem to.  If this is
not a bug, how do I get this behavior?

=over 4

=item * Answer by Damian

The optional nature of the reference to mysubrule(?)
means that, when the subrule fails (whether committed or not)
the failure doesn't matter, since myrule can match if it
finds zero mysubrules, which it just did.


The usual way to get the rule-of-the-subrule to fail upon subrule failure is
by "anchoring" the end of the match. That might be:

  myrule: 'stuff' mysubrule(?) ...!ID

  mysubrule: ID <commit> '[' ']'
           | <error?> <reject>

or 

  myrule: 'stuff' mysubrule(?) /\s*\Z/

  mysubrule: ID <commit> '[' ']'
           | <error?> <reject>


or whatever addition confirms that there really wasn't anything else
after 'stuff'.

=item * Now that you think you know the answer...

That answer is partially wrong, as was pointed out by Marcel Grunaer.
In this phrase:

  myrule: 'stuff' mysubrule(?) ...!ID

it is necessary to return a { 1 }, as the rule
fails otherwise, presumably because of the negative lookahead:

  myrule: 'stuff' mysubrule(?) ...!ID { 1 }

Marcel went on to point out an optimization:

another option would be the use of a rulevar:

  myrule : <rulevar: local $failed>
  myrule : 'stuff' mysubrule(?) <reject:$failed>

  mysubrule: ID <commit> '[' ']'
    | <error?> { $failed++ }

this way you don't have to specify a potentially complex negative
lookahead, and the method works over several levels of subrules
as well.


=back


=head2 Making warning line numbers correspond to your grammar

How do I match the line numbers with the actual contents of my
script?

At present, you can't (but that's on the ToDo list).
Setting C<$::RD_TRACE> can be useful though:

Once you've run with C<$RD_TRACE>, do this:

        perl -w RD_TRACE

Then go and examine the actual line numbers given for the error
in the file C<RD_TRACE>.

That will show you the actual generated code that's the problem.

That code will, in turn, give you a hint where the problem is in the
grammar (e.g. find out which subroutine it's in, which will tell you the
name of the offending rule).

=head1 IGNORABLE TOKENS 

=head2 Removing C comments

Since there is no separate lexer in recdescent. And it is top down. Is
there anyway to deal w/ removing C comments that could be anywhere.

=over 4

=item * Answer by Conway

Sure. Treat them as whitespace!

Do something like this:

	program: <skip: qr{\s* (/[*] .*? [*]/ \s*)*}x> statement(s)

	statement: # etc...

=back

=head1 NEWLINE PROCESSING

=head2 Parsing Windows Init Files

I'm trying ot use Parse::RecDescent to parse a configuration file which
looks like this:

 [SECTION]
 parameter 1=value 1
 parameter2=value 2

 [NEXTSECTION]
 other parameter=other value

=over 4

=item * Answer by Damian

       q{
                config:
                          section(s)

                section:
                          <skip: ''>  section_label parameter(s)
                        | <error>

                section_label:
                          /\[[A-Z]+\]\s*/

                parameter:
                          key "=" value

                key:
                          /[A-Za-z0-9 ]+/

                value:
                          /.*\n/
        }

=item * Another Answer

Also take a look at the example in section 11.2 in "Data Munging with Perl"
by Dave Cross.

=back


=head2 As end of line



I'm trying to parse a text line by line using Parse::RecDescent. Each
line is terminated by a "\n".

Although the task setting up a grammar for this case is straightforward
the following program doesn't
produce any results.


     use Parse::RecDescent;

     $grammar =
     q{
         line:       word(s) newline { print "Found a line\n"; }
         word:       /\w+/
         newline : /\n/
     };

     $parse = new Parse::RecDescent ($grammar);


     $data =
     qq(This is line one\nAnd this is line two\n);

     $parse->line($data);


RecDescent doesn't recognize the newlines. Does anybody know what I'm
getting wrong?

=over 4

=item * Answer by Damian



By default, P::RD skips all whitespace (*including* newlines) before
tokens. 

Try this instead:

         line:    <skip: qr/[ \t]*/> word(s) newline 
				{ print "Found a line\n"; }
         word:    /\w+/
         newline: /\n/

=back

=head1 COLUMN-ORIENTED PROCESSING

=head2 Whitespace, text, column N, period, number (some reference to lookahead)

Ok, now the line I'm trying to deal with is:

"some amount of
whitespace,
then some text, then starting at column 48 a number, followed by a
period,
followed by another number".  I want to capture the text (the
"title"),
and the two numbers (major and minor versions)

=over 4

=item * Answer by Damian Conway

You really do want to use a regex here (to get the
lookahead/backtracking that RecDescent doesn't do).

   line: m/^(\s*        		# leading whitespace
   	      (.*?)        		# the title
              (?:\s+(?=\d+\.\d+\s*$)) 	# the space preceeding the numbers
	    )
            (\d+)        		# the major version number
            \.
            (\d+)        		# the minor version number
	 /x
	 <reject: length $1 != 47>
	 { @{$return}{title major minor)} = ($2,$3,$4) }

=back



=head2 Another example

I'm parsing some lines where the "column formatting" is fixed, i.e. a
particular line might be formally described as "a single word followed by
some amount of whitespace followed by another word whose first character
begins at column 22". 

=over 4

=item * A simple answer that is wrong:


Hmm, I guess I could make this simpler and do this:

line: word <reject: $thiscolumn != 22> word
word: /\S+/

right?

Wrong. And the reason why is that The 

  <reject:...> 

won't skip any whitespace after the first word.

You instead would want:

	line: word '' <reject: $thiscolumn != 22> word

=item * Restating it in the positive can be a GOTCHA:

I'd state that in the positive instead:

    line: word '' { $thiscolumn == 22 } word 

This seems nice and more to the point, but unfortunately a failing conditional 
yields a false value but not necessarily an undef value. So in this case, you
might get back a C<0> from evaluating this conditional, but unfortunately,
that does not lead to failure.

On the other hand, <reject> is exactly the same as the action
 { undef } 
and is guaranteed to make a production fail immediately.

So if you would like to state the test in the positive, then do this:

   line: word '' { $thiscolumn == 22 || undef } word 

=back

=head1 MODULAR / GENERATIVE / CREATIVE / HAIRY PARSING

=head2 Cloning parsers but giving each parser it own package

It seems that the namespace for pre-compiled parsers
(ie. compiled into a perl module) have hard-coded
namespaces (IE. namespace00001).  I was trying to
clone one of these parsers by calling its 'new'
method, but each parser is sharing the same namespace
and thus any global variables I have in that namespace
within a startcode block of my grammar before the
first rule get overwritten by the other corresponding
parser.

=over 4

=item * Answer by Yves Orton

Heres the required patch 

 # Line 1692 of Parse::RecDescent reads

 my $nextnamespace = "namespace000001";

 # Add This Method
 sub set_namespace {
   local $_=$_[1];
   croak "$_ is not a legal namespace." if /[^\w]/;
   $_.="00" unless /\d+$/; # Ensure our namespace has a number at the end
   $nextnamespace=$_;
 }

 # And then just call
 Parse::RecDescent->set_namespace("MyNameSpace");


=back



=head2 Parsing sentences to generate sentences

In this column, Randal shows how to read text to generate more text.
He parses sentences to make Parse::RecDescent parse trees which he then
re-walks with random weightings to create new sentences.

 http://www.stonehenge.com/merlyn/LinuxMag/col04.html


=head2 Calling a parser within a grammar

I have a script that uses Parse::RecDescent, in which I want to define 2
parsers. The grammar for the second parser has to call the first parser.

Can I do this?

=over 4

=item * yes, here's an example

 
 #!/usr/local/bin/perl -w
 use strict;
 use Parse::RecDescent;
 
 $::RD_ERRORS = 1;
 $::RD_WARN = 1;
 $::RD_HINT = 1;
 
 our $text_to_parse = "";
 
 my $grammar1 = q{
 [...]
 }
 
 our $inner_parser = new Parse::RecDescent($grammar1);
 
 my $grammar2 = q{
 [...]
 
 rule: TEXT
 	{
 	  $text_to_parse = $item{TEXT};
           if (defined $text_to_parse) { print "executing inner parse...\n"; }
           my $p_text = $inner_parser->startrule($text_to_parse);
 	}
 
 [...]
 
 }
 


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

=head2 XOR as opposed IOR alternation matching

I'm using alternations in some productions but in contrast to
the definition of the |-operator, I'm looking for a behaviour
which is XOR (^) not OR (|). So far I used the <reject>
directive to simulate such a behaviour.

Is there any easy solution to this?

=over 4

=item * Answer by Randal Schwartz

Use a set.

 use Parse::RecDescent;
 use Data::Dumper; $|++;
 my $parser = Parse::RecDescent->new(q{
 
 line: word(s) /\z/ {
 my @words = @{$item[1]};
 my %count;
 (grep ++$count{$_} > 1, @words) ? undef : \@words;
 }
 
 word: "one" | "two" | "three"
 
 }) or die;
 
 for ("one two", "one one", "two three one", "three one two one") {
   print "$_ =>\n";
   print Dumper($parser->line($_));
 }
 
 # which generates:
 
 one two =>
   $VAR1 = [
 	   'one',
 	   'two'
 	  ];
 one one =>
   $VAR1 = undef;
 two three one =>
   $VAR1 = [
 	   'two',
 	   'three',
 	   'one'
 	  ];
 three one two one =>
   $VAR1 = undef;



=item * Embellishment by Damian Conway



Furthermore, if uniqueness was something you needed to enforce more
widely
in your grammar, you could factor it out into a parametric rule:

        use Parse::RecDescent;
        use Data::Dumper; $|++;
        my $parser = Parse::RecDescent->new(q{

        line: unique['word'] /\z/ { $return = $item[1] }

        unique: <matchrule: $arg[0]>(s)
            {
              my %seen;
              foreach (@{$item[1]}) { undef $item[1] and last if
$seen{$_}++ }
              $return = $item[1];
            }

        word: "one" | "two" | "three"

        }) or die;

        for ("one two", "one one", "two three one", "three one two
one") {
          print "$_ =>\n";
          print Dumper($parser->line($_));
        }



=back


=head1 CLEANING UP YOUR GRAMMARS

In honor of the original (and greatest) Perl book on cleaning up your
Perl code, this section is written in the style of 
Joseph Hall's "Effective Perl Programming"

=head2 Use repetition modifiers with a separator pattern to match
CSV-like data

The intuitive way to match CSV data is this:

 CSVLine:
      NonFinalToken(s?) QuotedText
 NonFinalToken: 
      QuotedText Comma
      { $return = $item[1] }

or, in other (merlyn's) words, "many comma terminated items followed by
one standalone item".

Instead, take the approach shown by merlyn:

 CSVLine: QuotedText(s Comma) { use Data::Dumper; Dumper($item[1]) }

Then just define C<QuotedText>, C<Comma>, and you're done!

=head1 OPTIMIZING YOUR GRAMMARS

=head2 Eliminate backtracking when possible

Let's take a look at two computationally equivalent grammars:

 expression      :       unary_expr PLUS_OP expression
                 |       unary_expr

versus

 expression      :       unary_expr plus_expression
 plus_expression :       PLUS_OP expression
                 |       # nothing

The second one is more efficient because it does not have to do backtracking.

The first one is more readable and more maintainable though. It is more 
readable because it doesnt have an empty rule. It is more maintainable because
as you add more expression types (minus_expression,
mult_expression...) you don't have to add an empty rule to each of
them. The top level description scales without change.

But, if speed is what you want then the second one is the way to go. 

=head2 Precompiling Grammars for Speed of Execution

Take a look at Parse::RecDescent's precompilation option under the section
titled "Precompiling parsers".

=head2 Parse::RecDescent is slow on Really Big Files. How can I speed it up?

=over 4

=item * Reduce the "depth" of the grammar. Use fewer levels
of nested subrules.

=item * Where possible, use regex terminals instead of subrules.  For 
example, instead of:

		string: '"' char(s?) '"'

		char:   /[^"\\]/
		    |   '\\"'
		    |   '\\\\'

write:

		string: /"([^"\\]|\\["\\])*"/

=item * Where possible, use string terminals instead of regexes.

=item * Use repetitions or <leftop>/<rightop> instead of recursion.

For example, instead of:

		list:  '(' elems ')'
		elems: elem ',' elems
		     | elem

write:

		list: '(' <leftop: elem ',' elem> ')'

or:

		list: '('  elem(s /,/)  ')'

=item * Factor out common prefixes in a set of alternate productions.

For example, instead of:
		
		id: name rank serial_num
		  | name rank hair_colour
		  | name rank shoe_size

write:
		  
		id: name rank (serial_num | haircolour | shoe_size)

=item * Pre-parse the input somehow to break it into smaller sections.
Parse each section separately.

=item * Precompile they grammar. This won't speed up the parsing, but it
will speed up the parser construction for big grammars (which
Really Big Files often require).

=item * Consider whether you would be better porting your grammar to
Parse::Yapp instead.

=back

=head1 CAPTURING MATCHES

=head2 Hey! I'm getting back ARRAY(0x355300) instead of what I set $return to!

Here's a prime example of when this mistake is made:

 QuotedText: 
       DoubleQuote TextChar(s?) DoubleQuote
       { my $chars = scalar(@item) - 1;  
         $return = join ('', @item[2..$chars]) }

This rule is incorrectly written. The author thinks that C<@item> will
have one C<TextChar> from position 2 until all C<TextChar>s are matched.
However, the true structure of C<@item> is:

=over 4

=item position one: the string matched by rule DoubleQuote

=item position two: array reference representing parse tree for TextChar(s?)

=item position three: the string matched by rule DoubleQuote

=back

Note that position two is an array reference. So the rule must be
rewritten in this way.

 QuotedText: 
       DoubleQuote TextChar(s?) DoubleQuote
       { $return = join ( '', @{$item[2]} ) }
     

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



=head2 Capturing whitespace between tokens

I need to capture the whitespace between tokens using Parse::RecDescent.
I've tried modifying the $skip expression to // or /\b/ (so I can tokenize
whitespace), but that doesn't seem to have the desired effect.

Just having a variable where all skipped whitespace is stored would be
sufficient.

Does anybody know how to trick Parse::RecDescent into doing this?

=over 4

=item * Answer by Damian Conway

To turn off whitespace skipping so I can handle it manually, I always use:

	<skip:''>

See:

	demo_decomment.pl
	demo_embedding.pl
	demo_textgen.pl

for examples.

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

=head1 THINGS NOT TO DO

=head2 Don't think that rule: statement and rule: statement(1) are the
same

Even though in pure Perl, the repetition modifier returns the same
data structure without or without an argument of one:

 use Data::Dumper;

 my @a = (x);
 my @b = (x) x 1;

 my $x = 'x';
 my $y = 'x' x 1;

In this first case below, C<rule_one> returns a scalar upon matching, 
while C<rule_two> returns an arrayref with 1 element upon matching:

 rule_one: statement
 rule_two: statement(1)

However counter-intuitive this may at first sound, Damian provides us with 
some insight:

I don't think C<x> is the right analogy for RecDescent repetition operators.
The behaviour of C<*> and C<+> in regexes is a closer model.

I guess it depends on your poitn of view. I would have said that the
absolute consistency with which *every* repetition (regardless of its
number) returns an array ref is better than the alternative:

        christmas:
                gold_rings(5)                   # returns array ref
                calling_birds(4)                # returns array ref
                French_hens(3)                  # returns array ref
                turtle_doves(2)                 # returns array ref
                partridge_in_a_pear_tree(1)     # returns scalar value

Especially if you have to change the count at some later point, which 
would mess up any code relying on the type of value returned.




=head2 Do not follow <resync> with <reject> to skip errors

C<resync> is used to allow a rule which would normally fail to "pass" so that 
parsing can continue. If you add the reject, then it unconditionally fails.

=head2 Do not assume that %item contains an array ref of all text matched for
a particular subrule

For example: 

        range: '(' number '..' number )'
                        { $return = $item{number} }

will return only the value corresponding to the last match of the C<number>
subrule.

To get each value for the number subrule, you have a couple of choices,
both documented in the Parse::RecDescent manpage under
C<@item and %item>.

=head2 use <rulevar: local $x> not <rulevar: $x> 

If you say:

	somerule: <rulevar: $x>

you get a lexical $x within the rule (only). If you say:

	somerule: <rulevar: local $x>

you get a localized $x within the rule (and any subrules it calls).

=head2 Don't use $::RD_AUTOACTION to print while you are parsing

You can't print out your result while you are parsing it, because you
can't "unprint" a backtrack.

Instead, have the final top-level rule do all the diagnostic printing, or
alternatively use P::RD's tracing functionality to observe parsing in 
action.

=head1 ERROR HANDLING

=head 2 Propagating a failure up after a <commit> on a subrule

See L<Commit in subrule which is optional in rule|Commit in subrule which is optional in rule>



=head2 In a non-shell (e.g. CGI) environment

I need to parse a file with a parser that I cooked up from
Parse::Recdescent. 
My problem, it must work in a cgi environment and the script must be
able to handle errors. I tried eval, piping, forking, Tie::STDERR, but
the errors msgs from Parse::Recdescent seem unstoppable.

I can catch them only by redirecting the script's STDERR from the
shell. But howdo I catch them from within ??

=over 4 

=item * Like this:

        use Parse::RecDescent;
        open (Parse::RecDescent::ERROR, ">errfile")
                or die "Can't redirect errors to file 'errfile'";

        # your program here

=back

=head2 Accessing error data

What I want to do is export a <error: foo bar> condition to the
calling
program.  Currently _error writes the error message to (what
essentially
is STDOUT) which means a parsing error prints a nice message, but it
is
up to the reader to DO anything about it.

I have a Tk viewer that will parse the file.  When the parse fails, I
would like to capture the line number and error message returned and
position the viewer (a text widget) to that line, highlighted.  And no
STDOUT message.

Something kind of like the eval function where the return value is the
result but $@ is set as a "side effect".

Am I missing something about the built in capability?  Is the solution
as simple as overloading the Parse::RecDescent::_error subroutine with
my own copy which might look like this:

%Parse::RecDescent::ERROR=();
...
sub Parse::RecDescent::_error($;$)
{
	$ERRORS++;
	return 0 if ! _verbosity("ERRORS");
	%Parse::RecDescent::ERROR=('line'=>$_[1],'msg'=>$_[0]);
	return 1;
}

It seems like it should work and I tried it and it did.  BUT this is
an
extremely complex bit of code and I'm concerned about unforseen
consequences.

Of course, I could make ERROR a my variable and provide a method to
access it so it is not a "global", and this would be OO code of a
higher
purity (or something), but that is not really the point.

=over 4

=item * Answer by Damian Conway

You can get access to the error data by referring to the attribute
C<$thisparser->{errors}> within a rule. 

C<$thisparser->{errors}> is a reference to an array of arrays. Each of
the inner arrays has two elements: the error message, and the line
number. 

So, for example, if your top-level rule is:

 start: subrule1 subrule2

then you could intercept any errors and print them to a log file, like
so: 

 start: subrule1 subrule2
      | { foreach (@{$thisparser->{errors}}) {
              print LOGFILE "Line $_->[1]:$_->[0]\n";
          }
          $thisparser->{errors} = undef;
        }

Note that the line:

 $thisparser->{errors} = undef;

is doing double duty. By resetting C<$thisparser->{errors}>, it's
preventing those annoying error messages from being automagically
printed. And by having the value C<undef> as the last value of the
action, it's causing the action to fail, which means the second
production fails, which means the top rule fails, which means errors
still cause the parse to fail and return C<undef>.

=back

=head2 Simple Error Handling

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

=head2 Collecting all error messages for processing

Is there a way to to collect the parser-generated errors and use them later 
on in my script?

=over 4

=item * Answer by Damian

There's no "official" way (yet). A future release will allow you
to create pluggable OO error handlers. At the moment the best 
you can do is:

	startrule: try_this
		 | try_that
		 | try_the_other
		 | { ::do_something_with( $thisparser->{errors} ) }

$thisparser->{errors} will contain a reference to an array-of-arrays,
where each inner array contains the error message and the line number
it occurred at.

=back

=head1 OTHER Parse::RecDescent QUESTIONS


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

=head1 REGULAR EXPRESSIONS

=head2 Shortest match instead of longest match

What is the Perl idiom for getting the leftmost shortest match?
For instance, so:

 $a = "banana";
 $a =~ /b.*n/;  # but different
 print $&;

would yield "ban" instead of "banan"?

=over 4

=item *

    $a =~ /b.*?n/;

=back



=head1 Programming Topics Germane to Parse::RecDescent Use

=head2 Double vs Single-quoted strings


I'm playing around with the <skip:> directive and I've noticed
something interesting that I can't explain to myself. 

Here is my script:

------ Start Script ------
use strict;
use warnings;

$::RD_TRACE = 1;

use Parse::RecDescent;

my $grammar = q{

   input:  number(s) { $return = $item{ number } } | <error>

   number: <skip: '\.*'> /\d+/ 

};

my $parser = new Parse::RecDescent($grammar);

my $test_string = qq{1.2.3.5.8};

print join( "\n", @{ $parser -> input( $test_string ) } );
------ End Script ------

This script works great. However, if I change the value of the skip
directive so that it uses double quotes instead of single quotes:

<skip: "\.*">

the grammar fails to parse the input. However, if I put square
brackets around the escaped dot:

<skip: "[\.]*">

the grammar starts working again:

How does this work this way?

=over 4

=item * Damian says:



This small test program may help you figure out what's going wrong:

	print "\.*", "\n";
	print '\.*', "\n";

Backslash works differently inside single and double quotes.
Try:

      <skip: "\\.*">

The reason the third variant:

      <skip: "[\.]*">

works is because it becomes the pattern:

	/[.]/

which is a literal dot.

=back

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


=item * Damian Conway says:

I have no recollection of why I did this (see children, that's
why you should *always* comment your code!).

I *suspect* it's vestigal -- from a time when contents of the
argument array reference were somehow modified in situ, but
it was important that the original argument's contents not
be changed.

The ungainly C<@{[@{$_[0]}]}> syntax is a way of (shallow)
copying the array referenced in $_[0] without declaring a new
variable. So another possible explanation is that evalop may
originally have been a one-liner, in which case I might have
used this "inlined copy" to keep the subroutine's body to a
single expression.

However...

   Even Damian can make a mistake

is by far the likeliest explanation.



=back



=head1 SEE ALSO

=over 4

=item * MySql to Oracle schema conversion utility

Written in Parse::RecDescent by Tim Bunce:

 http://groups.google.com/groups?q=recdescent&start=40&hl=en&scoring=d&rnum=41&selm=9km7b1%246vc%241%40FreeBSD.csie.NCTU.edu.tw

=item * Data::MultiValuedHash on search.cpan.org

Transparent manipulation of single or multiply-valued Perl hash values.

=item * Parse::Recdescent tutorial at www.perl.com

http://www.perl.com/pub/a/2001/06/13/recdecent.html

=item * "Safe undumping"

In this Linux Magazine article by Randal Schwartz uses
Parse::RecDescent to parse Data::Dumper output. Not fast, but quite
complete. 


=item * py

py, which I assume is short for C<parse yacc>, is a program by
Mark-Jason Dominus which parses GNU Bison output to produce Perl parsers.

It is obtainable from http://perl.plover.com/py/

=item * Parse::YAPP

A bottom-up parser which will be familiar to those who
have used Lex and Yacc. Parse::RecDescent is a top-down parser.

=item * Text::Balanced 

Use this instead of writing hairy regular expressions to match certain
common "balanced" forms of text, such as tags and parenthesized text.

=item * "Mastering Regular Expressions" by Jeffrey Freidl

You still need to know when to use /.*/ or /.+/ or /[^x]*/

=item * "Data Munging with Perl" by Dave Cross

Chapter 11 is focused on parsing with special emphasis on practical use of
Parse::RecDescent.

=item * "Object-Oriented Perl" by Damian Conway

This book will aid you in complexity management for large grammars.

=item * http://www.PerlMonks.org

A useful site to get fast help on Perl.

=back

=head1 AUTHOR

The author of Parse::RecDescent::FAQ is Terrence Brannon <tbone@cpan.org>. 

The author of Parse::RecDescent is Damian Conway. 

The (unwitting) contributors to this FAQ

=over 4 

=item * Me

=item * Damian Conway

=item * Marcel Grunaer

=item * Brent Dax

=item * Randal L. Schwartz (merlyn), Perl hacker

=item * lhoward of Perlmonks

=item * Matthew Wickline

=item * Gwynn Judd

=back 

=cut
