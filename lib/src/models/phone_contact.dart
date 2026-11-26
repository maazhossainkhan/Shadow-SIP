class PhoneContact {
  const PhoneContact({required this.name, required this.number});

  final String name;
  final String number;

  Map<String, Object?> toJson() => {'name': name, 'number': number};

  factory PhoneContact.fromJson(Map<String, dynamic> json) => PhoneContact(
        name: json['name'] as String? ?? '',
        number: json['number'] as String? ?? '',
      );
}
