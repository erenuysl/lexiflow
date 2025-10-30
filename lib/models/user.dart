import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isAnonymous;
  final bool emailVerified;
  final DateTime? creationTime;
  final DateTime? lastSignInTime;

  const User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isAnonymous = false,
    this.emailVerified = false,
    this.creationTime,
    this.lastSignInTime,
  });

  // Firebase User'dan dönüştürme
  factory User.fromFirebaseUser(firebase_auth.User firebaseUser) {
    return User(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoURL: firebaseUser.photoURL,
      isAnonymous: firebaseUser.isAnonymous,
      emailVerified: firebaseUser.emailVerified,
      creationTime: firebaseUser.metadata.creationTime,
      lastSignInTime: firebaseUser.metadata.lastSignInTime,
    );
  }

  // JSON'dan dönüştürme
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] ?? '',
      email: json['email'],
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      isAnonymous: json['isAnonymous'] ?? false,
      emailVerified: json['emailVerified'] ?? false,
      creationTime: json['creationTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['creationTime'])
          : null,
      lastSignInTime: json['lastSignInTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSignInTime'])
          : null,
    );
  }

  // JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isAnonymous': isAnonymous,
      'emailVerified': emailVerified,
      'creationTime': creationTime?.millisecondsSinceEpoch,
      'lastSignInTime': lastSignInTime?.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'User(uid: $uid, email: $email, displayName: $displayName, isAnonymous: $isAnonymous)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}