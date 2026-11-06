import 'package:budget/struct/cloudSync/cloudSyncConfig.dart';
import 'package:budget/struct/cloudSync/cloudSyncLock.dart';
import 'package:budget/struct/cloudSync/cloudSyncSession.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

Future<bool> cleanupOldTombstones({
  CloudSyncSession? sessionOverride,
  int daysTtl = 180,
  bool force = false,
}) async {
  return CloudSyncLock.synchronized(() async {
    try {
      final String? lastCleanupStr =
          sharedPreferences.getString("cloudLastTombstoneCleanup");
      if (!force && lastCleanupStr != null) {
        final lastCleanup = DateTime.tryParse(lastCleanupStr);
        if (lastCleanup != null &&
            DateTime.now().difference(lastCleanup).inHours < 24) {
          return true;
        }
      }

      final session = sessionOverride ?? await getCloudSyncSession();
      if (session == null) return false;

      final cutoffDate = DateTime.now().subtract(Duration(days: daysTtl));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate.toUtc());

      final snapshot = await session
          .collectionFor(CloudTable.deleteLogs)
          .where(CloudFields.serverUpdatedAt, isLessThan: cutoffTimestamp)
          .limit(400)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = session.db.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print(
            "Cloud maintenance: deleted ${snapshot.docs.length} expired deleteLogs tombstones");
      }

      await sharedPreferences.setString(
          "cloudLastTombstoneCleanup", DateTime.now().toIso8601String());
      return true;
    } catch (e) {
      print("Notice during tombstone cleanup: $e");
      return false;
    }
  });
}

Future<bool> deleteMyCloudData({
  CloudSyncSession? sessionOverride,
}) async {
  return CloudSyncLock.synchronized(() async {
    try {
      final session = sessionOverride ?? await getCloudSyncSession();
      if (session == null) {
        print("Delete cloud data failed: no session");
        return false;
      }

      print("Deleting all cloud data for user ${session.uid}...");

      for (final table in CloudTable.values) {
        final collectionRef = session.collectionFor(table);
        bool hasMore = true;
        while (hasMore) {
          final snapshot = await collectionRef.limit(400).get();
          if (snapshot.docs.isEmpty) {
            hasMore = false;
            break;
          }
          final batch = session.db.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          if (snapshot.docs.length < 400) {
            hasMore = false;
          }
        }
      }

      // Delete meta documents
      try {
        await session.syncMetaDoc.delete();
        await session.settingsMetaDoc.delete();
      } catch (_) {}

      // Reset local sync state
      await sharedPreferences.remove("cloudLastPushedAt");
      for (final table in CloudTable.values) {
        await sharedPreferences.remove("cloudPullCursor_${table.name}");
      }
      await updateSettings("cloudInitialSyncDone", false,
          updateGlobalState: false);
      await updateSettings("cloudSyncEnabled", false,
          updateGlobalState: true);

      print("All cloud data successfully deleted");
      return true;
    } catch (e, stack) {
      print("Error deleting cloud data: $e");
      print(stack);
      return false;
    }
  });
}
