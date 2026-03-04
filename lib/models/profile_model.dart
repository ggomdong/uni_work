class ProfileModel {
  final String empName;
  final String dept;
  final String position;
  final String username;
  final String email;
  final String branchCode;
  final String branchName;

  const ProfileModel({
    required this.empName,
    required this.dept,
    required this.position,
    required this.username,
    required this.email,
    required this.branchCode,
    required this.branchName,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      empName: (json['emp_name'] ?? '') as String,
      dept: (json['dept'] ?? '') as String,
      position: (json['position'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      branchCode: (json['branch_code'] ?? '') as String,
      branchName: (json['branch_name'] ?? '') as String,
    );
  }
}
