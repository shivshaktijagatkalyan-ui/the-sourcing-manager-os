import 'training_storage_stub.dart'
    if (dart.library.html) 'training_storage_web.dart' as impl;

String? readTrainingStorage(String key) => impl.readTrainingStorage(key);

void writeTrainingStorage(String key, String value) => impl.writeTrainingStorage(key, value);

