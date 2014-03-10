#!/usr/bin/perl

#---------------
#
#    FreeCheck - a free check printing application released
#                under the GNU General Public Licene.
#
#    Copyright (C) 2000 Eric Sandeen (eric_sandeen@bigfoot.com)
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#---------------

$ConfigFile = "freecheck.cfg";

# Some defaults...
$opt_account = "sample";
$opt_checktype = "MVG3001";
$opt_checkstyle = "normal";

use Getopt::Long;
#use Carp;

#use File::Slurp;

# This tells us how to format the strings from the cfg file
# so we can print it as a PostScript definition
# The key read will replace "value" for each of these
# Strings are enclosed in parentheses	(String)	(Foobar)
# Fonts are preceded by a "/"		/FontName	/Arial
# Digits are fine as they are		Digit		123
# Booleans are fine too			Bool		true
# But to be safe, do digits and bools as subroutines:
# Subroutines are in {}			{subr}		{3 mul}

%Formats = qw(
		# Globals
		MICRFontName		/value
		MICRFontSize		{value}
		TransitSymbol		(value)
		OnUsSymbol		(value)
		AmountSymbol		(value)
		DashSymbol		(value)
		MICRVerTweak		{value}
		MICRHorTweak		{value}
		# Account
		CheckNumber		{value}
		PrintCheckBody		{value}
		PrintMICRLine		{value}
		NumPages		{value}
		Name1			(value)
		Name2			(value)
		Address1		(value)
		Address2		(value)
		CityStateZip		(value)
		PhoneNumber		(value)
		BankName		(value)
		BankAddr1		(value)
		BankAddr2		(value)
		BankCityStateZip	(value)
		RoutingNumber		(value)
		AccountNumber		(value)
		Fraction		(value)
		PrintVOID		{value}
		# Styles
		StandardFontName	/value
		StandardFontSize	{value}
		CheckNumFont		/value
		CheckNumSize		{value}
		MemoLineHeight		{value}
		SignatureLineHeight	{value}
		BankInfoHeight		{value}
		AmountLineHeight	{value}
		PayeeLineHeight		{value}
		DateLineHeight		{value}
		# Check Blank Types
		CheckHeight		{value}
		CheckWidth		{value}
		CheckHorOffset		{value}
		CheckVerOffset		{value}
		ChecksPerPage		{value}
		LeftMargin		{value}
		RightMargin		{value}
		TopMargin		{value}
		);
			
# Parse command line options and deal with them:

GetOptions	("account:s",	# Account definition file 
		"checknum:i",	# Check number optional (overrides acct file)
		"pages:i",	# Number of pages to print
		"checkstyle:s",	# Check style (defaults to "normal_style.ps"
		"checktype:s",  # Check blank definition 
		"nomicr",       # Prevents MICR line from printing (body only)
		"nobody",	# Prevents body from printing (MICR line only)
		"test",		# Don't increment check no. and print VOID
		"help")

or Show_Usage();

if ($opt_help) {
	Show_Usage();
}

# Pull the config file into a string...
$config_file = read_file($ConfigFile);

# Go through the config and fill up a hash with PostScript defines...
Parse_Config($config_file);

# Overwrite anything we got from the config file with what was on the
# Command Line (if anything...)

if ($opt_checknum) {
	$Definitions{"CheckNumber"} = $opt_checknum;
}

if ($opt_pages) {
	$Definitions{"NumPages"} = $opt_pages;
}

if ($opt_nomicr) {
	$Definitions{"PrintMICRLine"} = "false";
}

if ($opt_nobody) {
	$Definitions{"PrintCheckBody"} = "false";
}

# This probably isn't in the config file (although it might be...)
# so cover both possibilites (true/false)
if ($opt_test) {
	$Definitions{"PrintVOID"} = "true";
} else {
	$Definitions{"PrintVOID"} = "false";
}

# Print PostScript

# Initial stuff:

print "%!\n";
print "/inch {72 mul} def\n";

# Go through $Definitions and print them out PostScript-Like
Print_Defs();

# Then print the main body
Print_Body();

# Update the config file with the new check number, if it's not just a test
if (!$opt_test) {
	$next_check_number = $Definitions{"CheckNumber"} 
		+ ($Definitions{"NumPages"} * $Definitions{"ChecksPerPage"});

	$config_file = Replace_Val($config_file, "Account", $opt_account, 
				"CheckNumber", $next_check_number);
	write_file ("freecheck.cfg", $config_file);
}

###############
# Subroutines #
###############

# read_file and write_file shamelessly stolen from the File::Slurp module
# Short enough, and I didn't want to require a non-standard module

sub read_file
{
	my ($file) = @_;

	local(*F);
	my $r;
	my (@r);

	open(F, "<$file") || die "open $file: $!";
	@r = <F>;
	close(F);

	return @r if wantarray;
	return join("",@r);
}

sub write_file
{
	my ($f, @data) = @_;

	local(*F);

	open(F, ">$f") || die "open >$f: $!";
	(print F @data) || die "write $f: $!";
	close(F) || die "close $f: $!";
	return 1;
}


sub Parse_Config {
	local ($config_file) = ($_[0]);
	# Find each section we're looking for...
	while ($config_file =~ /^\[\s*(
					Global |
					Account\s+${opt_account} | 
					Style\s+${opt_checkstyle} |
					CheckBlank\s+${opt_checktype}
					)\s*\]/xmgci) {
		# and get the lines under it one by one
		while ($config_file =~ /(^.+$)/mgc) {
			$line = $+;
			# If this line is a comment, skip it
			if ($line =~ /^#/) {
				next;
			}
			# If the line we just found is a new section..."[...]"
			if ($line =~ /\[.+\]/) {
				# and it is another section we're looking for
				# Grab the next line, and keep going
				if ($line =~ /\[\s*(
						Global |
						Account\s+${opt_account} |
						Style\s+${opt_checkstyle} |
						CheckBlank\s+${opt_checktype}
						)\s*]/xi) {
					# Grab the next line, and keep going
					next;
				} else {
					# Not a section we need, so break out
					# of the loop
					last;
				}
			}
			
			($key, $val) = split (/\s*=\s*/,$line);
			$Definitions{$key} = $val;
		} # line-by-line while
	} # section match conditional
}

sub Replace_Val {
	local ($string, $section, $name, $key, $value) = 
	      ($_[0],   $_[1],    $_[2], $_[3], $_[4]);
	# We want to get "[section name] ... key = value" and replace it
	# with the new value.
	
	# s - "." matches ANYTHING including newline
	# m - ^ and $ match after and before any newline
	# in this case, ".+?" means the minimum number of <anything> i.e. end
	# when we find the first instance of $key after [section name]
	$string =~ 
	s/(^\[\s*$section\s+$name\s*\].+?^${key}\s*=\s*).*?$/$+$value/smi;
	$string;
}

sub Show_Usage {
	print "\nFreeCheck v. 0.1 - a Free Check printing Utility\n\n";
	print "Usage: freecheck <options>:\n";
	print "\n";
	print "options:\n";
	print "  --account    <filename>    account to use (default \"$opt_account\")\n";
	print "  --checknum   <integer>     starting check number (overrides cfg)\n";
	print "  --pages      <integer>     number of pages to print (overrides cfg)\n";
	print "  --checkstyle <filename>    check style to use (default \"$opt_checkstyle\")\n";
	print "  --checktype  <filename>    blank check type to use (default \"$opt_checktype\")\n";
	print "  --nomicr                   print check body only, no MICR line\n";
	print "  --nobody                   print MICR line only, no check body\n";
	print "  --help                     print this message\n";
	print "  --test                     print but don't increment check number\n";
	print "                             and print VOID on the check\n";
	print "\nconfig file \"freecheck.cfg\" must be in the same directory,\n";
	print "as the freecheck executable (this will change in the future...)\n";
	die "\n";
}

sub Print_Defs {
	# Go through each def in the hash table, and print according to the
	# formatting hash
	while ( ($key, $val) = each (%Definitions) ) {
		print "/$key\t";
		$_ = $Formats{$key};
		s/value/$val/;
		print;
		print " def\n";
	}
}

sub Print_Body {

# This is the main body of the postscript file, that acts on all of the
# definitions we got from the config file.

print '
	% Other Constants:
	
	% Size of the rectangular box for the amount (digits)
	/AmountBoxWidth		{1 inch} def
	/AmountBoxHeight	{0.25 inch} def
	
	/LineWidth 		{0.3} def
	
	% Max number of digits in check number, and allocate string
	/CheckNumDigits 	4 def
	/CheckNumberString 	CheckNumDigits string def
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Helpful Printing Routines %
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
	% Shows a line, then does a "carriage return / line feed"
	% But only if the string exists (more than 0 chars)
	% (How do we get the current font size (height)?)
	
	/ShowAndCR {
		% A couple copies of the string (now 3 on stack)
		dup dup
		length 0 gt {	% First copy
			show		% Second copy
			stringwidth pop neg 0 rmoveto	% Third copy & move back
			neg 0 exch rmoveto % line down
		} if
	} def
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Feature Printing Routines %
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
	/DrawMemoLine {
		LeftMargin MemoLineHeight moveto
		2.5 inch 0 inch rlineto
		-2.5 inch 0 inch rmoveto
		0 2 rmoveto
		(for) show
	} def
	
	/DrawSignatureLine { % Expects height of signature line
			 % and right edge of check for
			 % beginning position
	
		CheckWidth SignatureLineHeight moveto
		RightMargin neg 0 rmoveto
		-2.5 inch 0 rmoveto
		2.5 inch 0 inch rlineto
	
	} def
	
	/DrawAmountLine {
		CheckWidth AmountLineHeight moveto
		RightMargin neg 0 rmoveto
		(DOLLARS) stringwidth pop neg 0 rmoveto
		(DOLLARS) show
		(DOLLARS) stringwidth pop neg 0 rmoveto
		-2 0 rmoveto
		LeftMargin AmountLineHeight lineto
	} def
	
	/DrawAccountHolderInfo {
		LeftMargin CheckHeight moveto
		0 TopMargin neg rmoveto
		0 StandardFontSize neg rmoveto
	
	
		StandardFontSize Name1 ShowAndCR
		%Name1 show
		%Name1 stringwidth pop neg StandardFontSize neg rmoveto
	
	
		StandardFontSize Name2 ShowAndCR
		% Show Name2 only if present
		%Name2 length 0 gt {
		%	Name2 show
		%	Name2 stringwidth pop neg StandardFontSize neg rmoveto
		%} if
	
		StandardFontName findfont
		StandardFontSize 1 sub scalefont
		setfont
	
		StandardFontSize 1 sub Address1 ShowAndCR
		%Address1 stringwidth pop neg StandardFontSize neg rmoveto
	
		% Show Address2 only if present
		Address2 length 0 gt {
			Address2 show
			Address2 stringwidth pop neg StandardFontSize neg rmoveto
		} if
	
		CityStateZip show
		CityStateZip stringwidth pop neg StandardFontSize neg rmoveto
	
		% Show PhoneNumber only if present
		PhoneNumber length 0 gt {
			PhoneNumber show
			PhoneNumber stringwidth pop neg StandardFontSize neg rmoveto
		} if
		
		StandardFontName findfont
		StandardFontSize 1 add scalefont
		setfont
	} def
	
	/DrawDateLine {
		0.6 CheckWidth mul DateLineHeight moveto
		(Date) show
		1 inch 0 rlineto
	} def
	
	/DrawBankInfo {
		LeftMargin BankInfoHeight moveto
	
		BankName show
		BankName stringwidth pop neg StandardFontSize neg rmoveto
	
		StandardFontName findfont
		StandardFontSize 1 sub scalefont
		setfont
		
		BankAddr1 show
		BankAddr1 stringwidth pop neg StandardFontSize neg rmoveto
	
		% Show Addr2 only if present
		BankAddr2 length 0 gt {
			BankAddr2 show
			BankAddr2 stringwidth pop neg StandardFontSize neg rmoveto
		} if
	
		BankCityStateZip show
		BankCityStateZip stringwidth pop neg StandardFontSize neg rmoveto
	
		StandardFontName findfont
		StandardFontSize 1 add scalefont
		setfont
	} def
	
	/DrawPayeeLine {
	
		LeftMargin PayeeLineHeight moveto
		(ORDER OF) show
		(ORDER OF) stringwidth pop neg  StandardFontSize rmoveto
		(PAY TO THE) show
		0 StandardFontSize neg rmoveto
		4 0 rmoveto
		currentpoint mark
		
		CheckWidth PayeeLineHeight moveto
		RightMargin neg 0 rmoveto
		AmountBoxWidth neg 0 rmoveto
	
		0 AmountBoxHeight rlineto
		AmountBoxWidth 0 rlineto
		0 AmountBoxHeight neg rlineto
		AmountBoxWidth neg 0 rlineto
	
		-4 0 rmoveto
		
		/Helvetica-Bold findfont
		14 scalefont
		setfont
		
		($) stringwidth pop neg 0 rmoveto
		($) show
		($) stringwidth pop neg 0 rmoveto
		
		-4 0 rmoveto
		cleartomark
		lineto
	
		StandardFontName findfont
		StandardFontSize scalefont
		setfont
	
	} def
	
	/DrawMICR {
		% 0.25 high, 5.6875 from right edge should be in the middle 
		% of the tolerance band
		CheckWidth 0.25 inch moveto
		-5.6875 inch 0 inch rmoveto
		MICRHorTweak MICRVerTweak rmoveto
	
		save
			MICRFontName findfont
			MICRFontSize scalefont
			setfont
			TransitSymbol show
			RoutingNumber show
			TransitSymbol show
			( ) show
			% Pad with spaces if acct number is short
			12 AccountNumber length sub {( ) show} repeat
			AccountNumber show
			OnUsSymbol show
			( ) show
			% Same deal, pad w/ 0s if short check number
			CheckNumDigits 1 sub -1 1 
				{CheckNumberString exch get 0 eq {(0) show} if } for
			CheckNumberString show
		restore
	} def
	
	/DrawCheckNumber {
		CheckWidth CheckHeight moveto
		RightMargin neg TopMargin neg rmoveto
		CheckNumFont findfont
		CheckNumSize scalefont
		setfont
	
		CheckNumberString stringwidth pop neg 0 rmoveto
		0 -14 rmoveto
		CheckNumberString show
	
		StandardFontName findfont
		StandardFontSize scalefont
		setfont
	} def
	
	/DrawFraction {
		0.6 CheckWidth mul CheckHeight moveto
		0 TopMargin neg rmoveto
		0 StandardFontSize neg rmoveto
		Fraction show
	} def
	
	/DrawStub {
		CheckHorOffset 2 inch ge {
			save
			newpath
			CheckHorOffset neg 0 translate
			StandardFontName findfont
			StandardFontSize 1 sub scalefont
			setfont
			/StubSpacing {CheckHeight 6 div} def
			CheckHorOffset 2 div StubSpacing 5 mul moveto
			CheckNumberString show
			0.3 inch StubSpacing 4 mul moveto
			(Date ) show
			CheckHorOffset 0.3 inch sub StubSpacing 4 mul lineto
			0.3 inch StubSpacing 3 mul moveto
			(Payee ) show
			CheckHorOffset 0.3 inch sub StubSpacing 3 mul lineto
			0.3 inch StubSpacing 2 mul moveto
			(Amount ) show
			CheckHorOffset 0.3 inch sub StubSpacing 2 mul lineto
			0.3 inch StubSpacing 1 mul moveto
			(Memo ) show
			CheckHorOffset 0.3 inch sub StubSpacing 1 mul lineto
			stroke
			restore
		} if
	} def	
	
	/DrawVOID {
		save
		StandardFontName findfont
		50 scalefont
		setfont
		newpath
		CheckWidth 2 div 1 inch moveto
		30 rotate
		(V O I D) stringwidth pop 0 moveto
		(V O I D) true charpath
		stroke
		restore
	} def
	
	/DrawCheck {
		% Temporarily draw boxes around the checks
		0 0 moveto
		CheckWidth 0 lineto
		CheckWidth CheckHeight lineto
		0 CheckHeight lineto
		0 0 lineto
	 
		% Convert CheckNumber integer to a string
		PrintCheckBody {
			CheckNumber CheckNumberString cvs
			DrawBankInfo
			DrawAccountHolderInfo
			DrawMemoLine
			DrawSignatureLine
			DrawAmountLine
			DrawPayeeLine
			DrawCheckNumber
			DrawFraction
			DrawDateLine
		} if
	
		PrintMICRLine {
			DrawMICR
		} if
	
		PrintVOID {
			DrawVOID
		} if
	
	} def
	
	
	/CurrentPage 1 def
	
	NumPages -1 1 {
		/CheckNumber CheckNumber ChecksPerPage add def
		CheckHorOffset CheckVerOffset translate
	
		StandardFontName findfont
		StandardFontSize scalefont
		setfont
	
		LineWidth setlinewidth
	
		% Loop through printing checks, starting with the bottom one
	
		ChecksPerPage -1 1 {
			/CheckNumber CheckNumber 1 sub def
			newpath
	
			DrawCheck
			DrawStub % But only if there is room
	
			stroke
			0 CheckHeight translate
		} for
	
		showpage
		/CheckNumber CheckNumber ChecksPerPage add def
		/CurrentPage CurrentPage 1 add def
	
	} for
	';
	
}
