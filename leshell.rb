#!/opt/ruby_2.2.3/bin/ruby -w
# coding: utf-8
#如果报readline找不到，需要
#1，yum -y install readline readline-devel
#2，重新编译ruby 加上--with-ext  ./configure --prefix=/opt/ruby_2.2.3/ --with-ext

########################################################
#   加载库
########################################################
begin
	require "readline"
	require "gdbm"  #支持中文
	require 'socket'
rescue Exception => e
	p e.message
end

#######################################################
#   命令记录库
#######################################################
#交互变量 = GDBM.new("readline.db")

puts "#########################################################"
puts "############### 应用交互式 shell #########################"
puts "#########################################################"

################################################
#  初始化变量
################################################
命令段落=""


##############################################
# 建立socke连接
##############################################
begin
   连接控制台=UDPSocket.new
   连接控制台.connect('127.0.0.1',4913);
rescue Exception => e
   puts "UNIXSocket无法连接"
   exit
end


###############################################
# 读取命令行并执行
###############################################
while 读取行 = Readline.readline('###>', true)
	#退出	
	exit if 读取行=='exit' || 读取行=='quit' ;

	#帮助
	(sh输出=`cat help.txt`;puts sh输出) if 读取行=='help';
    
    #处理命令行段落
	if ! 读取行.include? ";"
		命令段落 << 读取行 + ';'
	elsif 读取行.end_with?(";")
		命令段落 << 读取行
		puts "#{命令段落}" if ARGV[0] == 'debug'
		p 命令段落         if ARGV[0] == 'debug'
		begin			
			连接控制台.send 命令段落,0
		rescue Exception => e
			puts "UDPSocket发送有错误，重试"
			sleep 0.5
			retry
		end
		命令段落="";
	else
		puts "输入命令有误，请检查，并以分号;结尾"
		命令段落=""
	end
end


=begin
while 读取行 = Readline.readline(">", true)
	
	(sh输出=`cat help.txt`;puts sh输出) if 读取行=='help';
	交互变量['client_1'] = 读取行;
	p 交互变量['client_1'].force_encoding("UTF-8");
	eval 读取行
end;
=end