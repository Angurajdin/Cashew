import 'package:budget/database/tables.dart';
import 'package:budget/struct/cloudSync/cloudSerializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudSerializer Round-Trip Tests', () {
    test('TransactionWallet round-trip with full data', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final wallet = TransactionWallet(
        walletPk: 'w-1',
        name: 'Main Wallet',
        colour: '#FF0000',
        iconName: 'wallet_icon',
        dateCreated: now,
        dateTimeModified: now.add(const Duration(minutes: 5)),
        order: 1,
        currency: 'USD',
        currencyFormat: '\$#,##0.00',
        decimals: 2,
        homePageWidgetDisplay: [
          HomePageWidgetDisplay.WalletSwitcher,
          HomePageWidgetDisplay.PieChart,
        ],
      );

      final cloudMap = CloudSerializer.walletToCloud(wallet);
      expect(cloudMap['walletPk'], 'w-1');
      expect(cloudMap['homePageWidgetDisplay'], isA<List<dynamic>>());

      final roundTrip = CloudSerializer.walletFromCloud(cloudMap);
      expect(roundTrip.walletPk, wallet.walletPk);
      expect(roundTrip.name, wallet.name);
      expect(roundTrip.colour, wallet.colour);
      expect(roundTrip.iconName, wallet.iconName);
      expect(roundTrip.dateCreated.toUtc(), wallet.dateCreated);
      expect(roundTrip.dateTimeModified?.toUtc(), wallet.dateTimeModified);
      expect(roundTrip.order, wallet.order);
      expect(roundTrip.currency, wallet.currency);
      expect(roundTrip.currencyFormat, wallet.currencyFormat);
      expect(roundTrip.decimals, wallet.decimals);
      expect(roundTrip.homePageWidgetDisplay, wallet.homePageWidgetDisplay);
    });

    test('TransactionWallet round-trip with nulls', () {
      final now = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final wallet = TransactionWallet(
        walletPk: 'w-null',
        name: 'Empty Wallet',
        colour: null,
        iconName: null,
        dateCreated: now,
        dateTimeModified: null,
        order: 0,
        currency: null,
        currencyFormat: null,
        decimals: 2,
        homePageWidgetDisplay: null,
      );

      final cloudMap = CloudSerializer.walletToCloud(wallet);
      final roundTrip = CloudSerializer.walletFromCloud(cloudMap);
      expect(roundTrip.walletPk, wallet.walletPk);
      expect(roundTrip.name, wallet.name);
      expect(roundTrip.colour, isNull);
      expect(roundTrip.iconName, isNull);
      expect(roundTrip.dateTimeModified, isNull);
      expect(roundTrip.homePageWidgetDisplay, isNull);
    });

    test('Transaction round-trip with full data', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final tx = Transaction(
        transactionPk: 'tx-1',
        pairedTransactionFk: 'tx-0',
        name: 'Grocery Shopping',
        amount: 45.67,
        note: 'Supermarket receipt',
        categoryFk: 'cat-food',
        subCategoryFk: 'cat-groceries',
        walletFk: 'w-1',
        dateCreated: now,
        dateTimeModified: now.add(const Duration(minutes: 2)),
        originalDateDue: now.subtract(const Duration(days: 1)),
        income: false,
        periodLength: 1,
        reoccurrence: BudgetReoccurence.monthly,
        endDate: now.add(const Duration(days: 365)),
        upcomingTransactionNotification: true,
        type: TransactionSpecialType.subscription,
        paid: true,
        createdAnotherFutureTransaction: false,
        skipPaid: false,
        methodAdded: MethodAdded.email,
        transactionOwnerEmail: 'user@example.com',
        transactionOriginalOwnerEmail: 'orig@example.com',
        sharedKey: 'shared-123',
        sharedOldKey: 'old-123',
        sharedStatus: SharedStatus.shared,
        sharedDateUpdated: now,
        sharedReferenceBudgetPk: 'b-1',
        objectiveFk: 'obj-1',
        objectiveLoanFk: 'loan-1',
        budgetFksExclude: ['b-2', 'b-3'],
      );

      final cloudMap = CloudSerializer.transactionToCloud(tx);
      final roundTrip = CloudSerializer.transactionFromCloud(cloudMap);

      expect(roundTrip.transactionPk, tx.transactionPk);
      expect(roundTrip.pairedTransactionFk, tx.pairedTransactionFk);
      expect(roundTrip.name, tx.name);
      expect(roundTrip.amount, tx.amount);
      expect(roundTrip.note, tx.note);
      expect(roundTrip.categoryFk, tx.categoryFk);
      expect(roundTrip.subCategoryFk, tx.subCategoryFk);
      expect(roundTrip.walletFk, tx.walletFk);
      expect(roundTrip.dateCreated.toUtc(), tx.dateCreated);
      expect(roundTrip.dateTimeModified?.toUtc(), tx.dateTimeModified);
      expect(roundTrip.originalDateDue?.toUtc(), tx.originalDateDue);
      expect(roundTrip.income, tx.income);
      expect(roundTrip.periodLength, tx.periodLength);
      expect(roundTrip.reoccurrence, tx.reoccurrence);
      expect(roundTrip.endDate?.toUtc(), tx.endDate);
      expect(roundTrip.upcomingTransactionNotification,
          tx.upcomingTransactionNotification);
      expect(roundTrip.type, tx.type);
      expect(roundTrip.paid, tx.paid);
      expect(roundTrip.createdAnotherFutureTransaction,
          tx.createdAnotherFutureTransaction);
      expect(roundTrip.skipPaid, tx.skipPaid);
      expect(roundTrip.methodAdded, tx.methodAdded);
      expect(roundTrip.transactionOwnerEmail, tx.transactionOwnerEmail);
      expect(roundTrip.sharedKey, tx.sharedKey);
      expect(roundTrip.sharedStatus, tx.sharedStatus);
      expect(roundTrip.sharedDateUpdated?.toUtc(), tx.sharedDateUpdated);
      expect(roundTrip.objectiveFk, tx.objectiveFk);
      expect(roundTrip.objectiveLoanFk, tx.objectiveLoanFk);
      expect(roundTrip.budgetFksExclude, tx.budgetFksExclude);
    });

    test('Transaction round-trip with nulls', () {
      final now = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final tx = Transaction(
        transactionPk: 'tx-null',
        name: 'Simple',
        amount: 10.0,
        note: '',
        categoryFk: 'cat-1',
        walletFk: '0',
        dateCreated: now,
        income: false,
        paid: false,
        skipPaid: false,
      );

      final cloudMap = CloudSerializer.transactionToCloud(tx);
      final roundTrip = CloudSerializer.transactionFromCloud(cloudMap);

      expect(roundTrip.transactionPk, tx.transactionPk);
      expect(roundTrip.name, tx.name);
      expect(roundTrip.amount, tx.amount);
      expect(roundTrip.pairedTransactionFk, isNull);
      expect(roundTrip.dateTimeModified, isNull);
      expect(roundTrip.budgetFksExclude, isNull);
    });

    test('TransactionCategory round-trip with full and null data', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final cat = TransactionCategory(
        categoryPk: 'cat-1',
        name: 'Food',
        colour: '#00FF00',
        iconName: 'food_icon',
        emojiIconName: '🍔',
        dateCreated: now,
        dateTimeModified: now.add(const Duration(minutes: 1)),
        order: 3,
        income: false,
        methodAdded: MethodAdded.csv,
        mainCategoryPk: 'main-cat-1',
      );

      final cloudMap = CloudSerializer.categoryToCloud(cat);
      final roundTrip = CloudSerializer.categoryFromCloud(cloudMap);

      expect(roundTrip.categoryPk, cat.categoryPk);
      expect(roundTrip.name, cat.name);
      expect(roundTrip.colour, cat.colour);
      expect(roundTrip.iconName, cat.iconName);
      expect(roundTrip.emojiIconName, cat.emojiIconName);
      expect(roundTrip.dateCreated.toUtc(), cat.dateCreated);
      expect(roundTrip.dateTimeModified?.toUtc(), cat.dateTimeModified);
      expect(roundTrip.order, cat.order);
      expect(roundTrip.income, cat.income);
      expect(roundTrip.methodAdded, cat.methodAdded);
      expect(roundTrip.mainCategoryPk, cat.mainCategoryPk);
    });

    test('Budget round-trip with full and null data', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final budget = Budget(
        budgetPk: 'b-1',
        name: 'Monthly Budget',
        amount: 1500.0,
        colour: '#0000FF',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        walletFks: ['w-1', 'w-2'],
        categoryFks: ['cat-1', 'cat-2'],
        categoryFksExclude: ['cat-3'],
        income: false,
        archived: false,
        addedTransactionsOnly: false,
        periodLength: 1,
        reoccurrence: BudgetReoccurence.monthly,
        dateCreated: now,
        dateTimeModified: now.add(const Duration(hours: 1)),
        pinned: true,
        order: 0,
        walletFk: '0',
        budgetTransactionFilters: [
          BudgetTransactionFilters.addedToOtherBudget,
          BudgetTransactionFilters.includeIncome,
        ],
        memberTransactionFilters: ['filter-1'],
        sharedKey: 'sb-1',
        sharedOwnerMember: SharedOwnerMember.owner,
        sharedDateUpdated: now,
        sharedMembers: ['a@example.com', 'b@example.com'],
        sharedAllMembersEver: ['a@example.com', 'b@example.com', 'c@example.com'],
        isAbsoluteSpendingLimit: true,
      );

      final cloudMap = CloudSerializer.budgetToCloud(budget);
      final roundTrip = CloudSerializer.budgetFromCloud(cloudMap);

      expect(roundTrip.budgetPk, budget.budgetPk);
      expect(roundTrip.name, budget.name);
      expect(roundTrip.amount, budget.amount);
      expect(roundTrip.colour, budget.colour);
      expect(roundTrip.startDate.toUtc(), budget.startDate);
      expect(roundTrip.endDate.toUtc(), budget.endDate);
      expect(roundTrip.walletFks, budget.walletFks);
      expect(roundTrip.categoryFks, budget.categoryFks);
      expect(roundTrip.categoryFksExclude, budget.categoryFksExclude);
      expect(roundTrip.income, budget.income);
      expect(roundTrip.archived, budget.archived);
      expect(roundTrip.addedTransactionsOnly, budget.addedTransactionsOnly);
      expect(roundTrip.periodLength, budget.periodLength);
      expect(roundTrip.reoccurrence, budget.reoccurrence);
      expect(roundTrip.dateCreated.toUtc(), budget.dateCreated);
      expect(roundTrip.dateTimeModified?.toUtc(), budget.dateTimeModified);
      expect(roundTrip.pinned, budget.pinned);
      expect(roundTrip.order, budget.order);
      expect(roundTrip.walletFk, budget.walletFk);
      expect(roundTrip.budgetTransactionFilters,
          budget.budgetTransactionFilters);
      expect(roundTrip.memberTransactionFilters,
          budget.memberTransactionFilters);
      expect(roundTrip.sharedKey, budget.sharedKey);
      expect(roundTrip.sharedOwnerMember, budget.sharedOwnerMember);
      expect(roundTrip.sharedDateUpdated?.toUtc(), budget.sharedDateUpdated);
      expect(roundTrip.sharedMembers, budget.sharedMembers);
      expect(roundTrip.sharedAllMembersEver, budget.sharedAllMembersEver);
      expect(roundTrip.isAbsoluteSpendingLimit,
          budget.isAbsoluteSpendingLimit);
    });

    test('CategoryBudgetLimit round-trip', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final limit = CategoryBudgetLimit(
        categoryLimitPk: 'cbl-1',
        categoryFk: 'cat-1',
        budgetFk: 'b-1',
        amount: 250.0,
        dateTimeModified: now,
        walletFk: 'w-1',
      );

      final cloudMap = CloudSerializer.categoryBudgetLimitToCloud(limit);
      final roundTrip = CloudSerializer.categoryBudgetLimitFromCloud(cloudMap);

      expect(roundTrip.categoryLimitPk, limit.categoryLimitPk);
      expect(roundTrip.categoryFk, limit.categoryFk);
      expect(roundTrip.budgetFk, limit.budgetFk);
      expect(roundTrip.amount, limit.amount);
      expect(roundTrip.dateTimeModified?.toUtc(), limit.dateTimeModified);
      expect(roundTrip.walletFk, limit.walletFk);
    });

    test('TransactionAssociatedTitle round-trip', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final title = TransactionAssociatedTitle(
        associatedTitlePk: 'tat-1',
        categoryFk: 'cat-1',
        title: 'Uber Eats',
        dateCreated: now,
        dateTimeModified: now,
        order: 2,
        isExactMatch: true,
      );

      final cloudMap = CloudSerializer.associatedTitleToCloud(title);
      final roundTrip = CloudSerializer.associatedTitleFromCloud(cloudMap);

      expect(roundTrip.associatedTitlePk, title.associatedTitlePk);
      expect(roundTrip.categoryFk, title.categoryFk);
      expect(roundTrip.title, title.title);
      expect(roundTrip.dateCreated.toUtc(), title.dateCreated);
      expect(roundTrip.dateTimeModified?.toUtc(), title.dateTimeModified);
      expect(roundTrip.order, title.order);
      expect(roundTrip.isExactMatch, title.isExactMatch);
    });

    test('ScannerTemplate round-trip', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final template = ScannerTemplate(
        scannerTemplatePk: 'st-1',
        dateCreated: now,
        dateTimeModified: now,
        templateName: 'Bank Alert',
        contains: 'Payment of',
        titleTransactionBefore: 'to ',
        titleTransactionAfter: ' on',
        amountTransactionBefore: '\$',
        amountTransactionAfter: ' was',
        defaultCategoryFk: 'cat-1',
        walletFk: 'w-1',
        ignore: false,
      );

      final cloudMap = CloudSerializer.scannerTemplateToCloud(template);
      final roundTrip = CloudSerializer.scannerTemplateFromCloud(cloudMap);

      expect(roundTrip.scannerTemplatePk, template.scannerTemplatePk);
      expect(roundTrip.dateCreated.toUtc(), template.dateCreated);
      expect(roundTrip.dateTimeModified?.toUtc(), template.dateTimeModified);
      expect(roundTrip.templateName, template.templateName);
      expect(roundTrip.contains, template.contains);
      expect(roundTrip.titleTransactionBefore, template.titleTransactionBefore);
      expect(roundTrip.titleTransactionAfter, template.titleTransactionAfter);
      expect(roundTrip.amountTransactionBefore, template.amountTransactionBefore);
      expect(roundTrip.amountTransactionAfter, template.amountTransactionAfter);
      expect(roundTrip.defaultCategoryFk, template.defaultCategoryFk);
      expect(roundTrip.walletFk, template.walletFk);
      expect(roundTrip.ignore, template.ignore);
    });

    test('Objective round-trip', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final obj = Objective(
        objectivePk: 'obj-1',
        type: ObjectiveType.loan,
        name: 'Car Loan',
        amount: 12000.0,
        order: 1,
        colour: '#FFAA00',
        dateCreated: now,
        endDate: now.add(const Duration(days: 720)),
        dateTimeModified: now,
        iconName: 'car_icon',
        emojiIconName: '🚗',
        income: false,
        pinned: true,
        archived: false,
        walletFk: '0',
      );

      final cloudMap = CloudSerializer.objectiveToCloud(obj);
      final roundTrip = CloudSerializer.objectiveFromCloud(cloudMap);

      expect(roundTrip.objectivePk, obj.objectivePk);
      expect(roundTrip.type, obj.type);
      expect(roundTrip.name, obj.name);
      expect(roundTrip.amount, obj.amount);
      expect(roundTrip.order, obj.order);
      expect(roundTrip.colour, obj.colour);
      expect(roundTrip.dateCreated.toUtc(), obj.dateCreated);
      expect(roundTrip.endDate?.toUtc(), obj.endDate);
      expect(roundTrip.dateTimeModified?.toUtc(), obj.dateTimeModified);
      expect(roundTrip.iconName, obj.iconName);
      expect(roundTrip.emojiIconName, obj.emojiIconName);
      expect(roundTrip.income, obj.income);
      expect(roundTrip.pinned, obj.pinned);
      expect(roundTrip.archived, obj.archived);
      expect(roundTrip.walletFk, obj.walletFk);
    });

    test('DeleteLog round-trip', () {
      final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
      final log = DeleteLog(
        deleteLogPk: 'dl-1',
        entryPk: 'tx-deleted-1',
        type: DeleteLogType.Transaction,
        dateTimeModified: now,
      );

      final cloudMap = CloudSerializer.deleteLogToCloud(log);
      final roundTrip = CloudSerializer.deleteLogFromCloud(cloudMap);

      expect(roundTrip.deleteLogPk, log.deleteLogPk);
      expect(roundTrip.entryPk, log.entryPk);
      expect(roundTrip.type, log.type);
      expect(roundTrip.dateTimeModified.toUtc(), log.dateTimeModified);
    });

    test('Firestore type safety: no DateTime or Enum objects in map', () {
      final now = DateTime.now();
      final tx = Transaction(
        transactionPk: 'tx-test',
        name: 'Test',
        amount: 1.0,
        note: 'Note',
        categoryFk: 'cat-1',
        walletFk: '0',
        dateCreated: now,
        dateTimeModified: now,
        reoccurrence: BudgetReoccurence.daily,
        type: TransactionSpecialType.credit,
        methodAdded: MethodAdded.csv,
        income: true,
        paid: false,
        skipPaid: false,
      );

      final map = CloudSerializer.transactionToCloud(tx);
      for (final entry in map.entries) {
        final val = entry.value;
        if (val == null) continue;
        expect(
          val is String ||
              val is num ||
              val is bool ||
              val is List ||
              val is Map,
          isTrue,
          reason: 'Field ${entry.key} had non-primitive type: ${val.runtimeType}',
        );
        expect(val is DateTime, isFalse);
        expect(val is Enum, isFalse);
      }
    });
  });
}
