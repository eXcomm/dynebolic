# menugen is a AWK script that generates menus of various formats
# for window managers and GUIs used in dyne:bolic, see http://dynebolic.org

# this script reads the dyne:bolic application list (see dyne.applist)
# checks for the availability of each command and if present
# adds the entry into the menu thru the requested renderer
#
# render mode is defined on commandline, to call this script do:
# cat dyne.applist | awk -f menugen.awk -v render=fluxbox > fluxbox.menu
#
# this script is Copyleft (C) 2005-2006 by Denis "jaromil" Rojo
#
# This source code is free software; you can redistribute it and/or
# modify it under the terms of the GNU Public License as published
# by the Free Software Foundation; either version 2 of the License,
# or (at your option) any later version.
#
# This source code is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# Please refer to the GNU Public License for more details.
#
# You should have received a copy of the GNU Public License along with
# this source code; if not, write to:
# Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# debug function
function debug(msg) {
	if( DEBUG == "true" ) print msg
}

# here we go with the renderers. let's remind the format:
# nome | descrizione | comando | flags | web url | autore
# flags:
#   multi     = multiple instances of the application can be launched
#   nocheck   = don't check for the presence of the application
#   manual    = don't start the application, but show it's manpage
#   terminal  = launch the application in a terminal
#   literal   = include the entry as is, without parsing fields
#   root      = run the executable as root (will ask for password)
#   user      = executable cannot be run as root (use luther instead)

function render_fluxbox() {

	if ($4 ~ "manual" ) # CLI sw, RTFM
	   # let's skip it for now
           return
        fi

	# if we have submenus to render in queue, then do it now
	# that we are sure there is an executable for them
	for(c=0; c<qsub_num; c++) {
		line = "[submenu] (" qsubmenu[c+1] " )"

		print line

		delete qsubmenu[c+1]
	}
	qsub_num = 0 # all queue is flushed now

	line = "[exec] (" $1 " :: " $2 ") {"

	command = "launch "

	if ($4 ~ "root" ) # run as root
	   command = "launchroot "

        if ($4 ~ "user" ) # run as user
           command = "launchuser "
	     
	if ($4 ~ "terminal" ) # run into a terminal
	   command = "launchterm '" $1 " :: " $2 "' "

	command = command $3 "}"

	print line command

}

function render_xfce() {

  if ($4 ~ "manual" ) # CLI sw, RTFM
# let's skip it for now
    return
      fi
      
# if we have submenus to render in queue, then do it now
# that we are sure there is an executable for them
      for(c=0; c<qsub_num; c++) {
	
	menu_icon="emblem-generic"

		if      (qsubmenu[c+1] ~ "AUDIO")  menu_icon="gnome-settings-sound"
		else if (qsubmenu[c+1] ~ "VIDEO") menu_icon="gnome-multimedia"
		else if (qsubmenu[c+1] ~ "IMAGE") menu_icon="gnome-graphics"
                else if (qsubmenu[c+1] ~ "TEXT")  menu_icon="gnome-applications"
		else if (qsubmenu[c+1] ~ "NET") menu_icon="xfce-internet"
		else if (qsubmenu[c+1] ~ "DEVEL") menu_icon="gnome-devel"
		else if (qsubmenu[c+1] ~ "GAMES")  menu_icon="xfce-games"
		else if (qsubmenu[c+1] ~ "FILES") menu_icon="disks"
		else if (qsubmenu[c+1] ~ "OFFICE") menu_icon="ooo_calc"
		else if (qsubmenu[c+1] ~ "XUTILS") menu_icon="gnome-util"
	        else if (qsubmenu[c+1] ~ "PLAY" ) menu_icon="stock_media-play"
		else if (qsubmenu[c+1] ~ "PERFORM" ) menu_icon="stock_midi"
		else if (qsubmenu[c+1] ~ "EDIT" ) menu_icon="stock_mic"
       		else if (qsubmenu[c+1] ~ "STREAM" ) menu_icon="stock_channel"
                else if (qsubmenu[c+1] ~ "MANUALS" ) menu_icon="gdict"


		line = "	<menu name=\"" qsubmenu[c+1] "\" icon=\"" menu_icon "\">"

		print line

		delete qsubmenu[c+1]
		  
	}

	qsub_num = 0 # all queue is flushed now

	line = "	<app name=\"" $1 " :: " $2 "\" "

	command = "cmd=\"launch "

	if ($4 ~ "root" ) # run as root
	   command = "cmd=\"launchroot "
	else if ($4 ~ "user" ) # run as user
           command = "cmd=\"launchuser "

	if ($4 ~ "terminal" ) # run into a terminal
	   command = "cmd=\"launchterm '" $1 " :: " $2 "' "

        if      ($1 ~ "CONFIGURE" ) icon="gnome-settings"
	command = command $3 "\" icon=\"" icon "\"/>"

	print line command

}


function render_wmaker() {

	# if a menu should be open, do it now
	# that we are sure entries are present
	# so let's render all queued submenus
	for(c=0; c<qsub_num; c++) {

		line = "( \"" qsubmenu[c+1] "\""

		# termination issue
		# if ( menustart == 1 ) print ","
		# else menustart = 1
		print ","

		print line

		delete qsubmenu[c+1]
	}
	qsub_num = 0 # all queue is flushed now

	# in any case print a comma before the new entry
	print ","

	print "(\"" $1 " :: " $2 "\","

        # shortcut hack
        if ( $1 ~ "XVT" ) print " SHORTCUT, \"Mod1+x\", "

        print "EXEC,"

        title = $1 "_::_" $2

	command = "launch "

	if ( $4 ~ "term" ) { # prefix the terminal launcher
                gsub(/\ /, "_", title)
		command = "launchterm " title
        }

	if ($4 ~ "root" ) # run as root
	   command = "launchroot "

        if ($4 ~ "user" ) # run as user
           command = "launchuser "

	command = command $3

	print " \"" command "\")"

}

BEGIN {

	# set the field separator as a pipe "|"
	FS = "|"

	##### detect the rendered output
	if ( render == "wmaker" ) {

		windowmanager = "WindowMaker"
                print "(\"dyne:II\""

        } else if ( render == "icewm" ) {

		windowmanager = "IceWM"

	} else if ( render == "fluxbox" ) {

		windowmanager = "Fluxbox"
		print "# Fluxbox menu generated by dynemenu.awk"
		print "# this file is automatically generated at boot"
		print "# to add you own entries, use ~/.fluxbox/usermenu"
		print "[begin] (dyne:II)"

		  
        } else if (render == "xfce" ) {

                windowmanager = "Xfce"

	} else {
		print "unrecognized renderer"
		print "please specify \"-v render=param\" on commandline"
		print "param can be one of: wmaker, icewm or fluxbox"
		exit
	}

	debug("Rendering " windowmanager " menu")
	#####

	##### initialize variables
	sub_num = 0
	qsub_num = 0
}

END {

# TERMINATION ISSUE HERE
# this script doesn't closes the menu structure,
# it will be done back in the check_apps_present() function of wmaker.sh
# anyway, uncomment below to have complete generation within this script
#	if ( render == "fluxbox" ) {
#
#	  print  "[end]"
#
#	} else if ( render == "wmaker" ) {
#
#       print  "\n)"
#
#	}

}

/^#/ { next } # skip comments

/Begin/ { # enter a sub menu

	sub_num++
	submenu[sub_num] = $2
	debug( "enter submenu " submenu[sub_num] )

	# queue the submenu: will not print if no entry for it
	qsub_num++
	qsubmenu[qsub_num] = submenu[sub_num] # tabulation line

	next

}

/End/ { # end a sub menu

	if( sub_num < 1) {
		print "ERROR on line " NR ": cannot end submenu, none opened"
		exit
	}

	if( submenu[sub_num] != $2 ) {
		print "ERROR on line " NR ": can't close submenu " $2
		print "      current submenu is " submenu[sub_num]
		exit
	}

	if( submenu[sub_num] == qsubmenu[qsub_num] ) {
		debug( "closing unrendered menu" )
		delete qsubmenu[qsub_num]
		delete submenu[sub_num]
		sub_num--
		qsub_num--
		next
	}

	# use selected render
	if( render == "wmaker" ) {

		print "\n"
		line = ")"

	} else if ( render == "fluxbox" ) {

	  line = "[end]"

        } else if ( render == "xfce" ) {
	  
	  line = "	</menu>"

	}
	# fill in missing renderers

	print line

	debug( "end submenu " submenu[sub_num]  )
	delete submenu[sub_num]
	sub_num--

	next
}


{
	# skip blank lines
	if( NF == 0 ) next

	if      ( render == "wmaker" )  render_wmaker()
	else if ( render == "fluxbox" ) render_fluxbox()
        else if ( render == "xfce" )    render_xfce()

	# fill in missing renderers
}
