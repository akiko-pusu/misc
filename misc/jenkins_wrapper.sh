#!/bin/sh
#
#-----------------------------------------------------------------------------
# Jenkinsサーバへローカルホスト内のジョブやスクリプトの実行結果を通知するための
# ラッパースクリプトです。
#
# 必要なツール: curl (wgetのようなコマンドラインインタフェース)
# 事前Jenkinsにのサーバに、通知専用のプロジェクトを作る必要があります。
# また、プロジェクトは匿名アクセス可能にしないといけません。非公開の場合は、
# curlのオプションで、-u userid:password を渡すように修正してください。
#
# Jenkinsへの外部ジョブ登録用フォーマットは、XML形式です。
# Ref. http://wiki.jenkins-ci.org/display/JA/Monitoring+external+jobs
# 
#-----------------------------------------------------------------------------
#
#
# Wrapper for sending the results of an arbitrary script to Jenkins for
# monitoring. 
#
# Usage: 
#   jenkins_wrapper <jenkins_url> <job> <script>
#
#   e.g. jenkins_wrapper http://jenkins.myco.com:8080 testjob /path/to/script.sh
#        jenkins_wrapper http://jenkins.myco.com:8080 testjob 'sleep 2 && ls -la'
#
# Requires:
#   - curl
#   - bc
#
# Runs <script>, capturing its stdout, stderr, and return code, then sends all
# that info to Jenkins under a Jenkins job named <job>.
if [ $# -lt 3 ]; then
    echo "Not enough args!"
    echo "Usage: $0 JENKINS_URL JENKINS_JOB_NAME SCRIPT"
    exit 1
fi

JENKINS_URL=$1; shift
JOB_NAME=$1; shift
SCRIPT="$@"

OUTFILE=$(mktemp -t jenkins_wrapper.XXXXXXXX)
echo "Temp file is:     $OUTFILE" >> $OUTFILE
echo "Jenkins job name:  $JOB_NAME" >> $OUTFILE
echo "Script being run: $SCRIPT" >> $OUTFILE
echo "" >> $OUTFILE

### Execute the given script, capturing the result and how long it takes.

START_TIME=$(date +%s.%N)
eval $SCRIPT >> $OUTFILE 2>&1
RESULT=$?
END_TIME=$(date +%s.%N)
ELAPSED_MS=$(echo "($END_TIME - $START_TIME) * 1000 / 1" | bc)
echo "Start time: $START_TIME" >> $OUTFILE
echo "End time:   $END_TIME" >> $OUTFILE
echo "Elapsed ms: $ELAPSED_MS" >> $OUTFILE

### Post the results of the command to Jenkins.

# We build up our XML payload in a temp file -- this helps avoid 'argument list
# too long' issues.
CURLTEMP=$(mktemp -t jenkins_wrapper_curl.XXXXXXXX)
echo "<run><log encoding=\"hexBinary\">$(hexdump -v -e '1/1 "%02x"' $OUTFILE)</log><result>${RESULT}</result><duration>${ELAPSED_MS}</duration></run>" > $CURLTEMP
curl -X POST -d @${CURLTEMP} ${JENKINS_URL}/job/${JOB_NAME}/postBuildResult

### Clean up our temp files and we're done.

rm $CURLTEMP
rm $OUTFILE

