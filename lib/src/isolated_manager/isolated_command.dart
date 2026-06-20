import 'dart:isolate';

class IsolateCommand {
  const IsolateCommand(this.input, this.replyPort);
  final dynamic input;
  final SendPort replyPort;
}

class IsolateError implements Exception {
  const IsolateError(this.error, this.stackTrace);
  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() => 'IsolateError: $error';
}
