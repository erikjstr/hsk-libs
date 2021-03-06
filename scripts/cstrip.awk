#!/usr/bin/awk -f
#
# Seperates C instructions into individual lines, streamlining the formatting
# for parsing in other scripts.
#
# Arguments starting with a dash are passed to each CPP instance, arguments
# the remaining arguments are treated as file names.
#

##
# Initialise globals and process command line arguments.
#
# The following globals are created:
# - CPP: The C preprocessor to use, either from the environment variable
#   with the same name or the default "cpp"
# - DEBUG: Defaults to the environment variable with the same name
#
BEGIN {
	# Get environment settings
	CPP = ENVIRON["CPP"] ? ENVIRON["CPP"] : "cpp"
	DEBUG = ENVIRON["DEBUG"]

	RS = "\0"
	# Collect parameters
	for (i = 1; i < ARGC; i++) {
		if (ARGV[i] ~ /^-.$/) {
			CPP = CPP " " ARGV[i] " " ARGV[i + 1]
			delete ARGV[i++]
			delete ARGV[i]
		} else if (ARGV[i] ~ /^-/) {
			CPP = CPP " " ARGV[i]
			delete ARGV[i]
		}
	}

	if (DEBUG) {
		print "cstrip.awk: CPP = " CPP > "/dev/stderr"
	}
}

##
# Accumulate and preprocess files so they become easier to parse.
#
!visited[FILENAME]++ {
	if (DEBUG) {
		print "cstrip.awk: processing " FILENAME > "/dev/stderr"
	}
	# Preprocess file, so there is no trouble with unknown symbols
	cmd = CPP " " FILENAME " 2> /dev/null"
	$0 = ""
	while (cmd | getline line) {
		$0 = $0 line "\n"
	}
	close(cmd)
	# Remove escaped newlines
	gsub(/\\(\r\n|\n)/, " ")
	# Remove comments
	gsub(/\/\*(\*[^\/]|[^\*])*\*\//, "")
	# Isolate preprocessor comments
	gsub(/(^|\n)[ \t]*#[^\n]*/, "&\177")
	# Collapse spaces
	gsub(/[ \t\r\n]+/, " ")
	# Remove obsolete spaces
	sub(/^ /, "")
	split("{}()|?*+^[].", ctrlchars, "")
	for (i in ctrlchars) {
		gsub(" ?\\" ctrlchars[i] " ?", ctrlchars[i])
	}
	split("#=!<>;:,/-%~\"\177", ctrlchars, "")
	ctrlchars["&"] = "\\&"
	for (i in ctrlchars) {
		gsub(" ?" ctrlchars[i] " ?", ctrlchars[i])
	}
	# Add newlines behind statements
	gsub(/\177/, "\n")
	gsub(/;/, "&\n")
	# Segregate nested code
	gsub(/[{}]/, "\n&\n")
	# Segregate labels from the code following them
	gsub(/:([a-zA-Z0-9_]+|case [^:]+):/, "&\n")
	gsub(/(^|\n)([a-zA-Z0-9_]+|case [^:]+):/, "&\n")
	# Remove empty lines
	gsub(/\n+/, "\n")
	printf "#1\"%s\"\n%s", FILENAME, $0
	nextfile
}

