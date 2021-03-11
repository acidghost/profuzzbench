#!/usr/bin/env bash

posnum() { [[ ( "$1" =~ [0-9]+ ) && ( "$1" -gt 0 ) ]]; }

fuzz=$1
[ -n "$fuzz" ] || fuzz=aflnet
time="$2"
posnum "$time" || time=$((60 * 60))  # 1H
runs=$3
posnum "$runs" || runs=10
res=$4
[ -d "$res" ] || res="\$HOME/aflnet/results"
scripts=$5
[ -d "$scripts" ] || scripts="\$HOME/aflnet/profuzzbench/scripts"

declare -A prot
prot['forked-daapd']='daap'
prot['dcmtk']='dicom'
prot['dnsmasq']='dns'
prot['tinydtls']='dtls'
prot['bftpd']='ftp'
prot['lightftp']='ftp'
prot['proftpd']='ftp'
prot['pure-ftpd']='ftp'
prot['live555']='rtsp'
prot['kamailio']='sip'
prot['exim']='smtp'
prot['openssh']='ssh'
prot['openssl']='tls'

actual_fuzz=$fuzz

declare -A args
if [ "$fuzz" = aflnet ]; then
    args['forked-daapd']="-P HTTP -D 2000000 -m 1000 -t 50000+ -q 3 -s 3 -E -K"
    args['dcmtk']="-P DICOM -D 10000 -E -K"
    args['dnsmasq']="-P DNS -D 10000 -K"
    args['tinydtls']="-P DTLS12 -D 10000 -q 3 -s 3 -E -K -W 30"
    args['bftpd']="-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -c clean"
    args['lightftp']="-P FTP -D 10000 -q 3 -s 3 -E -K -c ./ftpclean.sh"
    args['proftpd']="-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -c clean"
    args['pure-ftpd']="-t 1000+ -m none -P FTP -D 10000 -q 3 -s 3 -E -K -c clean"
    args['live555']="-P RTSP -D 10000 -q 3 -s 3 -E -K -R"
    args['kamailio']="-m 200 -t 3000+ -P SIP -l 5061 -D 50000 -q 3 -s 3 -E -K -c run_pjsip"
    args['exim']="-P SMTP -D 10000 -q 3 -s 3 -E -K -W 100"
    args['openssh']="-P SSH -D 10000 -q 3 -s 3 -E -K -W 10"
    args['openssl']="-P TLS -D 10000 -q 3 -s 3 -E -K -R -W 100"
elif [ "$fuzz" = "aflnet-no-state" ]; then
    actual_fuzz=aflnet
    args['forked-daapd']="-P HTTP -D 2000000 -m 1000 -t 50000+ -K"
    args['dcmtk']="-P DICOM -D 10000 -K"
    args['dnsmasq']="-P DNS -D 10000 -K"
    args['tinydtls']="-P DTLS12 -D 10000 -K -W 30"
    args['bftpd']="-t 1000+ -m none -P FTP -D 10000 -K -c clean"
    args['lightftp']="-P FTP -D 10000 -K -c ./ftpclean.sh"
    args['proftpd']="-t 1000+ -m none -P FTP -D 10000 -K -c clean"
    args['pure-ftpd']="-t 1000+ -m none -P FTP -D 10000 -K -c clean"
    args['live555']="-P RTSP -D 10000 -K -R"
    args['kamailio']="-m 200 -t 3000+ -P SIP -l 5061 -D 50000 -K -c run_pjsip"
    args['exim']="-P SMTP -D 10000 -K -W 100"
    args['openssh']="-P SSH -D 10000 -K -W 10"
    args['openssl']="-P TLS -D 10000 -K -R -W 100"
elif [ "$fuzz" = aflnwe ]; then
    args['forked-daapd']="-D 2000000 -m 1000 -t 50000+ -K"
    args['dcmtk']="-D 10000 -K"
    args['dnsmasq']="-D 10000 -K"
    args['tinydtls']="-D 10000 -K -W 30"
    args['bftpd']="-t 1000+ -m none -D 10000 -K -c clean"
    args['lightftp']="-D 10000 -K -c ./ftpclean.sh"
    args['proftpd']="-t 1000+ -m none -D 10000 -K -c clean"
    args['pure-ftpd']="-t 1000+ -m none -D 10000 -K -c clean"
    args['live555']="-D 10000 -K"
    args['kamailio']="-m 200 -t 3000+ -D 50000 -K -c run_pjsip"
    args['exim']="-D 10000 -K -W 100"
    args['openssh']="-D 10000 -K -W 10"
    args['openssl']="-D 10000 -K -W 100"
fi

s="$scripts/execution/profuzzbench_exec_common.sh"
targets=('forked-daapd' 'dcmtk' 'dnsmasq' 'tinydtls'
    'bftpd' 'lightftp' 'proftpd' 'pure-ftpd' 'live555'
    'kamailio' 'exim' 'openssh' 'openssl')

for t in "${targets[@]}"; do
    if [ -z "${prot[$t]}" ]; then
        >&2 echo "No protocol for $t"
        exit 1
    elif [ -z "${args[$t]}" ]; then
        >&2 echo "No args for $t"
        exit 1
    fi
    im="profuzzbench-${prot[$t]}-$t"
    o="out-$t-$fuzz"
    echo $s "$im" $runs $res/"$t" $actual_fuzz "$o" "\"${args[$t]}\"" $time 5
done
