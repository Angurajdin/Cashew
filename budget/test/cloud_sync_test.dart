import 'package:budget/database/tables.dart';
import 'package:budget/struct/cloudSync/cloudPull.dart';
import 'package:budget/struct/cloudSync/cloudPush.dart';
import 'package:budget/struct/cloudSync/cloudSyncConfig.dart';
import 'package:budget/struct/cloudSync/cloudSyncSession.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:drift/drift.dart' hide Table, isNull;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Sync Engine Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FinanceDatabase dbA;
    late FinanceDatabase dbB;
    late CloudSyncSession sessionA;
    late CloudSyncSession sessionB;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        "cloudSyncProvider": "firestore",
        "cloudSyncEnabled": true,
        "sharedBudgets": false,
        "selectedWalletPk": "0",
      });
      sharedPreferences = await SharedPreferences.getInstance();
      appStateSettings = {
        "cloudSyncProvider": "firestore",
        "cloudSyncEnabled": true,
        "sharedBudgets": false,
        "selectedWalletPk": "0",
      };

      fakeFirestore = FakeFirebaseFirestore();
      dbA = FinanceDatabase(NativeDatabase.memory());
      dbB = FinanceDatabase(NativeDatabase.memory());
      database = dbA;

      final userRoot = fakeFirestore.collection('users').doc('test-user-uid');
      sessionA = CloudSyncSession(
        db: fakeFirestore,
        uid: 'test-user-uid',
        userRoot: userRoot,
      );
      sessionB = CloudSyncSession(
        db: fakeFirestore,
        uid: 'test-user-uid',
        userRoot: userRoot,
      );
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
    });

    test('Push then pull: transaction created on A is pulled into B', () async {
      database = dbA;
      final now = DateTime.now();

      // Setup default category & wallet on dbA & dbB
      await dbA.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: 'cat-1',
          name: 'Food',
          dateCreated: now,
          order: 0,
          income: false,
        ),
      );
      await dbA.createOrUpdateWallet(
        TransactionWallet(
          walletPk: '0',
          name: 'Default',
          dateCreated: now,
          order: 0,
          decimals: 2,
        ),
      );

      // Create transaction on A
      await dbA.createOrUpdateTransaction(
        Transaction(
          transactionPk: 'tx-1',
          name: 'Lunch',
          amount: 15.50,
          note: 'Tasty',
          categoryFk: 'cat-1',
          walletFk: '0',
          dateCreated: now,
          dateTimeModified: now,
          income: false,
          paid: true,
          skipPaid: false,
        ),
      );

      // Push A -> Cloud
      clientID = 'client-A';
      final pushResult = await pushLocalChangesToCloud(
        sessionOverride: sessionA,
        dbOverride: dbA,
        force: true,
      );
      expect(pushResult, isTrue);

      // Verify doc exists in fake Firestore
      final doc = await sessionA.docFor(CloudTable.transactions, 'tx-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'Lunch');
      expect(doc.data()?[CloudFields.clientId], 'client-A');

      // Pull Cloud -> B
      database = dbB;
      clientID = 'client-B';
      final pullResult = await pullCloudChanges(
        sessionOverride: sessionB,
        dbOverride: dbB,
        force: true,
      );
      expect(pullResult, isTrue);

      // Verify B now has the transaction
      final txOnB = await dbB.getTransactionFromPk('tx-1');
      expect(txOnB.name, 'Lunch');
      expect(txOnB.amount, 15.50);
    });

    test('LWW: newer remote change overwrites older local change', () async {
      final t0 = DateTime.utc(2026, 1, 1, 10, 0, 0);
      final t1 = DateTime.utc(2026, 1, 1, 11, 0, 0);

      // Local row on B with older timestamp t0
      database = dbB;
      await dbB.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: 'cat-shared',
          name: 'Groceries Old',
          dateCreated: t0,
          dateTimeModified: t0,
          order: 0,
          income: false,
        ),
        customDateTimeModified: t0,
        updateSharedEntry: false,
      );

      // Row on A with newer timestamp t1
      database = dbA;
      await dbA.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: 'cat-shared',
          name: 'Groceries Updated',
          dateCreated: t0,
          dateTimeModified: t1,
          order: 0,
          income: false,
        ),
        customDateTimeModified: t1,
        updateSharedEntry: false,
      );

      clientID = 'client-A';
      await pushLocalChangesToCloud(
        sessionOverride: sessionA,
        dbOverride: dbA,
        force: true,
      );

      database = dbB;
      clientID = 'client-B';
      await pullCloudChanges(
        sessionOverride: sessionB,
        dbOverride: dbB,
        force: true,
      );

      final catOnB = await dbB.getCategoryInstance('cat-shared');
      expect(catOnB.name, 'Groceries Updated');
    });

    test('LWW: older remote change does NOT overwrite newer local change', () async {
      final tOld = DateTime.utc(2026, 1, 1, 10, 0, 0);
      final tNew = DateTime.utc(2026, 1, 1, 12, 0, 0);

      // Older edit on A
      database = dbA;
      await dbA.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: 'cat-lww',
          name: 'Stale Remote Name',
          dateCreated: tOld,
          dateTimeModified: tOld,
          order: 0,
          income: false,
        ),
        customDateTimeModified: tOld,
        updateSharedEntry: false,
      );

      clientID = 'client-A';
      await pushLocalChangesToCloud(
        sessionOverride: sessionA,
        dbOverride: dbA,
        force: true,
      );

      // Newer edit on B
      database = dbB;
      await dbB.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: 'cat-lww',
          name: 'Fresh Local Name',
          dateCreated: tOld,
          dateTimeModified: tNew,
          order: 0,
          income: false,
        ),
        customDateTimeModified: tNew,
        updateSharedEntry: false,
      );

      clientID = 'client-B';
      await pullCloudChanges(
        sessionOverride: sessionB,
        dbOverride: dbB,
        force: true,
      );

      final catOnB = await dbB.getCategoryInstance('cat-lww');
      expect(catOnB.name, 'Fresh Local Name');
    });

    test('Deletions propagate tombstones and remove remote docs', () async {
      final tCreate = DateTime.utc(2026, 1, 1, 10, 0, 0);

      // Create on A and B with tCreate
      database = dbA;
      await dbA.createOrUpdateWallet(
        TransactionWallet(
          walletPk: 'w-del',
          name: 'To Delete',
          dateCreated: tCreate,
          dateTimeModified: tCreate,
          order: 1,
          decimals: 2,
        ),
        customDateTimeModified: tCreate,
      );

      database = dbB;
      await dbB.createOrUpdateWallet(
        TransactionWallet(
          walletPk: 'w-del',
          name: 'To Delete',
          dateCreated: tCreate,
          dateTimeModified: tCreate,
          order: 1,
          decimals: 2,
        ),
        customDateTimeModified: tCreate,
      );

      clientID = 'client-A';
      database = dbA;
      await pushLocalChangesToCloud(
        sessionOverride: sessionA,
        dbOverride: dbA,
        force: true,
      );

      // Verify doc exists in cloud
      final docBefore =
          await sessionA.docFor(CloudTable.wallets, 'w-del').get();
      expect(docBefore.exists, isTrue);

      // Delete on A (creates DeleteLog with DateTime.now() > tCreate)
      await dbA.deleteWallet('w-del', 1);

      // Push delete from A
      await pushLocalChangesToCloud(
        sessionOverride: sessionA,
        dbOverride: dbA,
        force: true,
      );

      // Cloud data doc should now be deleted
      final docAfter =
          await sessionA.docFor(CloudTable.wallets, 'w-del').get();
      expect(docAfter.exists, isFalse);

      // Delete tombstone should exist in deleteLogs collection
      final deleteLogsSnapshot =
          await sessionA.collectionFor(CloudTable.deleteLogs).get();
      expect(deleteLogsSnapshot.docs.isNotEmpty, isTrue);
      expect(
          deleteLogsSnapshot.docs
              .any((d) => d.data()['entryPk'] == 'w-del'),
          isTrue);

      // Pull into B should ensure wallet is deleted on B
      database = dbB;
      clientID = 'client-B';
      await pullCloudChanges(
        sessionOverride: sessionB,
        dbOverride: dbB,
        force: true,
      );

      final walletOnB =
          await (dbB.select(dbB.wallets)..where((w) => w.walletPk.equals('w-del')))
              .getSingleOrNull();
      expect(walletOnB, isNull);
    });

    test('Echo skip: own changes are skipped during pull', () async {
      database = dbA;
      final now = DateTime.now();
      await dbA.createOrUpdateCategory(
        TransactionCategory(
          categoryPk: 'cat-echo',
          name: 'Echo Test',
          dateCreated: now,
          order: 0,
          income: false,
        ),
      );

      clientID = 'client-same';
      await pushLocalChangesToCloud(
        sessionOverride: sessionA,
        dbOverride: dbA,
        force: true,
      );

      // Pull with same clientID should skip
      final pullResult = await pullCloudChanges(
        sessionOverride: sessionA,
        dbOverride: dbA,
        force: true,
      );
      expect(pullResult, isTrue);
    });
  });
}
