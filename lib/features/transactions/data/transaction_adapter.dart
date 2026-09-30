import 'package:hive/hive.dart';
import 'transaction_model.dart';

class TransactionAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 1;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return TransactionModel(
      id: fields[0] as String,
      type: TransactionTypeExtension.fromKey(fields[1] as String),
      amountMinor: fields[2] as int,
      categoryId: fields[3] as String,
      accountId: fields[4] as String,
      allocations: (fields[10] as List?)?.map((e) => PaymentAllocation.fromMap(e as Map)).toList() ?? const [],
      note: fields[5] as String?,
      proofPath: fields[9] as String?,
      dateTime: fields[6] as DateTime,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.key)
      ..writeByte(2)
      ..write(obj.amountMinor)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.dateTime)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.proofPath)
      ..writeByte(10)
      ..write(obj.allocations.map((a) => a.toMap()).toList());
  }
}
