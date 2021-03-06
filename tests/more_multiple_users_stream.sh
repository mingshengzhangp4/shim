#!/bin/bash
host=localhost
port=8088
td=$(mktemp -d)

mkdir -p $td/wwwroot
./shim -p $port -r $td/wwwroot  -f &
disown
sleep 1


# Test multiple users streaming their results

# SET THIS TO BE THE NUMBER OF CONCURRENT REQUESTS TO ISSUE AND NUMBER
# OF TIMES TO REPEAT
N=50
REP=10000

dosomething(){
  s=`curl -s -k http://${host}:${port}/new_session | tr -d '[\r\n]'`
  echo "session: $s"
  if test "${s}" != ""; then
    # The ugly url-encoded query string below is:
    # build(<x:double>[i=1:${1},10000,0],i)
    curl -s -k "http://${host}:${port}/execute_query?id=${s}&query=build(%3Cx%3Adouble%3E%5Bi%3D1%3A${1}%2C10000%2C0%5D%2Ci)&save=dcsv"
    curl -s -k "http://${host}:${port}/read_lines?id=${s}&n=0" | wc -l
    curl -s -k "http://${host}:${port}/release_session?id=${s}"
    echo "Done with session: ${s}"
  else
    echo "Resource not available"
  fi
}

l=0
while test $l -lt $REP; do
  date | tee -a /tmp/log
  pid=$(ps -A | grep shim | sed -e "s/^ *//;s/ .*//") && cat /proc/${pid}/status | grep RSS | tee -a /tmp/log
  j=0
  while test $j -lt $N;do
    dosomething 10 &
    j=$(($j + 1))
  done

  wait
  l=$(($l + 1))
done


sleep 1
rm -rf $td
killall -9 shim
