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

###########################################
# WARNING WARNING WARNING WARNING WARNING #
###########################################
# THIS CODE EXECUTES AT LEAST ONE EXTERNAL PROGRAM, BASED ON
# STRINGS PASSED IN FROM THE FORM.  A FEEBLE EFFORT HAS BEEN
# MADE TO SANITIZE THOSE STRINGS, BUT THERE COULD STILL BE
# A SECURITY RISK HERE.  YOU HAVE BEEN WARNED
##########################################

# This script will generate a form that allows users to fill out information to
# be printed on checks, and they get back either a PostScript or a PDF document.
# Currently, the freecheck script and config files need to be in the same dir as
# the CGI.  If you want to generate PDFs, you need GhostScript.  You also really
# need the 6.x series, or the PDFs will look horrible, and checks printed almost
# certainly will not be machine readable.

# The freecheck executable script, and the freecheck config file
# (freecheck.cfg) should be in the same dir as this script.

use CGI qw(:standard);

# The path to the GhostScript executable, with escaped "/"s
$GS = "\/usr\/bin\/gs";

# Parameters to GhostScript to generate PDFs (trailing "-" means STDIN
$PDFOptions = "-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=- -";


# Get the cookie to set the defaults, if it's there...
%pairs_hash = cookie('FreeCheck');

# If it's not there, set minimum defaults so the main script won't bonk
if (!%pairs_hash) {
	%pairs_hash = (	"NumPages", "1",
			"PrintCheckBody", "true",
			"PrintMICRLine", "true",
			"CheckNumber", "100");
}

# If we have no parameters passed, generate the initial page with default vals
# Those defaults might be from a cookie (above) if one has been set.
if (!param()) {
	print header;
	print start_html('FreeCheck Online'),
	#"Cookie:",br,
	#%pairs_hash,
	h1('FreeCheck'),
	"A free check printing utility",
	br,
	"Version 0.21",
	br,
	"Copyright (C) 2000 Eric Sandeen (eric_sandeen @ bigfoot.com)",
	hr,
	"WARNING - unless you're brave, treat this application as a
	proof-of-concept, rather than a useful utility.  I have not
	had a chance to test this stuff with a bank yet, and I'm also
	a bit concerned about the accuracy during conversion to 
	PDF.  Just don't go paying your rent with this yet, ok?  :)",
	hr,
	start_form,
	submit(	-name=>"Submit",
		-label=>" Get my checks! "),
	h2('Check Information'),
	h3('Account Holder Information'),

	textfield(	-name=>'Name1',
			-default=>$pairs_hash{"Name1"},
			-maxlength=>50),
	" Name 1", br,

	textfield(	-name=>'Name2',
			-default=>$pairs_hash{"Name2"},
			-maxlength=>50),
	" Name 2", br,

	textfield(	-name=>'Address1',
			-default=>$pairs_hash{"Address1"},
			-maxlength=>50),
	" Address Line 1", br,

	textfield(	-name=>'Address2',
			-default=>$pairs_hash{"Address2"},
			-maxlength=>50),
	" Address Line 2", br,

	textfield(	-name=>'CityStateZip',
			-default=>$pairs_hash{"CityStateZip"},
			-maxlength=>50),
	" City, State, Zip", br,

	textfield(	-name=>'PhoneNumber',
			-default=>$pairs_hash{"PhoneNumber"},
			-maxlength=>50),
	" Phone Number", br,

	h3('MICR Line Information'),
	"Pay close attention here - this is where you enter the MICR
	 line at the bottom of your check.  For the following symbols,
         use these characters:", p,

	hr,
	img {-src=>'/images/transit.gif'}, " = \"R\"", br,
	img {-src=>'/images/onus.gif'}, " = \"P\"", br,
	img {-src=>'/images/dash.gif'}, " = \"-\" (dash, or minus)", p,
	"For spaces, enter \"S\"", p,
	"For check numbers, enter a \"C\" for each check digit", p,
	hr,

	"Auxiliary On-Us field - Everything to the left of the leftmost ",
	img {-src=>'/images/transit.gif'}, " symbol",  br,
	em("Don't forget to include trailing spaces (\"S\")!"), br,
	"This field may not be present on personal checks", br,

	textfield(	-name=>'AuxOnUs',
			-default=>$pairs_hash{"AuxOnUs"},
			-maxlength=>50),

	" Auxiliary On-Us field", p,
	
	"Transit / Routing Field - 9 numbers between, and including, the ",
	img {-src=>'/images/transit.gif'}, " symbols",  br, 
	
	textfield(	-name=>'Routing',
			-default=>$pairs_hash{"Routing"},
			-size=>11, -maxlength=>11),

	" Routing Field", p,

	"On-Us field - everything to the right of the rightmost ",
	img {-src=>'/images/transit.gif'}, " symbol",  br,
	em("Don't forget to include leading spaces (\"S\")!"), br,

	textfield(	-name=>'OnUs',
			-default=>$pairs_hash{"OnUs"},
			-maxlength=>50),

	" On-Us field", p,

	textfield(	-name=>'Fraction', 
			-default=>$pairs_hash{"Fraction"},
			-maxlength=>50), 

	" Fraction (printed at top right of check)", br,

	h3('Bank Information'),
	textfield(	-name=>'BankName', 
			-default=>$pairs_hash{"BankName"},
			-maxlength=>50), 
	" Bank Name", br,

	textfield(	-name=>'BankAddr1', 
			-default=>$pairs_hash{"BankAddr1"},
			-maxlength=>50),
	" Bank Address1", br,

	textfield(	-name=>'BankAddr2', 
			-default=>$pairs_hash{"BankAddr2"},
			-maxlength=>50),
	" Bank Address 2", br,

	textfield(	-name=>'BankCityStateZip', 
			-default=>$pairs_hash{"BankCityStateZip"},
			-maxlength=>50),
	" Bank City, State, Zip", br,

	h2('Printing Options'),
	textfield(	-name=>'CheckNumber', 
			-default=>$pairs_hash{"CheckNumber"}, 
			-size=>10, 
			-maxlength=>10),
	" Starting Check Number", 
	br,

	"Select check style: ",
	popup_menu(	-name=>'CheckStyle',
			-values=>['Normal','Quicken_Personal'],
			-default=>$pairs_hash{"CheckStyle"}),
	br,

	"Select check blank: ",
	popup_menu(	-name=>'CheckType',
			-values=>['MVG3001','MVG1000','MVD1001'],
			-default=>$pairs_hash{"CheckType"},
			-labels=>{	'MVG3001'=>'VersaCheck MVG3001',
					'MVG1000'=>'VersaCheck MVG1000',
					'MVD1001'=>'VersaCheck MVD1001'}),
        p,


	checkbox(	-name=>'PrintCheckBody', 
			-checked=>$pairs_hash{"PrintCheckBody"},
			-value=>'true', 
			-label=>' Print Check Body'), 
	br,

	checkbox(	-name=>'PrintMICRLine', 
			-checked=>$pairs_hash{"PrintMICRLine"},
			-value=>'true',
			-label=>' Print MICR Line'),
	br,

	checkbox(	-name=>'Test',
			-checked=>$pairs_hash{"Test"},
			-value=>'true',
			-label=>' Print voided test checks'),
	p,

	"Select Output Format:",
	br,
	em("Be sure to de-select \"Fit to Page\" when printing PDFs"),
	br,
	em("To view PostScript correctly, you must have the
	    GnuMICR font installed locally"),
	br,
	radio_group(	-name=>'OutputType', 
			-values=>['PDF', 'PostScript'],
			-labels=>{'PDF'=>' PDF', 
				  'PostScript'=>' PostScript'},
			-default=>$pairs_hash{"OutputType"}, 
			-linebreak=>'true'), 
	br,

	"Number of Pages to Print: ",
	textfield(	-name=>'NumPages', 
			-default=>$pairs_hash{"NumPages"},
			-size=>2, 
			-maxlength=>1),
	p,

	"Save information in a cookie?",
	br,
	em("Note: if you're security-paranoid, and you've entered real data,
	this might not be a such a good idea at this point..."),
	br,
	radio_group(	-name=>'Cookie',
		 	-values=>['ClearCookie', 'SetCookie'],
			-default=>$pairs_hash{"Cookie"},
		 	-labels=>{'ClearCookie'=>' Don\'t set, or clear',
				 'SetCookie'=>' Set a cookie'},
			-linebreak=>'true'),
	br,
	submit(	-name=>"Submit",
		-label=>" Get my checks! "),
	end_form,
	em("If Netscape wants to save \"freecheck.cgi\" just rename it to
	    \"mychecks.[pdf,ps]\" - I don't know why this happens"),
	hr;
	print end_html;
}

# If Submit button has been pressed , then process the values
if (param("Submit")) {

	# Get a hash of all the fields and their values
	my @names = param();
	$pairs_string = "";
	foreach (@names) {
		$name = $_;
		$value = param($_);
		#$pairs_string = $pairs_string . $_ . " $value\n";
		$pairs_hash{$name} = $value;
	}
	# "Submit" is the only thing we don't want to store
	delete $pairs_hash{"Submit"};
	
	# Deal with the form elements that didn't go in the hash:
	$CheckStyle = param("CheckStyle");
	$CheckType  = param("CheckType");

	# For checkboxes, delete them from the hash/cookie if not checked
	if ( param("PrintMICRLine") ne "true" ) {
		$MICR = "--nomicr";
		delete $pairs_hash{"PrintMICRLine"};
	}

	if ( param("PrintCheckBody") ne "true" ) {
		$BODY = "--nobody";
		delete $pairs_hash{"PrintCheckBody"};
	}

	if ( param("Test") eq "true") {
		$TEST = "--test";
	} else {
		delete $pairs_hash{"Test"};
	}

	# Turn the hash into a string (this is a bit goofy, I guess...)
	# We do it as a hash initially to make it easier to fill in the
	# forms, above.
	# This is what is passed to the check generation script

	$pairs_string = "";
	$NotDefs="Submit Cookie Test OutputType CheckStyle CheckType";
	while ( ($name,$value) = each(%pairs_hash) ) {
		unless ($NotDefs =~ /${name}/ ) {
			$pairs_string = $pairs_string . "$name $value\n";
		}
	}

	# Create the argument string
	$arguments = "--checkstyle $CheckStyle --checktype $CheckType $MICR $BODY $TEST";

        # This is where we should set the next check number to be printed,
        # if we knew how many checks per page we had... any good way
        # to do this....? For now, we'll just set things up semi-manually

	%ChecksPerPage =
	("MVG3001", "3", "MVG1000", "1", "MVD1001", "1");

	$NextCheckNumber = param("CheckNumber") +
			param("NumPages") *
			$ChecksPerPage{param("CheckType")};

	$pairs_hash{"CheckNumber"} = $NextCheckNumber;

	# Sanitize $pairs_string and $arguments
	# Let's not go spawning any new shells (this is minimal security...)
	# Also checks for SSI strings

	# Look for SSI
	if ($pairs_string =~ /\<\!--\#(.*)\s+(.*)\s?=\s?(.*)--\>/s) {
		kill_input();
	}

	if ($arguments =~ /\<\!--\#(.*)\s+(.*)\s?=\s?(.*)--\>/s) {
		kill_input();
	}

	# Look for shell metachars
	if ($pairs_string =~ /[;><\*`\|]/s) {
		kill_input();
	}

	if ($arguments =~ /[;><\*`\|]/s) {
		kill_input();
	}

	if ( param("Cookie") eq "SetCookie" ) {
		$cookie = cookie(	-name=>'FreeCheck',
					-value=>\%pairs_hash,
					-expires=>'+6M',
					-path=>script_name(),
					-domain=>server_name());
	} elsif ( param("Cookie") eq "ClearCookie" ) {
		$cookie = cookie(	-name=>'FreeCheck',
					-value=>'',
					-expires=>'+1m',
					-path=>script_name(),
					-domain=>server_name());
	}

	# Generate the actual output.  
	# The PDF thing might become an option in the main script
	# soon...
	###########################################
	# WARNING WARNING WARNING WARNING WARNING #
	###########################################
	# THIS CODE EXECUTES AT LEAST ONE EXTERNAL PROGRAM, BASED ON
	# STRINGS PASSED IN FROM THE FORM.  A FEEBLE EFFORT HAS BEEN
	# MADE TO SANITIZE THOSE STRINGS, BUT THERE COULD STILL BE 
	# A SECURITY RISK HERE.  YOU HAVE BEEN WARNED

	if (param("OutputType") eq "PDF") {
		$PDFConvert = "\| $GS $PDFOptions";
	}

	#print (`.\/freecheck --cgi \"$pairs_string\" $arguments \| $GS $PDFConvert`);
	# This is just the postscript result, or the error:
	$Result = `.\/freecheck --cgi \"$pairs_string\" $arguments`;

	if (length($Result) < 500 ) { # Anything this short is an error...
		print header;
		print start_html("We encountered an error...");
		print h1("There are some errors on your form:");
		# HTML-ify the result ( \n to <br> )
		$Result =~ s/\n/<br>/gsm;
		print $Result;
		print br;
		print "Press the Back button on your browser to fix them...";
		print p;
		print em("If you select \"Print voided test checks\" then
			  MICR consistency checking will not be performed");
		print end_html;
		exit;
	}
	
	# Otherwise, generate the apropriate header...
	# And send the data
	if (param("OutputType") eq "PDF") {
		print header(	-type=>'application/pdf',
				-attachment=>'mychecks.pdf',
				-cookie=>$cookie);

	# This is bad... running the script a 2nd time... must be a better
	# way.  Like open(PDF, "|$GS $PDFConvert
	#open (PDF, "| $PDFConvert");
	#print PDF $Result;
	#close(PDF);

	print (`.\/freecheck --cgi \"$pairs_string\" $arguments \| $GS $PDFOptions`);
	} else {
		print header(	-type=>'application/postscript',
				-attachment=>'mychecks.ps',
				-cookie=>$cookie);

		print $Result;
	}
	
	exit;
}

sub kill_input {
	print header;
	print start_html("Problem with those strings...");
	print "You seem to have some shell metacharacters in your ";
	print "entered strings.  Sorry, you can't do that...";
	print p;
	print "Please get those funky things out of your form, and try again";
	print p;
	print "You can hit the back button to go back to your form.";
	print end_html;
	exit;
}
