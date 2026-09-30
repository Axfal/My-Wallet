import 'package:hive/hive.dart';
import 'account_model.dart';

class AccountAdapter extends TypeAdapter<AccountModel> {
  @override
  final int typeId = 0;

  @override
  AccountModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return AccountModel(
      id: fields[0] as String,
      name: fields[1] as String,
      providerName: fields[2] as String,
      type: AccountTypeExtension.fromKey(fields[3] as String),
      balanceMinor: fields[4] as int,
      openingBalanceMinor: fields[5] as int,
      accountNumber: fields[6] as String?,
      iconCodePoint: fields[7] as int,
      colorValue: fields[8] as int,
      note: fields[9] as String?,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AccountModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.providerName)
      ..writeByte(3)
      ..write(obj.type.key)
      ..writeByte(4)
      ..write(obj.balanceMinor)
      ..writeByte(5)
      ..write(obj.openingBalanceMinor)
      ..writeByte(6)
      ..write(obj.accountNumber)
      ..writeByte(7)
      ..write(obj.iconCodePoint)
      ..writeByte(8)
      ..write(obj.colorValue)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }
}
