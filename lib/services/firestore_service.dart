import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService._();

  static final instance = FirestoreService._();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  User get currentUser {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    return user;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> profileStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  Future<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      _db.collection('users').doc(uid).get();

  Future<void> createProfile({
    required User user,
    required String name,
    required String studentId,
    required String department,
    required String year,
  }) => _db.collection('users').doc(user.uid).set({
    'uid': user.uid,
    'name': name,
    'email': user.email ?? '',
    'studentId': studentId,
    'department': department,
    'year': year,
    'role': 'student',
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> updateProfile({
    required String name,
    required String studentId,
    required String department,
    required String year,
  }) => _db.collection('users').doc(currentUser.uid).update({
    'name': name,
    'studentId': studentId,
    'department': department,
    'year': year,
  });

  CollectionReference<Map<String, dynamic>> get grievances =>
      _db.collection('grievances');

  Stream<QuerySnapshot<Map<String, dynamic>>> studentGrievances(String uid) =>
      grievances.where('studentId', isEqualTo: uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> allGrievances() =>
      grievances.orderBy('createdAt', descending: true).snapshots();

  Future<String> createGrievance({
    required String category,
    required String subject,
    required String description,
    required String priority,
    required String studentName,
    required String studentEmail,
  }) async {
    final reference = grievances.doc();
    final data = {
      'grievanceId': reference.id,
      'studentId': currentUser.uid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'category': category,
      'subject': subject,
      'description': description,
      'priority': priority,
      'status': 'Submitted',
      'adminResponse': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await reference.set(data);
    return reference.id;
  }

  Future<void> updateGrievance(
    String id, {
    required String status,
    required String response,
  }) => grievances.doc(id).update({
    'status': status,
    'adminResponse': response,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> students() =>
      _db.collection('users').where('role', isEqualTo: 'student').snapshots();
}
