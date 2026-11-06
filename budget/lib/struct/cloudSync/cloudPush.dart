import 'package:budget/database/tables.dart';
import 'package:budget/struct/cloudSync/cloudSerializer.dart';
import 'package:budget/struct/cloudSync/cloudSyncConfig.dart';
import 'package:budget/struct/cloudSync/cloudSyncLock.dart';
import 'package:budget/struct/cloudSync/cloudSyncSession.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

CloudTable? cloudTableFromDeleteLogType(DeleteLogType type) {
  switch (type) {
    case DeleteLogType.TransactionWallet:
      return CloudTable.wallets;
    case DeleteLogType.TransactionCategory:
      return CloudTable.categories;
    case DeleteLogType.Budget:
      return CloudTable.budgets;
    case DeleteLogType.CategoryBudgetLimit:
      return CloudTable.categoryBudgetLimits;
    case DeleteLogType.Transaction:
      return CloudTable.transactions;
    case DeleteLogType.TransactionAssociatedTitle:
      return CloudTable.associatedTitles;
    case DeleteLogType.ScannerTemplate:
      return CloudTable.scannerTemplates;
    case DeleteLogType.Objective:
      return CloudTable.objectives;
    case DeleteLogType.Unused:
      return null;
  }
}

Future<bool> pushLocalChangesToCloud({
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
      print("Cloud push skipped: no active session");
      return false;
    }

    final FinanceDatabase targetDb = dbOverride ?? database;

    String? lastPushedString =
        sharedPreferences.getString("cloudLastPushedAt");
    DateTime lastPushedAt = lastPushedString != null
        ? (DateTime.tryParse(lastPushedString) ?? DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);

    final DateTime pushStarted = DateTime.now();

    // 1. Fetch changed rows in dependency order
    final wallets = await targetDb.getAllNewWallets(lastPushedAt);
    final categories = await targetDb.getAllNewCategories(lastPushedAt);
    final objectives = await targetDb.getAllNewObjectives(lastPushedAt);
    final budgets = await targetDb.getAllNewBudgets(lastPushedAt);
    final categoryBudgetLimits =
        await targetDb.getAllNewCategoryBudgetLimits(lastPushedAt);
    final associatedTitles =
        await targetDb.getAllNewAssociatedTitles(lastPushedAt);
    final scannerTemplates =
        await targetDb.getAllNewScannerTemplates(lastPushedAt);
    final transactions = await targetDb.getAllNewTransactions(lastPushedAt);
    final deleteLogs = await targetDb.getAllNewDeleteLogs(lastPushedAt);

    final int totalCount = wallets.length +
        categories.length +
        objectives.length +
        budgets.length +
        categoryBudgetLimits.length +
        associatedTitles.length +
        scannerTemplates.length +
        transactions.length +
        (deleteLogs.length * 2);

    if (totalCount == 0) {
      // Nothing changed, update push timestamp and return
      await sharedPreferences.setString(
          "cloudLastPushedAt", pushStarted.toIso8601String());
      return true;
    }

    WriteBatch batch = session.db.batch();
    int opCount = 0;
    int processedCount = 0;

    Future<void> commitBatchIfNeeded({bool forceCommit = false}) async {
      if (opCount >= 400 || (forceCommit && opCount > 0)) {
        await batch.commit();
        batch = session.db.batch();
        opCount = 0;
      }
    }

    void updateProgress() {
      if (totalCount > 0) {
        loadingProgressKey.currentState
            ?.setProgressPercentage(processedCount / totalCount);
      }
    }

    // Helper to queue an upsert
    Future<void> queueUpsert(
        CloudTable table, String docId, Map<String, dynamic> data) async {
      final docRef = session.docFor(table, docId);
      final payload = <String, dynamic>{
        ...data,
        CloudFields.serverUpdatedAt: FieldValue.serverTimestamp(),
        CloudFields.clientId: clientID,
        CloudFields.schemaVersion: schemaVersionGlobal,
      };
      batch.set(docRef, payload, SetOptions(merge: false));
      opCount++;
      processedCount++;
      updateProgress();
      await commitBatchIfNeeded();
    }

    // Push in dependency order
    for (final wallet in wallets) {
      await queueUpsert(CloudTable.wallets, wallet.walletPk,
          CloudSerializer.walletToCloud(wallet));
    }

    for (final category in categories) {
      await queueUpsert(CloudTable.categories, category.categoryPk,
          CloudSerializer.categoryToCloud(category));
    }

    for (final objective in objectives) {
      await queueUpsert(CloudTable.objectives, objective.objectivePk,
          CloudSerializer.objectiveToCloud(objective));
    }

    for (final budgetItem in budgets) {
      await queueUpsert(CloudTable.budgets, budgetItem.budgetPk,
          CloudSerializer.budgetToCloud(budgetItem));
    }

    for (final limit in categoryBudgetLimits) {
      await queueUpsert(CloudTable.categoryBudgetLimits, limit.categoryLimitPk,
          CloudSerializer.categoryBudgetLimitToCloud(limit));
    }

    for (final title in associatedTitles) {
      await queueUpsert(CloudTable.associatedTitles, title.associatedTitlePk,
          CloudSerializer.associatedTitleToCloud(title));
    }

    for (final template in scannerTemplates) {
      await queueUpsert(CloudTable.scannerTemplates, template.scannerTemplatePk,
          CloudSerializer.scannerTemplateToCloud(template));
    }

    for (final tx in transactions) {
      await queueUpsert(CloudTable.transactions, tx.transactionPk,
          CloudSerializer.transactionToCloud(tx));
    }

    // Push delete tombstones and delete the corresponding cloud documents
    for (final deleteLog in deleteLogs) {
      // 1. Write the delete tombstone doc
      await queueUpsert(CloudTable.deleteLogs, deleteLog.deleteLogPk,
          CloudSerializer.deleteLogToCloud(deleteLog));

      // 2. Also delete the actual document from the data collection to keep cloud clean
      final targetTable = cloudTableFromDeleteLogType(deleteLog.type);
      if (targetTable != null) {
        final dataDocRef = session.docFor(targetTable, deleteLog.entryPk);
        batch.delete(dataDocRef);
        opCount++;
        processedCount++;
        updateProgress();
        await commitBatchIfNeeded();
      }
    }

    // Commit any remaining writes
    await commitBatchIfNeeded(forceCommit: true);

    // Update schema version in sync meta doc
    try {
      await session.syncMetaDoc.set({
        'schemaVersion': schemaVersionGlobal,
        'lastWriterClientId': clientID,
        'lastPushedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Notice: could not update syncMetaDoc: $e");
    }

    // Successfully completed all writes - save cursor
    await sharedPreferences.setString(
        "cloudLastPushedAt", pushStarted.toIso8601String());
    loadingProgressKey.currentState?.setProgressPercentage(0);
    print("Cloud push successful: pushed $processedCount operations");
    return true;
  } catch (e, stack) {
    print("Error pushing local changes to cloud: $e");
    print(stack);
    loadingProgressKey.currentState?.setProgressPercentage(0);
    return false;
  }
  });
}
