#!/opt/ruby_2.2.3/bin/ruby -w
# coding: utf-8
require_relative "sayhello"
require_relative "color"

####################################
# 程序运行在这个线程中
####################################
Thread.new {
	loop {
		puts "#{多色显示("a","黄色","蓝色","")}";
		sleep 1;
	}
}


####################################
# hello线程
####################################
线程发送hello("192.168.137.37","127.0.0.1",18002,'join')