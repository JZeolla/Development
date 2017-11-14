from ctypes import *
minver = 0x904ff
dll = cdll.LoadLibrary(\"/usr/local/lib/librdkafka.so\")
version = dll.rd_kafka_version()
exit(0) if minver >= version else exit(1)
