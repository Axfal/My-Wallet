import 'package:hive/hive.dart';

class AppSettings {
  final String currencySymbol;
  final bool allowNegativeBalance;
  final DateTime updatedAt;
  const AppSettings({this.currencySymbol = '₨', this.allowNegativeBalance = false,
    required this.updatedAt});
  AppSettings copyWith({String? currencySymbol, bool? allowNegativeBalance}) => AppSettings(
    currencySymbol: currencySymbol ?? this.currencySymbol,
    allowNegativeBalance: allowNegativeBalance ?? this.allowNegativeBalance,
    updatedAt: DateTime.now());
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override final int typeId = 7;
  @override AppSettings read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{for (var i = 0; i < count; i++) reader.readByte(): reader.read()};
    return AppSettings(currencySymbol: fields[0] as String? ?? '₨',
      allowNegativeBalance: fields[1] as bool? ?? false,
      updatedAt: fields[2] as DateTime? ?? DateTime.now());
  }
  @override void write(BinaryWriter writer, AppSettings value) {
    writer..writeByte(3)..writeByte(0)..write(value.currencySymbol)
      ..writeByte(1)..write(value.allowNegativeBalance)
      ..writeByte(2)..write(value.updatedAt);
  }
}
