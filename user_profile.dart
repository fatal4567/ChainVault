class UserProfile {
  String username;
  String publicAddress;

  UserProfile({required this.username, required this.publicAddress});

  Map<String, dynamic> toJson() => {
        'username': username,
        'publicAddress': publicAddress,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        username: json['username'],
        publicAddress: json['publicAddress'],
      );
}