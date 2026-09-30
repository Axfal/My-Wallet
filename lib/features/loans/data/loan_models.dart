import 'package:hive/hive.dart';

enum LoanType { given, taken }

class Person {
  final String id, fullName, phoneNumber;
  final String? whatsappNumber, address, relationship, note;
  final DateTime createdAt, updatedAt;
  const Person({required this.id, required this.fullName, required this.phoneNumber,
    this.whatsappNumber, this.address, this.relationship, this.note,
    required this.createdAt, required this.updatedAt});
  Map<String, dynamic> toMap() => {'id': id, 'name': fullName, 'phone': phoneNumber,
    'whatsapp': whatsappNumber, 'address': address, 'relationship': relationship,
    'note': note, 'created': createdAt, 'updated': updatedAt};
  factory Person.fromMap(Map m) => Person(id: m['id'], fullName: m['name'],
    phoneNumber: m['phone'], whatsappNumber: m['whatsapp'], address: m['address'],
    relationship: m['relationship'], note: m['note'], createdAt: m['created'], updatedAt: m['updated']);
}

class Loan {
  final String id, personId, accountId;
  final LoanType type;
  final int originalAmountMinor, outstandingAmountMinor;
  final DateTime issuedAt, dueAt, createdAt, updatedAt;
  final DateTime? reminderAt;
  final String? note, referenceNumber, proofPath;
  final String? writeOffReason;
  final bool cancelled;
  const Loan({required this.id, required this.personId, required this.accountId,
    required this.type, required this.originalAmountMinor, required this.outstandingAmountMinor,
    required this.issuedAt, required this.dueAt, this.reminderAt, this.note,
    this.referenceNumber, this.proofPath, this.writeOffReason, this.cancelled = false,
    required this.createdAt, required this.updatedAt});
  String get status => cancelled ? 'Cancelled' : outstandingAmountMinor == 0 ? 'Paid'
    : dueAt.isBefore(DateTime.now()) ? 'Overdue'
    : outstandingAmountMinor < originalAmountMinor ? 'Partially Paid' : 'Active';
  Loan copyWith({int? outstandingAmountMinor, bool? cancelled,
    String? writeOffReason, DateTime? updatedAt}) => Loan(
    id: id, personId: personId, accountId: accountId, type: type,
    originalAmountMinor: originalAmountMinor,
    outstandingAmountMinor: outstandingAmountMinor ?? this.outstandingAmountMinor,
    issuedAt: issuedAt, dueAt: dueAt, reminderAt: reminderAt, note: note,
    referenceNumber: referenceNumber, proofPath: proofPath,
    writeOffReason: writeOffReason ?? this.writeOffReason,
    cancelled: cancelled ?? this.cancelled, createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt);
  Map<String, dynamic> toMap() => {'id': id, 'person': personId, 'account': accountId,
    'type': type.name, 'amount': originalAmountMinor, 'outstanding': outstandingAmountMinor,
    'issued': issuedAt, 'due': dueAt, 'reminder': reminderAt, 'note': note,
    'reference': referenceNumber, 'proof': proofPath, 'cancelled': cancelled,
    'writeOffReason': writeOffReason,
    'created': createdAt, 'updated': updatedAt};
  factory Loan.fromMap(Map m) => Loan(id: m['id'], personId: m['person'], accountId: m['account'],
    type: LoanType.values.byName(m['type']), originalAmountMinor: m['amount'],
    outstandingAmountMinor: m['outstanding'], issuedAt: m['issued'], dueAt: m['due'],
    reminderAt: m['reminder'], note: m['note'], referenceNumber: m['reference'],
    proofPath: m['proof'], cancelled: m['cancelled'] ?? false,
    writeOffReason: m['writeOffReason'],
    createdAt: m['created'], updatedAt: m['updated']);
}

class LoanRepayment {
  final String id, loanId, accountId;
  final int amountMinor;
  final DateTime paidAt, createdAt;
  final String? note, proofPath;
  const LoanRepayment({required this.id, required this.loanId, required this.accountId,
    required this.amountMinor, required this.paidAt, required this.createdAt,
    this.note, this.proofPath});
  Map<String, dynamic> toMap() => {'id': id, 'loan': loanId, 'account': accountId,
    'amount': amountMinor, 'paid': paidAt, 'created': createdAt, 'note': note, 'proof': proofPath};
  factory LoanRepayment.fromMap(Map m) => LoanRepayment(id: m['id'], loanId: m['loan'],
    accountId: m['account'], amountMinor: m['amount'], paidAt: m['paid'],
    createdAt: m['created'], note: m['note'], proofPath: m['proof']);
}

class AttachmentMetadata {
  final String id, localPath, originalName, mimeType;
  final DateTime createdAt;
  const AttachmentMetadata({required this.id, required this.localPath,
    required this.originalName, required this.mimeType, required this.createdAt});
  Map<String, dynamic> toMap() => {'id': id, 'path': localPath, 'name': originalName,
    'mime': mimeType, 'created': createdAt};
  factory AttachmentMetadata.fromMap(Map m) => AttachmentMetadata(id: m['id'],
    localPath: m['path'], originalName: m['name'], mimeType: m['mime'], createdAt: m['created']);
}

class PersonAdapter extends TypeAdapter<Person> {
  @override final int typeId = 3;
  @override Person read(BinaryReader reader) => Person.fromMap(reader.readMap());
  @override void write(BinaryWriter writer, Person value) => writer.writeMap(value.toMap());
}
class LoanAdapter extends TypeAdapter<Loan> {
  @override final int typeId = 4;
  @override Loan read(BinaryReader reader) => Loan.fromMap(reader.readMap());
  @override void write(BinaryWriter writer, Loan value) => writer.writeMap(value.toMap());
}
class LoanRepaymentAdapter extends TypeAdapter<LoanRepayment> {
  @override final int typeId = 5;
  @override LoanRepayment read(BinaryReader reader) => LoanRepayment.fromMap(reader.readMap());
  @override void write(BinaryWriter writer, LoanRepayment value) => writer.writeMap(value.toMap());
}
class AttachmentMetadataAdapter extends TypeAdapter<AttachmentMetadata> {
  @override final int typeId = 6;
  @override AttachmentMetadata read(BinaryReader reader) => AttachmentMetadata.fromMap(reader.readMap());
  @override void write(BinaryWriter writer, AttachmentMetadata value) => writer.writeMap(value.toMap());
}
