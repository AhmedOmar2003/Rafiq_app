class UserModel {
  final int id;
  final String name;
  final String email;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  // لتحويل البيانات إلى JSON لتخزينها بسهولة
  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'name': name,
      'email': email,
    };
  }

  // لتحويل JSON إلى موديل
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.parse(json['userId']),
      name: json['name'],
      email: json['email'],
    );
  }
}
