//generates grpc files despite this warning: "protos: warning: directory does not exist."
protoc --dart_out=grpc:lib/grpc --proto_path=resources -Iprotos Notes.proto

flutter build apk --no-shrink (to release)
