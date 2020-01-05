#!/opt/ruby_2.2.3/bin/ruby -w
# coding: utf-8
#
def 线程发送hello(*参数)
	require 'socket'
	if ARGV[1] == nil;本地IP  =参数[0];else 本地IP  =ARGV[1];end;
	if ARGV[2] == nil;远端IP  =参数[1];else 远端IP  =ARGV[2];end;
	if ARGV[3] == nil;远端端口=参数[2];else 远端端口=ARGV[3].to_i;end;
	if ARGV[4] == nil;线程join=参数[3];else 线程join=ARGV[4];end;

	线程数组=[]

	线程数组 << Thread.new {
		loop {
			begin
				p 远端IP
				p 远端端口
				UDPSocket.new.send("#{本地IP}-----#{$PROGRAM_NAME}-----#{Process.pid}",0,远端IP,远端端口);
				sleep 5
			rescue
				puts "重连并发送..."
				sleep 5
			end	
		}
	}
	线程数组.each {|x| x.join } if 线程join =='join' #显式join
end
#线程发送hello("192.168.137.37","192.168.137.38",18002)
