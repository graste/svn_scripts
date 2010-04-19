#!/bin/bash
# Pinning externals of an subversion working copy
# supporting svn 1.5 externals ONLY
#
# Usage:
#    0. $ cd into_the_working_copy_dir_having_externals
#    1. Run this script
#    2. Check the svn:externals properties.
#    3. If you have more dirs using externals start at step 0
#
# Copyright 2009 Robert Schulze <robert@dotless.de>. All rights reserved.
# Copyright 2010 Steffen Gransow <steffen.gransow@mivesto.de>. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY Robert Schulze ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Robert Schulze OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied, of Robert Schulze or Steffen Gransow.
#  
#
# Further improvements (2010-04-14, Steffen Gransow):
# - add SVN credentials as command line arguments and use them
# - use another path instead of current directory if necessary
# - multiple or missing trailing slashes will be merged to one for relative externals
# - add usage info etc.
#

function usage()
{
    cat <<EOF

usage: $0 --username <SVN username> --password <SVN password> [PATH]

This script pins the SVN externals of the current directory to their
most current revisions. Works for relative and absolute externals.
This script doesn't touch already pinned externals.

OPTIONS:

    --username <user>       SVN username to use for svn info
    --password <pass>       SVN password for the given user
    [PATH]                  optional directory to pin externals for (instead of current directory)

EXAMPLES:

    chuck@develop:~/projects/ironfist/trunk> $0 --username chuck.norris --password r0undhousek1ck
    chuck@develop:~/projects/ironfist/trunk> $0 --username chuck.norris --password r0undhousek1ck .
    chuck@develop:~/projects/ironfist/trunk> ../../.$0 --username chuck.norris --password r0undhousek1ck vendor/branches
    chuck@develop:~> $0 --username chuck.norris --password r0undhousek1ck /mount/projects/ironfist/trunk/vendor/branches

EOF
}

# number of command line arguments
NUMBER_OF_ARGS=$#

# command line arguments used for SVN
ARG1=$1
SVN_USERNAME=$2
ARG2=$3
SVN_PASSWORD=$4
DIRECTORY_TO_CHECK=$5

if [ -z "$DIRECTORY_TO_CHECK" ] ; then
    DIRECTORY_TO_CHECK="."
fi

if [ "$NUMBER_OF_ARGS" -lt 4 ] || [ "$ARG1" != "--username" ] || [ "$ARG2" != "--password" ]; then
    usage
    exit 1
fi

tempfile=`mktemp /tmp/svnpinXXXXXXXX`
svn propget svn:externals $DIRECTORY_TO_CHECK | \
gawk -v svnuser=$SVN_USERNAME -v svnpwd=$SVN_PASSWORD -v svnpath="$DIRECTORY_TO_CHECK/" '
{ 
    if (NF == 2)
    {
        sub(/\/+$/, "/", svnpath);
        command="svn info --username " svnuser " --password " svnpwd " " $1;
        if (!match($1, /^http/))
        {
            command="svn info --username " svnuser " --password " svnpwd " " svnpath $1;
        }

        i=0;
        revnum="";
        while ((command |& getline result) > 0)
        {
            if (4 == i++)
            {
                match(result, /([0-9]+)/, rev);
                revnum = rev[1];
            }
        }
        close(command);
        
        if (match($2, /:\/\//))
        {
            print $1, " -r" revnum, $2;
        }
        else
        {
            print "-r"revnum, $1, $2
        }
    }
    else
    {
        print $0;
    }
}' > $tempfile

svn propset svn:externals -F $tempfile $DIRECTORY_TO_CHECK
#cat $tempfile

rm $tempfile

