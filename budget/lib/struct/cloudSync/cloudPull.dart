import 'package:budget/database/tables.dart';
import 'package:budget/struct/cloudSync/cloudSerializer.dart';
import 'package:budget/struct/cloudSync/cloudSyncConfig.dart';
import 'package:budget/struct/cloudSync/cloudSyncLock.dart';
import 'package:budget/struct/cloudSync/cloudSyncSession.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/syncClient.dart';
import 'package:budget/widgets/walletEntry.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

Future<bool> pullCloudChanges({
  CloudSyncSession? sessionOverride,
  FinanceDatabase? dbOverride,
  bool force = false,
}) async {
  if (!force && !isFirestoreSyncActive() && sessionOverride == null) {
    return false;
  }

  return CloudSyncLock.synchronized(() async {
    try {
      final session = sessionOverride ?? await getCloudSyncSession();
      if (session == null) {
        print("Cloud pull skipped: no active session");
        return false;
      }

      final FinanceDatabase targetDb = dbOverride ?? database;

      // 1. Check schema compatibility
      try {
        final syncMetaSnapshot = await session.syncMetaDoc.get();
        if (syncMetaSnapshot.exists && syncMetaSnapshot.data() != null) {
          final remoteSchemaVersion =
              syncMetaSnapshot.data()?['schemaVersion'];
          if (remoteSchemaVersion is int &&
              remoteSchemaVersion > schemaVersionGlobal) {
            print(
                "Cloud pull stopped: remote schema version ($remoteSchemaVersion) is newer than app schema version ($schemaVersionGlobal)");
            return false;
          }
        }
      } catch (e) {
        print("Notice: could not read syncMetaDoc: $e");
      }

      final List<CloudTable> tableOrder = [
        CloudTable.wallets,
        CloudTable.categories,
        CloudTable.objectives,
        CloudTable.budgets,
        CloudTable.categoryBudgetLimits,
        CloudTable.associatedTitles,
        CloudTable.scannerTemplates,
        CloudTable.transactions,
        CloudTable.deleteLogs,
      ];

      final List<SyncLog> allLogs = [];
      final List<DeleteLog> deleteLogsToInsert = [];
      final Map<String, String> newCursorsToSave = {};

      for (final table in tableOrder) {
        final String cursorKey = "cloudPullCursor_${table.name}";
        final String? storedCursor = sharedPreferences.getString(cursorKey);
        DateTime cursorDateTime = storedCursor != null
            ? (DateTime.tryParse(storedCursor) ??
                DateTime.fromMillisecondsSinceEpoch(0))
            : DateTime.fromMillisecondsSinceEpoch(0);

        Timestamp cursorTimestamp = Timestamp.fromDate(cursorDateTime.toUtc());
        Timestamp maxTimestampSeen = cursorTimestamp;

        bool hasMore = true;
        while (hasMore) {
          final querySnapshot = await session
              .collectionFor(table)
              .where(CloudFields.serverUpdatedAt,
                  isGreaterThan: cursorTimestamp)
              .orderBy(CloudFields.serverUpdatedAt)
              .limit(500)
              .get();

          final docs = querySnapshot.docs;
          if (docs.isEmpty) {
            hasMore = false;
            break;
          }

          for (final doc in docs) {
            final data = doc.data();
            final dynamic rawTimestamp = data[CloudFields.serverUpdatedAt];
            if (rawTimestamp is Timestamp) {
              if (rawTimestamp.compareTo(maxTimestampSeen) > 0) {
                maxTimestampSeen = rawTimestamp;
              }
              cursorTimestamp = rawTimestamp;
            }

            final String? docClientId = data[CloudFields.clientId]?.toString();
            // Skip own echoes
            if (docClientId != null && docClientId == clientID) {
              continue;
            }

            final dynamic row = CloudSerializer.rowFromCloud(table, data);
            final syncLog = _syncLogFromRow(table, row);
            if (syncLog != null) {
              allLogs.add(syncLog);
            }

            if (row is DeleteLog) {
              deleteLogsToInsert.add(row);
            }
          }

          if (docs.length < 500) {
            hasMore = false;
          }
        }

        newCursorsToSave[cursorKey] =
            maxTimestampSeen.toDate().toUtc().toIso8601String();
      }

      // 2. Process all logs atomically through LWW
      if (allLogs.isNotEmpty) {
        CloudSyncLock.isApplyingCloudChanges = true;
        try {
          await targetDb.processSyncLogs(allLogs);

          // Save received deleteLogs locally
          if (deleteLogsToInsert.isNotEmpty) {
            for (final dl in deleteLogsToInsert) {
              try {
                await targetDb.createDeleteLog(
                  dl.type,
                  dl.entryPk,
                );
              } catch (_) {}
            }
          }
        } finally {
          CloudSyncLock.isApplyingCloudChanges = false;
        }
      }

      // 3. Save new cursors
      for (final entry in newCursorsToSave.entries) {
        await sharedPreferences.setString(entry.key, entry.value);
      }

      // 4. Verify selected wallet still exists
      try {
        final List<TransactionWallet> allWallets =
            await targetDb.getAllWallets();
        final String? selectedWallet = appStateSettings["selectedWalletPk"];
        if (allWallets.isNotEmpty) {
          final exists =
              allWallets.any((w) => w.walletPk == selectedWallet);
          if (!exists) {
            await setPrimaryWallet(allWallets.first.walletPk);
          }
        }
      } catch (e) {
        print("Notice checking selected wallet: $e");
      }

      final nowString = DateTime.now().toString();
      appStateSettings["lastSynced"] = nowString;
      await sharedPreferences.setString("lastSynced", nowString);

      print("Cloud pull successful: applied ${allLogs.length} remote changes");
      return true;
    } catch (e, stack) {
      print("Error pulling cloud changes: $e");
      print(stack);
      return false;
    }
  });
}

SyncLog? _syncLogFromRow(CloudTable table, dynamic row) {
  switch (table) {
    case CloudTable.wallets:
      final TransactionWallet r = row;
      return SyncLog(
        updateLogType: UpdateLogType.TransactionWallet,
        pk: r.walletPk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.categories:
      final TransactionCategory r = row;
      return SyncLog(
        updateLogType: UpdateLogType.TransactionCategory,
        pk: r.categoryPk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.objectives:
      final Objective r = row;
      return SyncLog(
        updateLogType: UpdateLogType.Objective,
        pk: r.objectivePk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.budgets:
      final Budget r = row;
      return SyncLog(
        updateLogType: UpdateLogType.Budget,
        pk: r.budgetPk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.categoryBudgetLimits:
      final CategoryBudgetLimit r = row;
      return SyncLog(
        updateLogType: UpdateLogType.CategoryBudgetLimit,
        pk: r.categoryLimitPk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.associatedTitles:
      final TransactionAssociatedTitle r = row;
      return SyncLog(
        updateLogType: UpdateLogType.TransactionAssociatedTitle,
        pk: r.associatedTitlePk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.scannerTemplates:
      final ScannerTemplate r = row;
      return SyncLog(
        updateLogType: UpdateLogType.ScannerTemplate,
        pk: r.scannerTemplatePk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.transactions:
      final Transaction r = row;
      return SyncLog(
        updateLogType: UpdateLogType.Transaction,
        pk: r.transactionPk,
        itemToUpdate: r,
        transactionDateTime: r.dateTimeModified ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    case CloudTable.deleteLogs:
      final DeleteLog r = row;
      return SyncLog(
        deleteLogType: r.type,
        pk: r.entryPk,
        transactionDateTime: r.dateTimeModified,
      );
  }
}
