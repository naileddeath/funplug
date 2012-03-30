#!/ffp/bin/sh
#
# Proposed directory structure:
# ROOT ($DIR_ROOT)
#     config ($DIR_CONFIG)
#         rsyncpasswd
#     definitions ($DIR_DEFINITIONS)
#         nano($X)
#             nano.funpkg
#     destdir ($DIR_DESTDIR)
#         nano ($F)
#             nano-2.2.5-arm-1.txz
#             nano-2.2.6-arm-1.txz
#     logs ($DIR_LOGS)
#     release ($DIR_RELEASE)
#         0.7
#             arm
#                 app-editors
#                     nano-2.2.6-arm-1.txz
#     temp ($DIR_TEMP)
#     work ($DIR_WORK)
#         nano
#             2.2.6
#                 distdir ($DIR_DIST)
#                 1 ($W)
#                     pkg ($D)
#                         ffp
#                         install
#                     nano-2.2.6 ($E)
#
###############################################################################
# Just to remember, the ffp package structure needs to be as follows:
#    $PN-$PV-$ARCH-$PR.txz
#        ffp
#        install
#            HOMEPAGE
#            DESCR
#            doinst.sh
###############################################################################
export DIR_ROOT=$(cd $(dirname $0) && pwd);
export DIR_CONFIG=$DIR_ROOT/config
export DIR_DEFINITIONS=$DIR_ROOT/definitions
export DIR_DEST=$DIR_ROOT/destdir
export DIR_LOGS=$DIR_ROOT/logs
export DIR_RELEASE=$DIR_ROOT/release
export DIR_TEMP=$DIR_ROOT/temp
export DIR_WORK=$DIR_ROOT/work
###############################################################################
# This is where ffp resides. should not be changed
export CPREFIX=/ffp

# A few export for various compilations
export MANDIR=/ffp/share/man
export INFODIR=/ffp/share/info
export DOCDIR=/ffp/share/doc

export FFPVERSION=0.7

# Logging
export MAINOUTPUT=$DIR_LOGS/$(date +%y%m%d-%H%M).log
export STATUSLOG=$DIR_LOGS/status.log

# Hold the architecture of ffp
export $(cat /ffp/etc/ffp-version|grep FFP_ARCH)
###############################################################################
BOLDON=`tput smso`
BOLDOFF=`tput rmso`
###############################################################################
# Setup logging
[[ -e $MAINOUTPUT ]] && rm $MAINOUTPUT
exec 3>&1 4>&2
MAINFIFO=/tmp/fifo.$$
[[ -e $MAINFIFO ]] || mkfifo $MAINFIFO
tee $MAINOUTPUT < $MAINFIFO >&3 &
MAINPID=$!
exec > $MAINFIFO 2>&1
###############################################################################
# Wrapper for echo
# If you want to skip the line-carriage, add "\c" to your string
function func_echo {
    DATE=$(date +"%Y%m%d-%H%M%S")
    echo "$DATE - $1";
}

# Wrapper for mkdir
function func_create_path {
    if [[ ! -d $1 ]]; then
        func_echo "Creating Path: $1"
        mkdir -p $1
    fi
    return 0
}
###############################################################################
# Initialize directory structure (should be created partially already, but
# just to make sure)
function func_init_ffpcompiler_dirs {
    func_create_path $DIR_ROOT
    func_create_path $DIR_CONFIG
    func_create_path $DIR_DEFINITIONS
    func_create_path $DIR_DEST
    func_create_path $DIR_LOGS
    func_create_path $DIR_RELEASE
    func_create_path $DIR_TEMP
    func_create_path $DIR_WORK
}
###############################################################################
# Initializes all required directories for a package
function func_init_pkg_work_dir {
    func_init_ffpcompiler_dirs
    # Example: definitions/nano
    export X=$DIR_DEFINITIONS/$PN
    # Example: work/nano/2.2.6/1
    export W=$DIR_WORK/$PN/$PV/$PR
        # Example: work/nano/2.2.6/1/pkg
        export D=$W/pkg
        # Example: work/nano/2.2.6/1/nano-2.2.6
        if [[ ! -f $X/dir_E ]]; then
            export E=$W/$PN-$PV
        else
            . $X/dir_E
        fi
    # Example: destdir/nano
    export F=$DIR_DEST/$PN
    # Now create the paths
    export DIR_DIST=$DIR_WORK/$PN/$PV/distdir
    func_create_path $DIR_DIST
    func_create_path $D
    func_create_path $F
}
###############################################################################
# Copy additional data to 'install' directory
function func_dir_install {
    func_create_path $D/install
    [[ -f $X/DESCR ]] && cp $X/DESCR $D/install
    [[ -f $X/HOMEPAGE ]] && cp $X/HOMEPAGE $D/install
    [[ -f $X/doinst.sh ]] && cp $X/doinst.sh $D/install
    return 0
}

# Copy additional data to 'ffp' directory
function func_dir_ffp {
    if [[ -d $X/ffp ]]; then
        func_create_path $D/ffp
        cp -R $X/ffp/* $D/ffp/
    fi
}
###############################################################################
# Download the package
function func_download_distfile {
	if [[ $(ls -1 $DIR_DIST|wc -l) -eq 0 ]]; then
		cd $DIR_DIST
		wget $SRC_URI
	else
		func_echo "There are files in $DIR_DIST"
		func_echo "therefore no download is started. If you want to redownload,"
		func_echo "please delete all files in this directory"
	fi
}
###############################################################################
# Unpack the package
function func_unpack_distfile {
    cd $W
    for FILENAME in $(ls -1 $DIR_DIST); do
        # Stolen from svn://inreto.de/svn/dns323/funplug/trunk/source/Make.sh
        FILEPATH=$DIR_DIST/$FILENAME
        if [[ -d "$FILEPATH" ]]; then
            echo "Copying directory $(basename $FILEPATH)"
            tar cf - -C $DIR_DIST --exclude=.svn --exclude=.git --exclude=CVS $FILENAME | tar xf -
        elif [ -r "$FILEPATH" ]; then
            echo "Unpacking $(basename $FILEPATH)"
            case "$FILEPATH" in
                *.tar.bz2)
                    echo "This is a .tar.bz2-File - Unpacking"
                    tar xjf $FILEPATH
                    ;;
                *.tar.gz | *.tgz)
                    echo "This is a .tar.gz/.tgz-File - Unpacking"
                    tar xzf $FILEPATH
                    ;;
                *.tar.xz | *.txz)
                    echo "This is a .tar.xz/.txz-File - Unpacking"
                    tar xJf $FILEPATH
                    ;;
                *.tar)
                    echo "This is a .tar.bz2-File - Unpacking"
                    tar xf $FILEPATH
                    ;;
                *.zip)
                    echo "This is a .zip-File - Unpacking"
                    unzip $FILEPATH
                    ;;
                *.1)
                    echo "This file is a double file - Deleting"
                    rm $FILEPATH
                    ;;
                *)
                    die "$(basename $FILEPATH): Don't know how to unpack"
                    ;;
            esac
        else
            die "$FILENAME: No archive found"
        fi
    done
}
###############################################################################
function func_patch {
    if [[ -f $X/command_patch ]]; then
        cd $E
        chmod +x $X/command_patch
        $X/command_patch
    fi
}

function func_determine_arch {
        export $(cat /ffp/etc/ffp-version|grep FFP_ARCH)
        case "$FFP_ARCH" in
            arm)
                export GNU_BUILD=arm-ffp-linux-uclibcgnueabi
                ;;
            oarm)
                export GNU_BUILD=arm-ffp-linux-uclibc
                ;;
            "")
                echo "FFP_ARCH unset"
                return 1
                ;;
            *)
                echo "FFP_ARCH unknown"
                return 1
                ;;
        esac

        export GNU_HOST=$GNU_BUILD
        export GNU_TARGET=$GNU_HOST
}

###############################################################################
# Execute configure
function func_configure {
    cd $E
    func_determine_arch
    if [[ ! -f $X/command_configure ]]; then
        export STOCK_FFP_CFLAGS="-I/ffp/include -O2"
        export STOCK_FFP_LDFLAGS="-L/ffp/lib -Wl,-rpath,/ffp/lib"
        export FFP_LDFLAGS=${FFP_LDFLAGS:=$STOCK_FFP_LDFLAGS}
        export FFP_CFLAGS=${FFP_CFLAGS:=$STOCK_FFP_CFLAGS}
        echo "CFLAGS=$FFP_CFLAGS"
        echo "LDFLAGS=$FFP_LDFLAGS"
        CFLAGS="$FFP_CFLAGS" LDFLAGS="$FFP_LDFLAGS" ./configure $CONFIGURE_ARGS
    else
        chmod +x $X/command_configure
        $X/command_configure
    fi
}

###############################################################################
# Execute make
function func_make {
    cd $E
    func_determine_arch

    # Export the temporary directory
    export TMPDIR=$DIR_TEMP

    if [[ ! -f $X/command_make ]]; then
        STOCK_COMMAND_MAKE="make"
        COMMAND_MAKE=${COMMAND_MAKE:=$STOCK_COMMAND_MAKE}
        eval $COMMAND_MAKE
    else
        chmod +x $X/command_make
        $X/command_make
    fi
}

# Execute make install
function func_make_install {
    cd $E
    if [[ ! -f $X/command_make_install ]]; then
        STOCK_COMMAND_MAKE_INSTALL="make DESTDIR=$D install"
        COMMAND_MAKE_INSTALL=${COMMAND_MAKE_INSTALL:=$STOCK_COMMAND_MAKE_INSTALL}
        eval $COMMAND_MAKE_INSTALL
    else
        chmod +x $X/command_make_install
        $X/command_make_install
    fi
}
###############################################################################
# Wrapper for makepkg
function func_makepkg {
    cd $D
    PKGDIR=$F /ffp/sbin/makepkg $PN $PV $PR
    export PACKAGELOCATION=$(ls -1 $F/$PN-$PV-*-$PR.txz)
}

# Copies the new package to the release-directory
function func_copynewpackage {
    if [[ -f $PACKAGELOCATION ]]; then
        cp $PACKAGELOCATION $DIR_RELEASE/$FFPVERSION/$FFP_ARCH/packages/
    fi
    for PACKAGENAME in $(ls -1 $DIR_RELEASE/$FFPVERSION/$FFP_ARCH/packages/*.txz|sort); do
	echo $PACKAGENAME
    done
}

function func_makerelease {
    mkdir -p $DIR_RELEASE/$FFPVERSION/arm/packages/
    mkdir -p $DIR_RELEASE/$FFPVERSION/oarm/packages/
    for DIRNAME in $(find $DIR_RELEASE -type d -exec echo {} \;); do
        if [[ $(ls -1 $DIRNAME/*.txz 2> /dev/null|wc -l) -gt 0 ]]; then
            cd $DIRNAME
            md5sum *.txz > CHECKSUMS.md5
            SHORTDIRNAME=$(echo $DIRNAME|sed -e "s#$DIR_RELEASE/##g")
            func_echo "Found the following packages in $SHORTDIRNAME:"
            cat CHECKSUMS.md5
        fi
    done
}
###############################################################################
# Publish to remote directory
function func_publishrelease {
    func_makerelease
    cd $DIR_RELEASE
    chmod +x $DIR_CONFIG/rsynctorepository.sh
    $DIR_CONFIG/rsynctorepository.sh
}

###############################################################################

function func_run_command {
    # First argument is thescriptname
    COMPILESCRIPTNAME=$1
    func_echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    func_echo "Executing $COMPILESCRIPTNAME";
    # Reset the variable which is set to 1 as long as the script needs to run and which is set
    # to 0 if the script was run.
    COMPILESCRIPTRUN=1
    # Now run it
    while [[ $COMPILESCRIPTRUN = 1 ]];
    do
        ISAFUNC=$(echo $COMPILESCRIPTNAME|grep "func_"|wc -l);
        if [[ $ISAFUNC -gt 0 ]]; then
            # Is a function
            $COMPILESCRIPTNAME
            # Set the returncode
            COMPLIEPROGRAMRC=$?;
        else
            
            # Is a script
            # Mark the script as executable
            chmod -f +x $X/$PN/$COMPILESCRIPT;
            # Run the script
            $X/$PN/$COMPILESCRIPT;
            COMPLIEPROGRAMRC=$?;
       fi
        # Check the Returncode
        if [ $COMPLIEPROGRAMRC -eq 0 ]; then
            COMPILESCRIPTRUN=0;
        else
            # Run failed
            func_echo "Seems like something happened, Returncode was $COMPLIEPROGRAMRC";
            func_echo "Please check the output carefully!"
            func_echo ""
            func_echo "What do you want to do?"
            PS3='What do you want to do?: '
            select COMPILESCRIPTFAILUREAGAIN in 'Run again' 'Exit' 'Run next'
            do
                if [[ -n $COMPILESCRIPTFAILUREAGAIN ]]; then
                    func_echo "You have chosen: $COMPILESCRIPTFAILUREAGAIN"
                    if [[ $COMPILESCRIPTFAILUREAGAIN = "Run next" ]]; then
                        # Action: Run next
                        COMPILESCRIPTRUN=0;
                    elif [[ $COMPILESCRIPTFAILUREAGAIN = "Exit" ]]; then
                        # Action: Exit
                        echo "$PN;$PV;$PR;1" >> $STATUSLOG
                        exit 1;
                    else
                        # Action: Run again
                        COMPILESCRIPTRUN=1;
                    fi
                    break
                else
                    func_echo "Invalid choice ($COMPILESCRIPTFAILUREAGAIN). Please try again";
                fi
            done
        fi
    done
}

###############################################################################
# Chooser
PS3="Select package to compile: "
select FILE_DEFINITIONS in '--> SKIP THIS' $(ls -1 $DIR_DEFINITIONS)
do
    if [[ -n $FILE_DEFINITIONS ]]; then
        func_echo "You have chosen: $FILE_DEFINITIONS"
        if [[ $FILE_DEFINITIONS = "--> SKIP THIS" ]]; then
            break
        else
            # Import the definition-file
            cd $DIR_DEFINITIONS/$FILE_DEFINITIONS
	    if [[ -f funpkg ]]; then
	        . ./funpkg
            elif [[ -f $FILE_DEFINITIONS.funpkg ]]; then
                . ./$FILE_DEFINITIONS.funpkg
            fi
            # Run through the commands
            for COMPILESCRIPT in $COMMANDS; do
                func_run_command $COMPILESCRIPT
            done
            echo "$PN;$PV;$PR;0" >> $STATUSLOG
            break
        fi
    else
        func_echo "Invalid choice ($FILE_DEFINITIONS). Please try again";
    fi
done

echo ""
echo ""

PS3='Publish packages?: '
select YESNOPUBLISH in 'Yes' 'No'
do
    if [[ -n $YESNOPUBLISH ]]; then
        func_echo "You have chosen: $YESNOPUBLISH"
        if [[ $YESNOPUBLISH = "Yes" ]]; then
            func_echo "Publishing"
            func_publishrelease
            func_echo "Done."
        elif [[ $YESNOPUBLISH = "No" ]]; then
            func_echo "Not publishing."
        fi
        break
    else
        func_echo "Invalid choice ($YESNOPUBLISH). Please try again";
    fi
done

func_echo "Done ffp-compiler.sh"
# EXIT LOGGING AND CLEAN UP
# Set back the redirections of the output
exec 1>&3 2>&4 3>&- 4>&-
# After redirecting the output, tee will exit. Wait for it
wait $MAINPID
# Remove the FIFO-Pipe
rm $MAINFIFO