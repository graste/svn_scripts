#!/bin/bash
#
# Creates new release and pins externals of given path to their latest revisions.
# Supports only SVN v1.5 externals.
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
# THIS SOFTWARE IS PROVIDED BY Robert Schulze AND STEFFEN GRANSOW``AS IS'' AND ANY EXPRESS OR IMPLIED
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


function usage()
{
    cat <<EOF

usage: $0 --username <SVN_USERNAME> --password <SVN_PASSWORD> <SVN_SOURCE_URL> <SVN_TARGET_URL> <SVN_EXTERNALS_PATH> <COMMIT_MESSAGE>

This script basically does a SVN COPY and pins the externals of the
given relative repository path to their most current revisions. This
is only done for absolute externals as relative externals should just
work anyways (tm). The script does not touch already pinned externals
and can't update those as well.

DOES ONLY SUPPORT RELATIVE EXTERNALS WITH "../" (NOT "^/" ETC. WHAT'S VALID WITH SVN 1.5+ AS WELL)

OPTIONS:

    --username <USER>       SVN username to use for svn info
    --password <PASS>       SVN password for the given user
    <SVN_SOURCE_URL>        SVN URL to use as source for svn copy command
    <SVN_TARGET_URL>        SVN URL to use as target for svn copy command
    <SVN_EXTERNALS_PATH>    path to append to target URL to get directory with externals to pin
    <COMMIT_MESSAGE>        SVN commit message to use for svn copy command

EXAMPLES:

    $0 --username chuck.norris --password r0undhousek1ck https://svn.example.com/ironfist/trunk https://svn.example.com/ironfist/releases/live20100415 /site 'create new release from trunk and pin absolute externals of /site folder'

EOF
}

# number of command line arguments
NUMBER_OF_ARGS=$#

# command line arguments used for SVN operations
ARG1=$1
SVN_USERNAME=$2
ARG2=$3
SVN_PASSWORD=$4
SVN_SOURCE_URL=$5
SVN_TARGET_URL=$6
SVN_EXTERNALS_PATH=$7
SVN_COMMIT_MESSAGE=$8

# el-cheapo check for existing command line arguments
if [ "$NUMBER_OF_ARGS" -lt 7 ] || [ "$ARG1" != "--username" ] || [ "$ARG2" != "--password" ] [ -z "$SVN_SOURCE_URL" ] || [ -z "$SVN_TARGET_URL" ] || [ -z "$SVN_TARGET_URL" ] || [ -z "$SVN_COMMIT_MESSAGE" ] ; then
    usage
    exit 1
fi

# canonicalize given target URL with appended path to externals
EXTERNALS_URL=$(echo $SVN_TARGET_URL$SVN_EXTERNALS_PATH | sed ':1;s,/[^/.][^/]*/\.\./,/,;t 1')

echo ""
echo "Settings used to create new copy:"
echo ""
echo "SVN SOURCE URL: $SVN_SOURCE_URL"
echo "SVN TARGET URL: $SVN_TARGET_URL"
echo "SVN EXTERNALS PATH: $SVN_EXTERNALS_PATH"
echo "SVN EXTERNALS URL: $EXTERNALS_URL"
echo ""
echo "Running SVN COPY from $SVN_SOURCE_URL to $SVN_TARGET_URL..."

# SVN COPY to create new repository path
TEMPCOMMITMSG=$(mktemp /tmp/svncommitmsgXXXXXXXX)
echo "${SVN_COMMIT_MESSAGE}" > $TEMPCOMMITMSG
svn copy --username $SVN_USERNAME --password $SVN_PASSWORD -F $TEMPCOMMITMSG $SVN_SOURCE_URL $SVN_TARGET_URL

echo ""
echo "Retrieving svn:externals from $EXTERNALS_URL and pinning them to their revisions if necessary..."

# retrieve externals of given externals URL, pin them to their revisions and store result in temporary file
TEMPFILE=$(mktemp /tmp/svnpinXXXXXXXX)
svn propget svn:externals --username $SVN_USERNAME --password $SVN_PASSWORD $EXTERNALS_URL | \
gawk -v svnuser=$SVN_USERNAME -v svnpwd=$SVN_PASSWORD -v svnpath="$EXTERNALS_URL/" '
{ 
    if (NF == 2)
    {
        sub(/\/+$/, "/", svnpath);
        svn_repos_url=(svnpath $1);

        command="svn info --username " svnuser " --password " svnpwd " " $1;
        if (!match($1, /^http/))
        {
            if (!match($2, /^http/))
            {
                cmd="echo " svn_repos_url " | sed \47:1;s,/[^/.][^/]*/../,/,;t 1\47";
                while ((cmd |& getline result) > 0)
                {
                    svn_repos_url=result;
                }
                command="svn info --username " svnuser " --password " svnpwd " " svn_repos_url;
            }
            else
            {
                command="svn info --username " svnuser " --password " svnpwd " " $2;
            }
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
        
        if (!match($1, /^http/) && !match($2, /^http/))
        {
            print $1, $2
        }
        else if (match($2, /:\/\//))
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
}' > $TEMPFILE

# checkout externals URL to temporary directory, modify svn:externals with temp file content and commit changes to repository
TEMPDIR=$(mktemp -d /tmp/svnpincodirXXXXXXXX)
echo "About to commit changes to svn:externals to $EXTERNALS_URL..."
svn checkout -N --username $SVN_USERNAME --password $SVN_PASSWORD $EXTERNALS_URL $TEMPDIR
svn propset svn:externals -F $TEMPFILE $TEMPDIR
svn ci -N --username $SVN_USERNAME --password $SVN_PASSWORD -m'pinning externals of new tag with their current revisions' $TEMPDIR

# remove all temporary files and directories used in above operations
echo ""
echo -n "Cleaning up..."
rm $TEMPCOMMITMSG
rm $TEMPFILE
rm -rf $TEMPDIR
echo "done."
echo ""
echo "Your new copy may be found under: $SVN_TARGET_URL"
echo "The svn:externals are changed on: $EXTERNALS_URL"
echo "Use 'svn pg svn:externals $EXTERNALS_URL' to check if changes are correct."
echo ""

