class ProfileModel {
  final String empName;
  final String dept;
  final String position;
  final String username;
  final String email;

  const ProfileModel({
    required this.empName,
    required this.dept,
    required this.position,
    required this.username,
    required this.email,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      empName: (json['emp_name'] ?? '') as String,
      dept: (json['dept'] ?? '') as String,
      position: (json['position'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      email: (json['email'] ?? '') as String,
    );
  }
}
