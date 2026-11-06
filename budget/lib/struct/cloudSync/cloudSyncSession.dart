import 'package:budget/struct/cloudSync/cloudSyncConfig.dart';
import 'package:budget/struct/firebaseAuthGlobal.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CloudSyncSession {
  final FirebaseFirestore db;
  final String uid;
  final DocumentReference<Map<String, dynamic>> userRoot;

  CloudSyncSession({
    required this.db,
    required this.uid,
    required this.userRoot,
  });

  CollectionReference<Map<String, dynamic>> collectionFor(CloudTable table) {
    final name = collectionNameForTable(table);
    return userRoot.collection(name);
  }

  DocumentReference<Map<String, dynamic>> docFor(
      CloudTable table, String docId) {
    return collectionFor(table).doc(docId);
  }

  DocumentReference<Map<String, dynamic>> get syncMetaDoc {
    return userRoot.collection(CloudCollections.meta).doc(CloudCollections.syncMetaDoc);
  }

  DocumentReference<Map<String, dynamic>> get settingsMetaDoc {
    return userRoot
        .collection(CloudCollections.meta)
        .doc(CloudCollections.settingsMetaDoc);
  }
}

bool _webPersistenceConfigured = false;

Future<CloudSyncSession?> getCloudSyncSession({
  FirebaseFirestore? firestoreOverride,
  String? uidOverride,
}) async {
  try {
    if (firestoreOverride != null && uidOverride != null) {
      final userRoot = firestoreOverride
          .collection(CloudCollections.users)
          .doc(uidOverride);
      return CloudSyncSession(
        db: firestoreOverride,
        uid: uidOverride,
        userRoot: userRoot,
      );
    }

    final FirebaseFirestore? db = await firebaseGetDBInstance();
    if (db == null) return null;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    if (kIsWeb && !_webPersistenceConfigured) {
      try {
        db.settings = const Settings(persistenceEnabled: true);
        _webPersistenceConfigured = true;
      } catch (e) {
        print("Web persistence configuration notice: $e");
      }
    }

    final userRoot = db.collection(CloudCollections.users).doc(user.uid);
    return CloudSyncSession(
      db: db,
      uid: user.uid,
      userRoot: userRoot,
    );
  } catch (e) {
    print("Error getting CloudSyncSession: $e");
    return null;
  }
}
