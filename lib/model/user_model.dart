class UserModel {
  final String id;
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
      id: json['userId'].toString(),
      name: json['name'],
      email: json['email'],
    );
  }
}
