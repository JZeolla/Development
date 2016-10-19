##! Load this script to enable IPv4 Internet-only
##! output to kafka for Conn, HTTP, and DNS logs

module Kafka;

event bro_init() &priority=-5
{
        Log::add_filter(Conn::LOG, [$name = "kafka-conn",
                $pred(rec: Conn::Info) = {
                        return ! (( |rec$id$orig_h| == 128 || |rec$id$resp_h| == 128 ) || ((Site::is_local_addr(rec$id$orig_h) || Site::is_private_addr(rec$id$orig_h)) && (Site::is_local_addr(rec$id$resp_h) || Site::is_private_addr(rec$id$resp_h))));
                },
                $writer = Log::WRITER_KAFKAWRITER,
                $config = table(["Conn::LOG"] = fmt("%s", Conn::LOG))
        ]);

        Log::add_filter(HTTP::LOG, [$name = "kafka-http",
                $pred(rec: HTTP::Info) = {
                        return ! (( |rec$id$orig_h| == 128 || |rec$id$resp_h| == 128 ) || ((Site::is_local_addr(rec$id$orig_h) || Site::is_private_addr(rec$id$orig_h)) && (Site::is_local_addr(rec$id$resp_h) || Site::is_private_addr(rec$id$resp_h))));
                },
                $writer = Log::WRITER_KAFKAWRITER,
                $config = table(["HTTP::LOG"] = fmt("%s", HTTP::LOG))
        ]);

        Log::add_filter(DNS::LOG, [$name = "kafka-dns",
                $pred(rec: DNS::Info) = {
                        return ! (( |rec$id$orig_h| == 128 || |rec$id$resp_h| == 128 ) || ((Site::is_local_addr(rec$id$orig_h) || Site::is_private_addr(rec$id$orig_h)) && (Site::is_local_addr(rec$id$resp_h) || Site::is_private_addr(rec$id$resp_h))));
                },
                $writer = Log::WRITER_KAFKAWRITER,
                $config = table(["DNS::LOG"] = fmt("%s", DNS::LOG))
        ]);
}
