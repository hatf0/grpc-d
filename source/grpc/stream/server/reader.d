module grpc.stream.server.reader;
import grpc.logger;
import grpc.core.tag;
import interop.headers;
import grpc.common.cq; 
import grpc.common.call;
import grpc.core.utils;
import grpc.common.batchcall;

class ServerReader(T) {
    private {
        CompletionQueue!"Next"* _cq;
        Tag* _tag;
    }
    import grpc.common.byte_buffer;
    import google.protobuf;


    auto readOne(Duration d = 10.seconds) {

        assert(_tag != null, "tag shouldn't be null");

        T protobuf = T.init;
        assert(_tag.ctx.data.valid, "byte buffer should always be valid");
        ulong len = _tag.ctx.data.length;
        DEBUG!"bf.length: %d"(len);
        if(len != 0) {
            ubyte[] data = _tag.ctx.data.readAll();
            protobuf = data.fromProtobuf!T();
        }
        return protobuf;
    }




    auto read(int count = 0)(Duration d = 10.seconds) {
        import std.concurrency;
        import std.stdio;

        auto r = new Generator!T({
            auto ctx = &_tag.ctx;
            ByteBuffer* bf = &ctx.data;
            static if(count == 1) {
                DEBUG!"unary call, so read off of the context bytebuffer (ptr: %x)"(bf);
                T protobuf;
                
                DEBUG!"checking if bf is valid";
                
                assert(bf.valid, "byte buffer should always be valid");
                
                DEBUG!"bf.length: %d"(bf.length);
                if(bf.length != 0) {
                    ubyte[] data = bf.readAll();
                    protobuf = data.fromProtobuf!T();
                }

                yield(protobuf);
                DEBUG!"we're done here";
            }
            else {
                BatchCall batch = new BatchCall();
                ubyte[] data;

                while(bf.length != 0) {
                    data = bf.readAll();
                    T protobuf;

                    if(data.length == 0) {
                        return;
                    }

                    try { 
                        protobuf = data.fromProtobuf!T();
                    } catch(Exception e) {
                        ERROR!"Deserialization fault: %s"(e.msg);
                        ERROR!"%s"(data);
                        ERROR!"Byte buffer length: %d"(bf.length);

                        return;
                    }

                    yield(protobuf);

                    batch.addOp(new RecvMessageOp(bf));
                    auto stat = batch.run(_cq, _tag, d);
                    if(stat != GRPC_CALL_OK) {
                        ERROR!"READ ERROR: %s"(stat);
                        return;
                    }

                }
                
            }
        });

        return r;
    }

    void finish() {
        int cancelled = 0;
        auto ctx = &_tag.ctx;
        BatchCall batch = new BatchCall();
        batch.addOp(new RecvCloseOnServerOp(&cancelled));
        DEBUG!"running!"();
        auto stat = batch.run(_cq, _tag);
    }



    this(CompletionQueue!"Next"* cq, Tag* tag) {
        import std.stdio;
        _cq = cq;
        _tag = tag;
    }

    ~this() {


    }
}
