// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: src/proto/grpc/status/status.proto

module google.rpc.status;

import google.protobuf;
import google.protobuf.any;

enum protocVersion = 3007000;

struct RPC {
    string methodName;
}

enum ServerStreaming;
enum ClientStreaming;

struct Status
{
    @Proto(1) int code = protoDefaultValue!int;
    @Proto(2) string message = protoDefaultValue!string;
    @Proto(3) Any[] details = protoDefaultValue!(Any[]);
}
