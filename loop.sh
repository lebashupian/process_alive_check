#!/bin/bash
source /etc/profile
source ~/.bash_profile
function exit_msg() {
	echo $1
	exit 1
}
[[ $1 == '' ]] && exit_msg "请指定模拟启动进程的个数" 
i=0
while [[ $i -lt $1 ]];
do
./cmd.rb > /dev/null &
i=$(($i+1))
done
