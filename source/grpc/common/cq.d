module grpc.common.cq;
import grpc.logger;
import interop.headers;
import std.typecons;
import grpc.core.tag;
import grpc.core;
import grpc.core.sync.mutex;
import grpc.core.resource;
import grpc.core.utils;
import core.lifetime;
import std.experimental.allocator : theAllocator, make, dispose;

//queue ok/ok type
alias NextStatus = Tuple!(bool, bool);


// TODO: add mutexes 

import core.thread;
import std.parallelism;

import std.traits;

class CompletionQueue(string T) 
    if(T == "Next") 
{
@safe:
    private { 
        shared(Mutex) mutex;
        SharedResource _cq;
        bool _inShutdownPath;
    }

    bool inShutdownPath() shared {
        return _inShutdownPath;
    }

    bool inShutdownPath(bool val) shared {
        _inShutdownPath = val;
        return val;
    }

    inout(grpc_completion_queue)* handle() inout @trusted nothrow shared {
        return cast(typeof(return)) _cq.handle;
    }

    inout(grpc_completion_queue)* handle() inout @trusted nothrow {
        return cast(typeof(return)) _cq.handle;
    }

    /* Preserved for compatibility */
    auto ptr(string file = __FILE__) @trusted {
        return handle;
    }

    void lock() {
        mutex.lock;
    }

    void lock() shared {
        mutex.lock;
    }

    void unlock() shared {
        mutex.unlock;
    }

    void unlock() {
        mutex.unlock;
    }
    
    static if(T == "Pluck") {
        // TODO: add Pluck/Callback types
    }
    static if(T == "Next") {
        grpc_event next(Duration time) @trusted shared {
            gpr_timespec t = durtotimespec(time);
            grpc_event _evt = grpc_completion_queue_next(handle, t, null);

            return _evt;
        }

        grpc_event next(Duration time) @trusted {
            gpr_timespec t = durtotimespec(time);
            grpc_event _evt = grpc_completion_queue_next(handle, t, null);

            return _evt;
        }
    }

    import grpc.server;

    grpc_call_error requestCall(void* method, Tag* tag, shared(Server) _server, shared(CompletionQueue!"Next") boundToCall) @trusted {
        assert(tag != null, "tag null");
        DEBUG!"hmm"();

        DEBUG!"locking context mutex";
        
        _server.lock;
        tag.ctx.mutex.lock;
        mutex.lock;

        scope(exit) {
            _server.unlock;
            tag.ctx.mutex.unlock;
            mutex.unlock;
        }

        DEBUG!"1";
        auto server_ptr = _server.handle();
        DEBUG!"2";
        auto method_cq = handle();

        DEBUG!"3";
        auto server_cq = boundToCall.handle();
        
        auto ctx = &tag.ctx;
        assert(ctx != null, "context null");
        DEBUG!"4";
        auto details = ctx.details.handle();
        
        DEBUG!"5";
        auto metadata = ctx.metadata.handle();
        DEBUG!"6";
        auto data = ctx.data.safeHandle();

        DEBUG!"call: %x"(ctx.call);

        grpc_call_error error = grpc_server_request_registered_call(server_ptr,
                method, ctx.call, &details.deadline, metadata,
                data, method_cq, server_cq, tag);

        DEBUG!"successfully reregistered"();

        return error;

    }


    this() @trusted {
        grpc_completion_queue* cq = null;

        static if (T == "Next") {
            cq = grpc_completion_queue_create_for_next(null);
        } else {
        }

        assert(cq != null, "CQ creation error");

        static bool release(shared(void)* ptr) @trusted nothrow {
            grpc_completion_queue_shutdown(cast(grpc_completion_queue*)ptr);
            grpc_completion_queue_destroy(cast(grpc_completion_queue*)ptr);

            return true;
        }

        _cq = SharedResource(cast(shared)cq, &release);
        mutex = cast(shared)Mutex.create();
    }


    static CompletionQueue!T opCall() @trusted {
        CompletionQueue!T obj = theAllocator.make!(CompletionQueue!T)();
        return obj;
    }

    void shutdown() @trusted {
        grpc_completion_queue_shutdown(handle);
        INFO!"shutting down CQ";
    }

}

