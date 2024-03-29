module grpc.logger;
import interop.headers;
import grpc.service.queue;
import std.datetime; 
import core.thread;

enum Verbosity {
    Debug = 0,
    Info = 1,
    Error = 2
};

import std.array, std.format;
static shared Logger gLogger;

void INFO(string format, string file = __MODULE__, int line = __LINE__, A...)(lazy A args) @trusted {
    if (gLogger.__minVerbosity <= Verbosity.Info) {
        auto msg = appender!string;
        formattedWrite(msg, format, args);
        gLogger.log(Verbosity.Info, msg.data, file, line);
    }
}

void DEBUG(string format, string file = __MODULE__, int line = __LINE__, A...)(lazy A args) @trusted {
    debug {
        if (gLogger.__minVerbosity <= Verbosity.Debug) {
            auto msg = appender!string;
            formattedWrite(msg, format, args);
            gLogger.log(Verbosity.Debug, msg.data, file, line);
        }
    }
}

void ERROR(string format, string file = __MODULE__, int line = __LINE__, A...)(lazy A args) @trusted {
    if (gLogger.__minVerbosity <= Verbosity.Error) {
        auto msg = appender!string;
        formattedWrite(msg, format, args);
        gLogger.log(Verbosity.Error, msg.data, file, line);
    }
}

class Logger {
    private {
        struct LogEvent {
            SysTime time;
            Verbosity v;
            string message;
            string source;
        }

        string _infoPath;
        string _warningPath;
        string _errorPath;
        string _debugPath;

        Verbosity __minVerbosity;

    }

    @property Verbosity minVerbosity() shared {
        return __minVerbosity;
    }

    @property Verbosity minVerbosity(Verbosity _min) shared {
        gpr_log_verbosity_init();
        gpr_set_log_verbosity(cast(gpr_log_severity)_min);
        __minVerbosity = _min;

        return _min;
    }


    
    void info(string message, string file = __MODULE__, int line = __LINE__) shared {
        log(Verbosity.Info, message, file, line);
    }

    void debug_(string message, string file = __MODULE__, int line = __LINE__)  shared{
        log(Verbosity.Debug, message, file, line);
    }

    void error(string message, string file = __MODULE__, int line = __LINE__) shared {
        log(Verbosity.Error, message, file, line);
    }

    void log(Verbosity v, string message, string file = __MODULE__, int line = __LINE__) shared {
        import std.string : toStringz;
        const(char)* msg = message.toStringz;
        const(char)* f = file.toStringz;
        gpr_log_message(f, line, cast(gpr_log_severity)v, msg); 
    }

    this(Verbosity _minVerbosity = Verbosity.Info, string info = "", string warning = "", string error = "", string debug_ = "") shared {
        minVerbosity = _minVerbosity;
        _infoPath = info;
        _warningPath = warning;
        _errorPath = error;
        _debugPath = debug_;
    }

    shared static this() {
        gLogger = new shared(Logger)();
        import core.exception;
        core.exception.assertHandler = &assertHandler;
    }
    
    shared static ~this() {
        destroy(gLogger);
    }
}

import core.stdc.stdlib : abort;
import core.thread;
import core.time;

void assertHandler(string file, ulong line, string message) nothrow {
    try { 
        ERROR!"ASSERT: %s at %s:%d"(message, file, line);
        abort();
    } catch(Exception e) {

    }
}

