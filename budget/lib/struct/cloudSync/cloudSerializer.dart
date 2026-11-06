import 'package:budget/database/tables.dart';
import 'package:budget/struct/cloudSync/cloudSyncConfig.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

class CloudSerializer {
  static String? _dateToIso(DateTime? dt) {
    if (dt == null) return null;
    return dt.toUtc().toIso8601String();
  }

  static DateTime? _dateFromIso(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    return DateTime.parse(val.toString()).toLocal();
  }

  static int? _enumToIndex(Enum? e) {
    return e?.index;
  }

  static T? _enumFromIndex<T extends Enum>(List<T> values, dynamic val,
      [T? defaultValue]) {
    if (val == null) return defaultValue;
    if (val is int) {
      if (val >= 0 && val < values.length) return values[val];
      return defaultValue;
    }
    if (val is num) {
      int idx = val.toInt();
      if (idx >= 0 && idx < values.length) return values[idx];
      return defaultValue;
    }
    if (val is String) {
      for (final v in values) {
        if (v.name == val) return v;
      }
    }
    return defaultValue;
  }

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? defaultVal;
  }

  static int _toInt(dynamic val, [int defaultVal = 0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? defaultVal;
  }

  static bool _toBool(dynamic val, [bool defaultVal = false]) {
    if (val == null) return defaultVal;
    if (val is bool) return val;
    return val.toString().toLowerCase() == 'true';
  }

  static List<String>? _toStringList(dynamic val) {
    if (val == null) return null;
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  // --- Wallets ---
  static Map<String, dynamic> walletToCloud(TransactionWallet r) {
    return <String, dynamic>{
      'walletPk': r.walletPk,
      'name': r.name,
      'colour': r.colour,
      'iconName': r.iconName,
      'dateCreated': _dateToIso(r.dateCreated),
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'order': r.order,
      'currency': r.currency,
      'currencyFormat': r.currencyFormat,
      'decimals': r.decimals,
      'homePageWidgetDisplay':
          r.homePageWidgetDisplay?.map((e) => e.index).toList(),
    };
  }

  static TransactionWallet walletFromCloud(Map<String, dynamic> m) {
    List<HomePageWidgetDisplay>? widgetDisplay;
    if (m['homePageWidgetDisplay'] != null &&
        m['homePageWidgetDisplay'] is List) {
      widgetDisplay = (m['homePageWidgetDisplay'] as List)
          .map((e) => _enumFromIndex(
              HomePageWidgetDisplay.values, e, HomePageWidgetDisplay.WalletSwitcher)!)
          .toList();
    }

    return TransactionWallet(
      walletPk: m['walletPk']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      colour: m['colour']?.toString(),
      iconName: m['iconName']?.toString(),
      dateCreated: _dateFromIso(m['dateCreated']) ?? DateTime.now(),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      order: _toInt(m['order']),
      currency: m['currency']?.toString(),
      currencyFormat: m['currencyFormat']?.toString(),
      decimals: _toInt(m['decimals'], 2),
      homePageWidgetDisplay: widgetDisplay,
    );
  }

  // --- Transactions ---
  static Map<String, dynamic> transactionToCloud(Transaction r) {
    return <String, dynamic>{
      'transactionPk': r.transactionPk,
      'pairedTransactionFk': r.pairedTransactionFk,
      'name': r.name,
      'amount': r.amount,
      'note': r.note,
      'categoryFk': r.categoryFk,
      'subCategoryFk': r.subCategoryFk,
      'walletFk': r.walletFk,
      'dateCreated': _dateToIso(r.dateCreated),
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'originalDateDue': _dateToIso(r.originalDateDue),
      'income': r.income,
      'periodLength': r.periodLength,
      'reoccurrence': _enumToIndex(r.reoccurrence),
      'endDate': _dateToIso(r.endDate),
      'upcomingTransactionNotification': r.upcomingTransactionNotification,
      'type': _enumToIndex(r.type),
      'paid': r.paid,
      'createdAnotherFutureTransaction': r.createdAnotherFutureTransaction,
      'skipPaid': r.skipPaid,
      'methodAdded': _enumToIndex(r.methodAdded),
      'transactionOwnerEmail': r.transactionOwnerEmail,
      'transactionOriginalOwnerEmail': r.transactionOriginalOwnerEmail,
      'sharedKey': r.sharedKey,
      'sharedOldKey': r.sharedOldKey,
      'sharedStatus': _enumToIndex(r.sharedStatus),
      'sharedDateUpdated': _dateToIso(r.sharedDateUpdated),
      'sharedReferenceBudgetPk': r.sharedReferenceBudgetPk,
      'objectiveFk': r.objectiveFk,
      'objectiveLoanFk': r.objectiveLoanFk,
      'budgetFksExclude': r.budgetFksExclude,
    };
  }

  static Transaction transactionFromCloud(Map<String, dynamic> m) {
    return Transaction(
      transactionPk: m['transactionPk']?.toString() ?? '',
      pairedTransactionFk: m['pairedTransactionFk']?.toString(),
      name: m['name']?.toString() ?? '',
      amount: _toDouble(m['amount']),
      note: m['note']?.toString() ?? '',
      categoryFk: m['categoryFk']?.toString() ?? '',
      subCategoryFk: m['subCategoryFk']?.toString(),
      walletFk: m['walletFk']?.toString() ?? '0',
      dateCreated: _dateFromIso(m['dateCreated']) ?? DateTime.now(),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      originalDateDue: _dateFromIso(m['originalDateDue']),
      income: _toBool(m['income'], false),
      periodLength: m['periodLength'] != null ? _toInt(m['periodLength']) : null,
      reoccurrence: _enumFromIndex(BudgetReoccurence.values, m['reoccurrence']),
      endDate: _dateFromIso(m['endDate']),
      upcomingTransactionNotification:
          m['upcomingTransactionNotification'] != null
              ? _toBool(m['upcomingTransactionNotification'], true)
              : true,
      type: _enumFromIndex(TransactionSpecialType.values, m['type']),
      paid: _toBool(m['paid'], false),
      createdAnotherFutureTransaction:
          m['createdAnotherFutureTransaction'] != null
              ? _toBool(m['createdAnotherFutureTransaction'], false)
              : false,
      skipPaid: _toBool(m['skipPaid'], false),
      methodAdded: _enumFromIndex(MethodAdded.values, m['methodAdded']),
      transactionOwnerEmail: m['transactionOwnerEmail']?.toString(),
      transactionOriginalOwnerEmail:
          m['transactionOriginalOwnerEmail']?.toString(),
      sharedKey: m['sharedKey']?.toString(),
      sharedOldKey: m['sharedOldKey']?.toString(),
      sharedStatus: _enumFromIndex(SharedStatus.values, m['sharedStatus']),
      sharedDateUpdated: _dateFromIso(m['sharedDateUpdated']),
      sharedReferenceBudgetPk: m['sharedReferenceBudgetPk']?.toString(),
      objectiveFk: m['objectiveFk']?.toString(),
      objectiveLoanFk: m['objectiveLoanFk']?.toString(),
      budgetFksExclude: _toStringList(m['budgetFksExclude']),
    );
  }

  // --- Categories ---
  static Map<String, dynamic> categoryToCloud(TransactionCategory r) {
    return <String, dynamic>{
      'categoryPk': r.categoryPk,
      'name': r.name,
      'colour': r.colour,
      'iconName': r.iconName,
      'emojiIconName': r.emojiIconName,
      'dateCreated': _dateToIso(r.dateCreated),
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'order': r.order,
      'income': r.income,
      'methodAdded': _enumToIndex(r.methodAdded),
      'mainCategoryPk': r.mainCategoryPk,
    };
  }

  static TransactionCategory categoryFromCloud(Map<String, dynamic> m) {
    return TransactionCategory(
      categoryPk: m['categoryPk']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      colour: m['colour']?.toString(),
      iconName: m['iconName']?.toString(),
      emojiIconName: m['emojiIconName']?.toString(),
      dateCreated: _dateFromIso(m['dateCreated']) ?? DateTime.now(),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      order: _toInt(m['order']),
      income: _toBool(m['income'], false),
      methodAdded: _enumFromIndex(MethodAdded.values, m['methodAdded']),
      mainCategoryPk: m['mainCategoryPk']?.toString(),
    );
  }

  // --- Budgets ---
  static Map<String, dynamic> budgetToCloud(Budget r) {
    return <String, dynamic>{
      'budgetPk': r.budgetPk,
      'name': r.name,
      'amount': r.amount,
      'colour': r.colour,
      'startDate': _dateToIso(r.startDate),
      'endDate': _dateToIso(r.endDate),
      'walletFks': r.walletFks,
      'categoryFks': r.categoryFks,
      'categoryFksExclude': r.categoryFksExclude,
      'income': r.income,
      'archived': r.archived,
      'addedTransactionsOnly': r.addedTransactionsOnly,
      'periodLength': r.periodLength,
      'reoccurrence': _enumToIndex(r.reoccurrence),
      'dateCreated': _dateToIso(r.dateCreated),
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'pinned': r.pinned,
      'order': r.order,
      'walletFk': r.walletFk,
      'budgetTransactionFilters':
          r.budgetTransactionFilters?.map((e) => e.index).toList(),
      'memberTransactionFilters': r.memberTransactionFilters,
      'sharedKey': r.sharedKey,
      'sharedOwnerMember': _enumToIndex(r.sharedOwnerMember),
      'sharedDateUpdated': _dateToIso(r.sharedDateUpdated),
      'sharedMembers': r.sharedMembers,
      'sharedAllMembersEver': r.sharedAllMembersEver,
      'isAbsoluteSpendingLimit': r.isAbsoluteSpendingLimit,
    };
  }

  static Budget budgetFromCloud(Map<String, dynamic> m) {
    List<BudgetTransactionFilters>? filters;
    if (m['budgetTransactionFilters'] != null &&
        m['budgetTransactionFilters'] is List) {
      filters = (m['budgetTransactionFilters'] as List)
          .map((e) => _enumFromIndex(BudgetTransactionFilters.values, e,
              BudgetTransactionFilters.defaultBudgetTransactionFilters)!)
          .toList();
    }

    return Budget(
      budgetPk: m['budgetPk']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      amount: _toDouble(m['amount']),
      colour: m['colour']?.toString(),
      startDate: _dateFromIso(m['startDate']) ?? DateTime.now(),
      endDate: _dateFromIso(m['endDate']) ?? DateTime.now(),
      walletFks: _toStringList(m['walletFks']),
      categoryFks: _toStringList(m['categoryFks']),
      categoryFksExclude: _toStringList(m['categoryFksExclude']),
      income: _toBool(m['income'], false),
      archived: _toBool(m['archived'], false),
      addedTransactionsOnly: _toBool(m['addedTransactionsOnly'], false),
      periodLength: _toInt(m['periodLength']),
      reoccurrence: _enumFromIndex(BudgetReoccurence.values, m['reoccurrence']),
      dateCreated: _dateFromIso(m['dateCreated']) ?? DateTime.now(),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      pinned: _toBool(m['pinned'], false),
      order: _toInt(m['order']),
      walletFk: m['walletFk']?.toString() ?? '0',
      budgetTransactionFilters: filters,
      memberTransactionFilters: _toStringList(m['memberTransactionFilters']),
      sharedKey: m['sharedKey']?.toString(),
      sharedOwnerMember:
          _enumFromIndex(SharedOwnerMember.values, m['sharedOwnerMember']),
      sharedDateUpdated: _dateFromIso(m['sharedDateUpdated']),
      sharedMembers: _toStringList(m['sharedMembers']),
      sharedAllMembersEver: _toStringList(m['sharedAllMembersEver']),
      isAbsoluteSpendingLimit: _toBool(m['isAbsoluteSpendingLimit'], false),
    );
  }

  // --- CategoryBudgetLimits ---
  static Map<String, dynamic> categoryBudgetLimitToCloud(CategoryBudgetLimit r) {
    return <String, dynamic>{
      'categoryLimitPk': r.categoryLimitPk,
      'categoryFk': r.categoryFk,
      'budgetFk': r.budgetFk,
      'amount': r.amount,
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'walletFk': r.walletFk,
    };
  }

  static CategoryBudgetLimit categoryBudgetLimitFromCloud(
      Map<String, dynamic> m) {
    return CategoryBudgetLimit(
      categoryLimitPk: m['categoryLimitPk']?.toString() ?? '',
      categoryFk: m['categoryFk']?.toString() ?? '',
      budgetFk: m['budgetFk']?.toString() ?? '',
      amount: _toDouble(m['amount']),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      walletFk: m['walletFk']?.toString() ?? '0',
    );
  }

  // --- AssociatedTitles ---
  static Map<String, dynamic> associatedTitleToCloud(
      TransactionAssociatedTitle r) {
    return <String, dynamic>{
      'associatedTitlePk': r.associatedTitlePk,
      'categoryFk': r.categoryFk,
      'title': r.title,
      'dateCreated': _dateToIso(r.dateCreated),
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'order': r.order,
      'isExactMatch': r.isExactMatch,
    };
  }

  static TransactionAssociatedTitle associatedTitleFromCloud(
      Map<String, dynamic> m) {
    return TransactionAssociatedTitle(
      associatedTitlePk: m['associatedTitlePk']?.toString() ?? '',
      categoryFk: m['categoryFk']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      dateCreated: _dateFromIso(m['dateCreated']) ?? DateTime.now(),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      order: _toInt(m['order']),
      isExactMatch: _toBool(m['isExactMatch'], false),
    );
  }

  // --- ScannerTemplates ---
  static Map<String, dynamic> scannerTemplateToCloud(ScannerTemplate r) {
    return <String, dynamic>{
      'scannerTemplatePk': r.scannerTemplatePk,
      'dateCreated': _dateToIso(r.dateCreated),
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'templateName': r.templateName,
      'contains': r.contains,
      'titleTransactionBefore': r.titleTransactionBefore,
      'titleTransactionAfter': r.titleTransactionAfter,
      'amountTransactionBefore': r.amountTransactionBefore,
      'amountTransactionAfter': r.amountTransactionAfter,
      'defaultCategoryFk': r.defaultCategoryFk,
      'walletFk': r.walletFk,
      'ignore': r.ignore,
    };
  }

  static ScannerTemplate scannerTemplateFromCloud(Map<String, dynamic> m) {
    return ScannerTemplate(
      scannerTemplatePk: m['scannerTemplatePk']?.toString() ?? '',
      dateCreated: _dateFromIso(m['dateCreated']) ?? DateTime.now(),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      templateName: m['templateName']?.toString() ?? '',
      contains: m['contains']?.toString() ?? '',
      titleTransactionBefore: m['titleTransactionBefore']?.toString() ?? '',
      titleTransactionAfter: m['titleTransactionAfter']?.toString() ?? '',
      amountTransactionBefore: m['amountTransactionBefore']?.toString() ?? '',
      amountTransactionAfter: m['amountTransactionAfter']?.toString() ?? '',
      defaultCategoryFk: m['defaultCategoryFk']?.toString() ?? '',
      walletFk: m['walletFk']?.toString() ?? '0',
      ignore: _toBool(m['ignore'], false),
    );
  }

  // --- Objectives ---
  static Map<String, dynamic> objectiveToCloud(Objective r) {
    return <String, dynamic>{
      'objectivePk': r.objectivePk,
      'type': _enumToIndex(r.type) ?? 0,
      'name': r.name,
      'amount': r.amount,
      'order': r.order,
      'colour': r.colour,
      'dateCreated': _dateToIso(r.dateCreated),
      'endDate': _dateToIso(r.endDate),
      'dateTimeModified': _dateToIso(r.dateTimeModified),
      'iconName': r.iconName,
      'emojiIconName': r.emojiIconName,
      'income': r.income,
      'pinned': r.pinned,
      'archived': r.archived,
      'walletFk': r.walletFk,
    };
  }

  static Objective objectiveFromCloud(Map<String, dynamic> m) {
    return Objective(
      objectivePk: m['objectivePk']?.toString() ?? '',
      type: _enumFromIndex(ObjectiveType.values, m['type'], ObjectiveType.goal) ??
          ObjectiveType.goal,
      name: m['name']?.toString() ?? '',
      amount: _toDouble(m['amount']),
      order: _toInt(m['order']),
      colour: m['colour']?.toString(),
      dateCreated: _dateFromIso(m['dateCreated']) ?? DateTime.now(),
      endDate: _dateFromIso(m['endDate']),
      dateTimeModified: _dateFromIso(m['dateTimeModified']),
      iconName: m['iconName']?.toString(),
      emojiIconName: m['emojiIconName']?.toString(),
      income: _toBool(m['income'], false),
      pinned: _toBool(m['pinned'], true),
      archived: _toBool(m['archived'], false),
      walletFk: m['walletFk']?.toString() ?? '0',
    );
  }

  // --- DeleteLogs ---
  static Map<String, dynamic> deleteLogToCloud(DeleteLog r) {
    return <String, dynamic>{
      'deleteLogPk': r.deleteLogPk,
      'entryPk': r.entryPk,
      'type': r.type.index,
      'dateTimeModified': _dateToIso(r.dateTimeModified) ??
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  static DeleteLog deleteLogFromCloud(Map<String, dynamic> m) {
    return DeleteLog(
      deleteLogPk: m['deleteLogPk']?.toString() ?? '',
      entryPk: m['entryPk']?.toString() ?? '',
      type: _enumFromIndex(
          DeleteLogType.values, m['type'], DeleteLogType.Transaction)!,
      dateTimeModified: _dateFromIso(m['dateTimeModified']) ?? DateTime.now(),
    );
  }

  // --- Generic row converters ---
  static Map<String, dynamic> rowToCloud(dynamic row) {
    if (row is TransactionWallet) return walletToCloud(row);
    if (row is Transaction) return transactionToCloud(row);
    if (row is TransactionCategory) return categoryToCloud(row);
    if (row is Budget) return budgetToCloud(row);
    if (row is CategoryBudgetLimit) return categoryBudgetLimitToCloud(row);
    if (row is TransactionAssociatedTitle) return associatedTitleToCloud(row);
    if (row is ScannerTemplate) return scannerTemplateToCloud(row);
    if (row is Objective) return objectiveToCloud(row);
    if (row is DeleteLog) return deleteLogToCloud(row);
    throw ArgumentError('Unknown row type: ${row.runtimeType}');
  }

  static dynamic rowFromCloud(CloudTable table, Map<String, dynamic> m) {
    switch (table) {
      case CloudTable.wallets:
        return walletFromCloud(m);
      case CloudTable.transactions:
        return transactionFromCloud(m);
      case CloudTable.categories:
        return categoryFromCloud(m);
      case CloudTable.budgets:
        return budgetFromCloud(m);
      case CloudTable.categoryBudgetLimits:
        return categoryBudgetLimitFromCloud(m);
      case CloudTable.associatedTitles:
        return associatedTitleFromCloud(m);
      case CloudTable.scannerTemplates:
        return scannerTemplateFromCloud(m);
      case CloudTable.objectives:
        return objectiveFromCloud(m);
      case CloudTable.deleteLogs:
        return deleteLogFromCloud(m);
    }
  }
}
